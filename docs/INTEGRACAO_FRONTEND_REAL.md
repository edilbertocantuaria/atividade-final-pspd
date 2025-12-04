# 🌐 Integração Frontend (Vercel) + Backend (Kubernetes)

Guia para conectar o frontend Next.js deployado na Vercel (`https://streaming-app-design.vercel.app`) com o backend gRPC/REST no Kubernetes local.

---

## 🎯 Cenários de Integração

### Opção 1: Expor Backend Publicamente (Recomendado para Produção)

Para conectar o frontend Vercel ao backend Kubernetes, você precisa expor o backend publicamente.

#### 1A: Usando Ngrok (Rápido e Fácil)

```bash
# Terminal 1: Port-forward do Gateway P
kubectl port-forward -n pspd svc/p-svc 8080:80

# Terminal 2: Expor com Ngrok
ngrok http 8080
```

**Saída esperada**:
```
Forwarding   https://abc123.ngrok.io -> http://localhost:8080
```

**Configure no Frontend (Vercel)**:
1. Vá em: https://vercel.com/seu-usuario/streaming-app-design/settings/environment-variables
2. Adicione:
   - **Key**: `NEXT_PUBLIC_API_URL`
   - **Value**: `https://abc123.ngrok.io`
   - **Environment**: Production
3. Redeploy: `git push` ou Vercel Dashboard → Redeploy

#### 1B: Usando Minikube Tunnel (Expor LoadBalancer)

```bash
# Terminal 1: Criar serviço LoadBalancer
kubectl expose deployment p-deploy -n pspd --name=p-lb --type=LoadBalancer --port=80 --target-port=8080

# Terminal 2: Iniciar tunnel (requer sudo)
minikube tunnel

# Terminal 3: Ver IP externo
kubectl get svc p-lb -n pspd
```

**Depois use Ngrok** no IP do LoadBalancer para expor publicamente.

#### 1C: Usando Minikube + Ingress + Ngrok

```bash
# Já tem Ingress configurado em k8s/ingress.yaml
kubectl get ingress -n pspd

# Pegar IP do Ingress
export INGRESS_IP=$(minikube ip)

# Expor com Ngrok
ngrok http $INGRESS_IP:80 --host-header=streaming.local
```

---

### Opção 2: Rodar Frontend Localmente (Desenvolvimento)

Para desenvolvimento, rode o frontend localmente e conecte ao backend local.

#### Passo 1: Clonar e Configurar Frontend

```bash
cd /home/edilberto/pspd
cd streaming-app-design

# Criar arquivo de ambiente
cat > .env.local << 'EOF'
NEXT_PUBLIC_API_URL=http://localhost:8080
EOF
```

#### Passo 2: Instalar Dependências

```bash
pnpm install
# OU
npm install
```

#### Passo 3: Modificar Frontend para Usar API Real

Edite `streaming-app-design/lib/content-data.ts`:

```typescript
// Adicionar no topo do arquivo
const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080'

// Função para buscar conteúdo real
export async function fetchContent(type?: string): Promise<Content[]> {
  try {
    const response = await fetch(`${API_URL}/api/content?type=${type || 'all'}`)
    if (!response.ok) throw new Error('Failed to fetch content')
    return await response.json()
  } catch (error) {
    console.error('Error fetching content:', error)
    // Fallback para dados mockados
    return [...movies, ...series]
  }
}

// Função para buscar metadata
export async function fetchMetadata(id: string) {
  try {
    const response = await fetch(`${API_URL}/api/metadata/${id}`)
    if (!response.ok) throw new Error('Failed to fetch metadata')
    return await response.json()
  } catch (error) {
    console.error('Error fetching metadata:', error)
    return null
  }
}

// Função para browse
export async function fetchBrowse(type: string) {
  try {
    const response = await fetch(`${API_URL}/api/browse?type=${type}`)
    if (!response.ok) throw new Error('Failed to fetch browse data')
    return await response.json()
  } catch (error) {
    console.error('Error fetching browse data:', error)
    return []
  }
}
```

#### Passo 4: Rodar Frontend + Backend

```bash
# Terminal 1: Port-forward do backend
kubectl port-forward -n pspd svc/p-svc 8080:80

# Terminal 2: Rodar frontend
cd /home/edilberto/pspd/streaming-app-design
pnpm dev
# OU
npm run dev
```

