# Integração Frontend Next.js com Backend gRPC

Este documento explica como o frontend da plataforma de streaming se integra com os microsserviços gRPC via Gateway P.

---

## 🌐 Arquitetura Completa

```
┌─────────────────────────────────────────────────────────────┐
│                    FRONTEND (Next.js)                       │
│         https://streaming-app-design.vercel.app/            │
│                                                             │
│  Pages: /browse, /watch/[id], /profiles                    │
│  Components: HeroSection, ContentRow, VideoPlayer          │
└─────────────────────┬───────────────────────────────────────┘
                      │ HTTP/REST
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              GATEWAY P (Node.js + Express)                  │
│                   localhost:8080 / K8s                      │
│                                                             │
│  Endpoints:                                                 │
│    GET /api/content?type=movies&limit=10                   │
│    GET /api/metadata/:contentId                            │
│    GET /api/browse?type=all                                │
└─────────────────────┬───────────────┬───────────────────────┘
                      │ gRPC          │ gRPC
                      ▼               ▼
        ┌─────────────────┐ ┌─────────────────┐
        │   Service A     │ │   Service B     │
        │   (Catálogo)    │ │  (Metadados)    │
        │   Python        │ │   Python        │
        └─────────────────┘ └─────────────────┘
```

---

## 📡 API Endpoints do Gateway

### 1. `/api/content` - Catálogo de Conteúdo

**Service utilizado**: Service A (gRPC unário)

**Parâmetros**:
- `type`: `movies`, `series`, `live`, `all` (padrão: `all`)
- `limit`: número de itens (padrão: `20`)
- `genre`: filtro por gênero (opcional)

**Exemplo de requisição**:
```bash
curl "http://localhost:8080/api/content?type=movies&limit=10&genre=Ação"
```

**Resposta**:
```json
{
  "items": [
    {
      "id": "m1",
      "title": "A Jornada Infinita",
      "description": "Uma aventura épica através das galáxias",
      "thumbnail": "/api/thumbnails/m1.jpg",
      "type": "movie",
      "genres": ["Ficção Científica", "Aventura"],
      "year": 2024,
      "rating": 8.7,
      "duration": "2h 15min"
    }
  ],
  "total": 4,
  "source": "ServiceA"
}
```

**Uso no Frontend**:
```typescript
// lib/api.ts
export async function getContent(type = 'all', limit = 20) {
  const res = await fetch(
    `${process.env.NEXT_PUBLIC_API_URL}/api/content?type=${type}&limit=${limit}`
  )
  return res.json()
}

// app/browse/movies/page.tsx
const { items } = await getContent('movies', 10)
```

---

### 2. `/api/metadata/:contentId` - Metadados e Recomendações

**Service utilizado**: Service B (gRPC streaming)

**Parâmetros**:
- `contentId`: ID do conteúdo (path param)
- `userId`: ID do usuário (query param, opcional)

**Exemplo de requisição**:
```bash
curl "http://localhost:8080/api/metadata/m1?userId=user123"
```

**Resposta**:
```json
{
  "contentId": "m1",
  "metadata": [
    {
      "key": "director",
      "value": "James Cameron",
      "relevanceScore": 0.95
    },
    {
      "key": "cast",
      "value": "Chris Evans, Zoe Saldana",
      "relevanceScore": 0.90
    },
    {
      "key": "similar",
      "value": "Interestelar",
      "relevanceScore": 0.85
    }
  ],
  "source": "ServiceB"
}
```

**Uso no Frontend**:
```typescript
// lib/api.ts
export async function getMetadata(contentId: string, userId?: string) {
  const url = new URL(`${process.env.NEXT_PUBLIC_API_URL}/api/metadata/${contentId}`)
  if (userId) url.searchParams.set('userId', userId)
  
  const res = await fetch(url.toString())
  return res.json()
}

// app/watch/[id]/page.tsx
const { metadata } = await getMetadata(params.id, session?.userId)
const recommendations = metadata.filter(m => m.key === 'similar')
```

---

### 3. `/api/browse` - Endpoint Combinado

**Services utilizados**: Service A + Service B (orquestração)

**Parâmetros**:
- `type`: tipo de conteúdo (padrão: `all`)
- `limit`: número de itens (padrão: `10`)

**Fluxo**:
1. Busca catálogo no Service A
2. Se houver itens, busca metadados do primeiro item no Service B
3. Retorna tudo combinado

**Exemplo de requisição**:
```bash
curl "http://localhost:8080/api/browse?type=series&limit=5"
```

**Resposta**:
```json
{
  "catalog": [
    {
      "id": "s1",
      "title": "Dimensões Paralelas",
      "type": "series",
      "rating": 9.1
    }
  ],
  "total": 4,
  "featuredMetadata": [
    {
      "key": "creator",
      "value": "J.J. Abrams",
      "relevanceScore": 0.96
    }
  ],
  "processingTime": "45.23ms"
}
```

**Uso no Frontend**:
```typescript
// app/browse/page.tsx
const { catalog, featuredMetadata } = await fetch(
  `${process.env.NEXT_PUBLIC_API_URL}/api/browse?type=all&limit=20`
).then(r => r.json())

// Renderiza hero com o primeiro item + metadados
<HeroSection content={catalog[0]} metadata={featuredMetadata} />
<ContentRow items={catalog.slice(1)} />
```

---

## 🔌 Configuração do Frontend

### 1. Variáveis de Ambiente (`.env.local`)

```bash
# URL do Gateway P (desenvolvimento local)
NEXT_PUBLIC_API_URL=http://localhost:8080

# URL do Gateway P (produção Kubernetes)
# NEXT_PUBLIC_API_URL=http://your-k8s-cluster.com
```

