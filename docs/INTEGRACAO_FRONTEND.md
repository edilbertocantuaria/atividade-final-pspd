# Integração Frontend com Backend gRPC

Frontend de demonstração da plataforma de streaming integrado com microsserviços gRPC.

**Deploy**: https://streaming-app-design.vercel.app/

---

## 🌐 Arquitetura

```
Frontend (Next.js)  →  Gateway P (HTTP/REST)  →  Services A/B (gRPC)
   Vercel              localhost:8080/K8s         Python Streaming
```

### Fluxo de Dados

1. **Usuário** acessa frontend Next.js
2. **Frontend** faz requisições HTTP para Gateway P
3. **Gateway P** converte HTTP → gRPC e chama Services A/B
4. **Services** retornam dados via gRPC
5. **Gateway** converte gRPC → JSON HTTP
6. **Frontend** renderiza dados

---

## 📡 Endpoints da API

### `/api/content` - Catálogo
```bash
# Listar todos os conteúdos
curl "http://localhost:8080/api/content?type=all&limit=20"

# Filtrar por tipo
curl "http://localhost:8080/api/content?type=movies&limit=10"
```

**Resposta**:
```json
{
  "items": [
    {
      "id": "m1",
      "title": "A Jornada Infinita",
      "type": "movie",
      "genres": ["Ficção Científica", "Aventura"],
      "rating": 8.7
    }
  ],
  "total": 4,
  "source": "ServiceA"
}
```

### `/api/metadata/:id` - Metadados
```bash
# Buscar metadados de um conteúdo
curl "http://localhost:8080/api/metadata/m1?userId=user123"
```

**Resposta**:
```json
{
  "contentId": "m1",
  "metadata": [
    {"key": "director", "value": "James Cameron", "relevanceScore": 0.95},
    {"key": "similar", "value": "Interestelar", "relevanceScore": 0.85}
  ],
  "source": "ServiceB"
}
```

### `/api/browse` - Endpoint Combinado
```bash
# Catálogo + metadados do primeiro item
curl "http://localhost:8080/api/browse?type=series&limit=5"
```

---

## 🧪 Testando a Integração

### 1. Port-forward local
```bash
# Gateway P
kubectl port-forward -n pspd svc/p-svc 8080:80

# Testar endpoints
curl http://localhost:8080/api/content?type=all
curl http://localhost:8080/api/metadata/m1
curl http://localhost:8080/api/browse?type=movies
```

### 2. Testes de carga (k6)
```bash
# Testes já simulam navegação real do usuário
./scripts/run_all_tests.sh baseline

# Padrão de requisições:
# - GET /api/content?type=all
# - GET /api/content?type=movies&limit=10
# - GET /api/metadata/m1
# - GET /api/browse?type=series
```

### 3. Verificar métricas
```bash
# Métricas do Gateway
curl http://localhost:8080/metrics | grep http_requests

# Dashboard Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# → http://localhost:3000
```

---

## 🔧 Troubleshooting

### Pods não estão rodando
```bash
kubectl get pods -n pspd
kubectl logs -n pspd -l app=p
```

### Timeout nas requisições
```bash
# Verificar HPA
kubectl get hpa -n pspd

# Escalar manualmente se necessário
kubectl scale deployment p-deploy -n pspd --replicas=3
```

### Dados não aparecem
```bash
# Testar Service A diretamente
kubectl port-forward -n pspd svc/a-svc 50051:50051

# Verificar logs
kubectl logs -n pspd -l app=a
```

---

## 📚 Tecnologias

- **Frontend**: Next.js 14 (App Router), TypeScript, Tailwind CSS
- **Gateway**: Node.js, Express, gRPC-js
- **Services**: Python, gRPC, Prometheus Client
- **Deploy**: Vercel (frontend), Kubernetes (backend)

---

**Nota**: O frontend é uma **demonstração visual** da API. O foco da atividade é a infraestrutura K8s, monitoramento e testes de carga.