Acesse: **http://localhost:3000**

---

### Opção 3: Implementação REST na Vercel (Proxy API Routes)

Crie API Routes no Next.js que fazem proxy para o backend exposto.

#### Criar API Route de Proxy

`streaming-app-design/app/api/content/route.ts`:
```typescript
export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const type = searchParams.get('type') || 'all'
  
  const backendUrl = process.env.BACKEND_URL // Ngrok URL
  
  try {
    const response = await fetch(`${backendUrl}/api/content?type=${type}`)
    const data = await response.json()
    return Response.json(data)
  } catch (error) {
    return Response.json({ error: 'Failed to fetch content' }, { status: 500 })
  }
}
```

`streaming-app-design/app/api/metadata/[id]/route.ts`:
```typescript
export async function GET(
  request: Request,
  { params }: { params: { id: string } }
) {
  const backendUrl = process.env.BACKEND_URL
  
  try {
    const response = await fetch(`${backendUrl}/api/metadata/${params.id}`)
    const data = await response.json()
    return Response.json(data)
  } catch (error) {
    return Response.json({ error: 'Failed to fetch metadata' }, { status: 500 })
  }
}
```

**Configure na Vercel**:
- **Environment Variable**: `BACKEND_URL` = `https://abc123.ngrok.io`

**No frontend, use**:
```typescript
// Agora chama API route local (que faz proxy)
fetch('/api/content?type=movies')
fetch('/api/metadata/m1')
```

---

## 📊 Ver Métricas com Tráfego do Frontend

### Cenário: Frontend → Backend → Métricas no Prometheus

#### Passo 1: Preparar Monitoramento

```bash
# Terminal 1: Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Terminal 2: Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Terminal 3: Backend (se rodando localmente)
kubectl port-forward -n pspd svc/p-svc 8080:80
```

#### Passo 2: Usar o Frontend

1. Acesse: https://streaming-app-design.vercel.app (se expôs backend com Ngrok)
2. **OU** http://localhost:3000 (se rodando localmente)
3. Navegue pelo site:
   - Login
   - Browse Movies
   - Browse Series
   - Watch (abre detalhes de conteúdo)

#### Passo 3: Observar Métricas em Tempo Real