### 2. Cliente API Centralizado

```typescript
// lib/streaming-api.ts
const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080'

export class StreamingAPI {
  static async getMovies(limit = 10) {
    const res = await fetch(`${API_BASE}/api/content?type=movies&limit=${limit}`)
    if (!res.ok) throw new Error('Failed to fetch movies')
    return res.json()
  }

  static async getSeries(limit = 10) {
    const res = await fetch(`${API_BASE}/api/content?type=series&limit=${limit}`)
    if (!res.ok) throw new Error('Failed to fetch series')
    return res.json()
  }

  static async getLiveChannels() {
    const res = await fetch(`${API_BASE}/api/content?type=live&limit=20`)
    if (!res.ok) throw new Error('Failed to fetch channels')
    return res.json()
  }

  static async getContentMetadata(contentId: string, userId?: string) {
    const url = new URL(`${API_BASE}/api/metadata/${contentId}`)
    if (userId) url.searchParams.set('userId', userId)
    
    const res = await fetch(url.toString())
    if (!res.ok) throw new Error('Failed to fetch metadata')
    return res.json()
  }

  static async browse(type = 'all', limit = 20) {
    const res = await fetch(`${API_BASE}/api/browse?type=${type}&limit=${limit}`)
    if (!res.ok) throw new Error('Failed to browse')
    return res.json()
  }
}
```

### 3. Exemplo de Uso em Componentes

```typescript
// app/browse/page.tsx
import { StreamingAPI } from '@/lib/streaming-api'

export default async function BrowsePage() {
  const { catalog, featuredMetadata } = await StreamingAPI.browse('all', 20)
  
  const movies = catalog.filter(c => c.type === 'movie')
  const series = catalog.filter(c => c.type === 'series')
  const live = catalog.filter(c => c.type === 'live')

  return (
    <div>
      <HeroSection content={catalog[0]} metadata={featuredMetadata} />
      <ContentRow title="Filmes Populares" items={movies} />
      <ContentRow title="Séries em Alta" items={series} />
      <ContentRow title="Ao Vivo" items={live} />
    </div>
  )
}
```

---

## 🚀 Deployment e Integração

### Desenvolvimento Local

1. **Iniciar backend**:
```bash
cd atividade-final-pspd
kubectl apply -f k8s/
kubectl port-forward -n pspd svc/p-svc 8080:80
```

2. **Iniciar frontend**:
```bash
cd streaming-app-design
echo "NEXT_PUBLIC_API_URL=http://localhost:8080" > .env.local
npm run dev
```

3. **Acessar**: http://localhost:3000

### Produção Kubernetes

1. **Backend**: Já deployado no cluster K8s
2. **Frontend**: Deploy no Vercel com variável:
   ```
   NEXT_PUBLIC_API_URL=http://<k8s-ingress-url>
   ```

3. **CORS**: Já configurado no Gateway P (`cors()` middleware)

---

## 📊 Métricas de Integração

O Gateway P expõe métricas Prometheus sobre as chamadas da API:

```promql
# Taxa de requisições HTTP por endpoint
rate(http_requests_total{app="p", route=~"/api/.*"}[1m])

# Latência P95 das APIs
histogram_quantile(0.95, 
  rate(http_request_duration_seconds_bucket{app="p", route=~"/api/.*"}[1m])
)

# Taxa de chamadas gRPC originadas pelo Gateway
rate(grpc_client_requests_total{app="p"}[1m])
```

---

## 🧪 Testando a Integração

### 1. Teste Manual (curl)

```bash
# Catálogo completo
curl http://localhost:8080/api/content?type=all

# Apenas filmes
curl http://localhost:8080/api/content?type=movies&limit=5

# Metadados de um filme
curl http://localhost:8080/api/metadata/m1

# Browse combinado
curl http://localhost:8080/api/browse?type=series
```

### 2. Teste com k6 (já incluído nos scripts)

```bash
# Os testes de carga já simulam navegação real
./scripts/run_all_tests.sh baseline

# Verifica:
# - GET /api/content?type=all&limit=20
# - GET /api/content?type=movies&limit=10
# - GET /api/metadata/m1
# - GET /api/browse?type=series&limit=5
```

### 3. Verificar Métricas

```bash
# Métricas do Gateway
curl http://localhost:8080/metrics | grep http_requests_total

# Dashboard Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# → http://localhost:3000
```

---

## 🔍 Troubleshooting

### Erro de CORS

**Sintoma**: Frontend não consegue chamar API
```
Access to fetch at 'http://localhost:8080/api/content' from origin 
'http://localhost:3000' has been blocked by CORS policy
```

**Solução**: Gateway P já tem `cors()` ativado. Verificar se middleware está antes das rotas.

### Timeout nas Requisições

**Sintoma**: Requisições demoram muito ou timeout
```
Error: Failed to fetch - Request timeout
```

**Solução**: 
1. Verificar se pods estão rodando: `kubectl get pods -n pspd`
2. Verificar HPA: `kubectl get hpa -n pspd`
3. Aumentar réplicas manualmente: `kubectl scale deployment p -n pspd --replicas=3`

### Dados Não Aparecem

**Sintoma**: API retorna array vazio

**Solução**:
1. Testar Service A diretamente:
   ```bash
   kubectl exec -it <pod-p> -- curl localhost:50051/ServiceA/GetContent
   ```
2. Verificar logs: `kubectl logs -n pspd -l app=a`

---

## 📚 Referências

- **Documentação gRPC**: https://grpc.io/docs/
- **Next.js Data Fetching**: https://nextjs.org/docs/app/building-your-application/data-fetching
- **Prometheus Client (Node.js)**: https://github.com/siimon/prom-client