**Prometheus** (http://localhost:9090/graph):
```promql
# Requisições HTTP do Gateway P
rate(http_requests_total{container="p"}[1m])

# Por endpoint
sum by (route) (rate(http_requests_total{container="p"}[1m]))

# Latência
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{container="p"}[1m]))
```

**Grafana** (http://localhost:3000):
- Dashboard: "Streaming API Metrics"
- Observe gráficos atualizando conforme você navega no frontend

---

## 🔥 Teste de Carga com Frontend + Métricas

### Simular Usuários Reais Navegando

```bash
# Terminal 1: Port-forward backend
kubectl port-forward -n pspd svc/p-svc 8080:80

# Terminal 2: Executar teste que simula navegação
k6 run load/spike.js

# Terminal 3: Observar Prometheus/Grafana
# Ver métricas subindo em tempo real
```

**Queries úteis durante teste**:
```promql
# Taxa de requisições
sum(rate(http_requests_total{container="p"}[30s]))

# Latência em tempo real
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{container="p"}[30s]))

# CPU do Gateway (scaling)
rate(container_cpu_usage_seconds_total{namespace="pspd",pod=~"p-deploy.*"}[30s])

# Número de réplicas (HPA em ação)
kube_horizontalpodautoscaler_status_current_replicas{namespace="pspd"}
```

---

## 🎬 Fluxo Completo: Frontend → Backend → Métricas

### Setup Recomendado

```bash
# === Terminal 1: Expor Backend ===
kubectl port-forward -n pspd svc/p-svc 8080:80

# === Terminal 2: Ngrok (para Vercel) ===
ngrok http 8080
# Copie URL: https://abc123.ngrok.io
# Configure na Vercel: NEXT_PUBLIC_API_URL

# === Terminal 3: Prometheus ===
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Acesse: http://localhost:9090

# === Terminal 4: Grafana ===
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Acesse: http://localhost:3000
# User: admin
# Password: kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d
```

### Usar a Aplicação

1. **Acesse frontend**: https://streaming-app-design.vercel.app
2. **Faça login** (email: emailcontateste@dominio.com, senha: 1234567890)
3. **Navegue** pelas páginas:
   - Browse → Movies
   - Browse → Series
   - Browse → Live TV
   - Clique em conteúdos para ver detalhes

4. **Observe métricas**:
   - Prometheus: http://localhost:9090/graph
   - Grafana: http://localhost:3000
   - Queries: `rate(http_requests_total{container="p"}[1m])`

---

## 🐛 Troubleshooting

### Problema: Frontend não conecta ao backend

**Erro**: `Failed to fetch` ou `Network error`

**Soluções**:

1. **Verificar CORS no backend**:
   ```bash
   # Ver logs do Gateway P
   kubectl logs -n pspd -l app=p --tail=50
   ```
   
   Se aparecer erro de CORS, edite `gateway_p_node/server.js`:
   ```javascript
   // Adicionar após criar app Express
   app.use((req, res, next) => {
     res.header('Access-Control-Allow-Origin', '*')
     res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE')
     res.header('Access-Control-Allow-Headers', 'Content-Type')
     next()
   })
   ```

2. **Rebuild e redeploy**:
   ```bash
   eval $(minikube docker-env)
   docker build -t p-gateway:local ./gateway_p_node
   kubectl delete pod -n pspd -l app=p
   ```

3. **Verificar Ngrok está rodando**:
   ```bash
   curl https://abc123.ngrok.io/api/content?type=all
   # Deve retornar JSON com conteúdos
   ```

### Problema: Métricas não aparecem

**Causa**: Frontend não está fazendo requisições ao backend

**Verificar**:
```bash
# Ver logs do Gateway P
kubectl logs -n pspd -l app=p -f

# Deve aparecer logs de requisições HTTP quando você navega no frontend
```

**Se não aparecer logs**:
- Frontend está usando dados mockados
- URL do backend está incorreta no frontend
- Ngrok não está rodando

### Problema: Latência muito alta

**Normal**: 100-300ms (inclui latency do Ngrok)

**Se > 1s**:
```bash
# Verificar recursos dos pods
kubectl top pods -n pspd

# Aumentar recursos se necessário
kubectl scale deployment p-deploy -n pspd --replicas=3
```

---

## 📊 Métricas Específicas do Frontend

### Queries PromQL para Analisar Navegação

```promql
# Endpoints mais acessados
topk(5, sum by (route) (rate(http_requests_total{container="p"}[5m])))

# Taxa de sucesso (2xx vs 4xx/5xx)
sum(rate(http_requests_total{container="p",status_code=~"2.."}[1m])) 
/ 
sum(rate(http_requests_total{container="p"}[1m])) * 100

# Latência por endpoint
histogram_quantile(0.95, 
  sum by (le, route) (rate(http_request_duration_seconds_bucket{container="p"}[5m]))
)

# Requisições por minuto (RPS)
sum(rate(http_requests_total{container="p"}[1m])) * 60
```

### Dashboard Grafana Customizado

Crie painéis para:
- **Taxa de usuários ativos** (requests/min)
- **Endpoints populares** (topk routes)
- **Latência por página** (P50, P95, P99)
- **Taxa de erro** (4xx, 5xx)
- **Scaling automático** (número de réplicas)

---

## ✅ Checklist de Integração

- [ ] Backend exposto (port-forward ou Ngrok)
- [ ] Frontend configurado com `NEXT_PUBLIC_API_URL`
- [ ] CORS habilitado no backend
- [ ] Prometheus/Grafana acessíveis
- [ ] ServiceMonitors UP (3 targets)
- [ ] Frontend fazendo requisições (ver logs do Gateway P)
- [ ] Métricas aparecendo no Prometheus
- [ ] Dashboard do Grafana mostrando dados

**Se todos os itens estão ✅, a integração está completa!** 🎉

---

## 🚀 Próximos Passos

1. **Deploy backend em cloud** (AWS/GCP/Azure) para URL pública permanente
2. **Configurar domínio customizado** (ex: `api.streaming.com`)
3. **Implementar autenticação JWT** entre frontend e backend
4. **Adicionar cache** (Redis) para melhorar performance
5. **Monitorar métricas de negócio** (usuários ativos, conteúdo popular, etc.)
