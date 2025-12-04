# Plataforma de Streaming - Monitoramento K8s

Aplicação de streaming baseada em microsserviços gRPC com monitoramento Prometheus/Grafana em cluster Kubernetes multi-node.

**Frontend**: https://streaming-app-design.vercel.app/

---

## ⚡ Arquitetura da Aplicação

```
Frontend (Next.js) → Gateway P (Node.js/Express)
                          ↓ gRPC
                     ┌────┴────┐
                     ↓         ↓
              Service A    Service B
              (Catálogo)   (Metadados/Recomendações)
              Python       Python Streaming
```

### Módulos da Aplicação

**Gateway P (Web API)**:
- Recebe requisições HTTP do frontend Next.js
- Expõe API REST: `/api/content`, `/api/metadata/:id`, `/api/browse`
- Converte HTTP → gRPC para comunicação com microsserviços
- Métricas Prometheus em `/metrics`

**Service A (Catálogo de Conteúdo)**:
- Fornece catálogo de filmes, séries e canais ao vivo
- RPC unária: `GetContent(type, limit, genre) → ContentResponse`
- Filtros: tipo de conteúdo, gênero, limite de resultados
- Retorna: 12 itens (4 filmes + 4 séries + 3 canais + metadados)

**Service B (Metadados e Recomendações)**:
- Fornece metadados detalhados via streaming
- RPC streaming: `StreamMetadata(contentId) → stream<MetadataItem>`
- Retorna: diretor, elenco, similaridade, recomendações
- Simulação de processamento incremental (análise de dados)

---

## 📊 Endpoints da API

### `/api/content?type=movies&limit=10&genre=Ação`
Retorna catálogo filtrado via Service A (gRPC unário)
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

### `/api/metadata/m1?userId=user123`
Retorna metadados via Service B (gRPC streaming)
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

### `/api/browse?type=all&limit=10`
**Endpoint combinado**: catálogo (A) + metadados do destaque (B)
```json
{
  "catalog": [...],
  "total": 12,
  "featuredMetadata": [...],
  "processingTime": "45.23ms"
}
```

---

## ⚡ Comandos Essenciais

### Setup Inicial (uma vez)
```bash
# 1. Criar cluster Kubernetes
minikube start --nodes 3 --cpus 4 --memory 8192
minikube addons enable metrics-server ingress

# 2. Build das imagens
eval $(minikube docker-env)
docker build -t a-py:latest ./services/a_py
docker build -t b-py:latest ./services/b_py
docker build -t p-node:latest ./gateway_p_node

# 3. Deploy aplicação
kubectl apply -f k8s/
kubectl apply -f k8s/monitoring/  # Opcional: apenas se tiver Prometheus instalado
```

### Executar Testes

**Opção 1: Testes Rápidos (cenário único - ~20 min)**
```bash
# Executar 4 testes k6 no cenário atual
./scripts/run_all_tests.sh all

# Ou testes individuais
./scripts/run_all_tests.sh baseline
./scripts/run_all_tests.sh spike
./scripts/run_all_tests.sh monitor  # Monitor em tempo real
```

**Opção 2: Análise Comparativa Completa (5 cenários - 2-3h)**
```bash
# 1. Executar todos os 5 cenários (5 × 4 testes = 20 execuções)
./test/run_all_scenarios.sh

# 2. Gerar comparação entre cenários
./scripts/run_scenario_comparison.sh --all
```

### Visualizar Métricas e Dashboards

📊 **[Guia Completo: VISUALIZAR_METRICAS.md](./VISUALIZAR_METRICAS.md)**

**Acesso rápido**:
```bash
# Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# → http://localhost:9090

# Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# → http://localhost:3000
# User: admin | Password: (ver VISUALIZAR_METRICAS.md)
```

---

## 📊 Arquitetura

```
HTTP Request → Gateway P (Node.js)
                   ↓ gRPC
              ┌────┴────┐
              ↓         ↓
         Service A  Service B
         (Python)   (Python streaming)
```

**Cluster K8s**: 1 master + 2 workers  
**Monitoramento**: Prometheus + Grafana  
**Autoscaling**: HPA configurado (CPU 70%, 1-10 replicas)

---

## 🧪 Testes de Carga (k6)

Simulam tráfego de usuários acessando a plataforma de streaming:

| Teste | Duração | VUs | Cenário Simulado |
|-------|---------|-----|------------------|
| **baseline** | 2min | 10 | Uso normal (navegação por catálogo) |
| **ramp** | 4.5min | 10→150 | Horário nobre (gradual) - testa HPA |
| **spike** | 1.5min | 10→200→10 | Lançamento de série viral |
| **soak** | 11.5min | 50 | Maratona de fim de semana |

### Padrão de Requisições
Cada VU simula um usuário real:
1. Lista catálogo completo: `GET /api/content?type=all`
2. Filtra filmes: `GET /api/content?type=movies&limit=10`
3. Busca metadados de um filme: `GET /api/metadata/m1`
4. Consulta combinada: `GET /api/browse?type=series`

### Métricas Coletadas
- Latência (p50, p95, p99)
- Throughput (req/s)
- Taxa de sucesso/erro
- Scaling HPA (réplicas)
- CPU/Memória por pod

### Resultados
```
results/
├── baseline/output.txt
├── ramp/output.txt
├── spike/output.txt
├── soak/output.txt
└── plots/
    ├── 01_latency_comparison.png
    ├── 02_throughput_comparison.png
    ├── 03_success_rate.png
    ├── 04_hpa_scaling.png
    ├── 05_resource_usage.png
    └── 06_latency_percentiles.png
```

---

## 🎯 Cenários de Teste

5 configurações diferentes para análise comparativa:

| # | Nome | Descrição | Foco |
|---|------|-----------|------|
| 1 | **base** | HPA padrão, 1 réplica inicial | Baseline |
| 2 | **replicas** | 2 réplicas iniciais | Warm start |
| 3 | **distribution** | Anti-affinity forçada | Alta disponibilidade |
| 4 | **resources** | CPU/Mem -50% | Recursos limitados |
| 5 | **no-hpa** | Réplicas fixas (3/5) | Sem autoscaling |

### Executar Cenários
```bash
# Todos os cenários (2-3 horas)
./scripts/run_scenario_comparison.sh --all

# Apenas gerar gráficos comparativos
./scripts/run_scenario_comparison.sh --compare

# Menu interativo (escolher 1 cenário)
./scripts/run_scenario_comparison.sh
```

### Saída Esperada
```
scenario-comparison/
├── 01_scenario_latency_comparison.png
├── 02_scenario_throughput_comparison.png
├── 03_scenario_hpa_scaling.png
├── 04_scenario_success_rate.png
├── 05_scenario_cost_analysis.png
├── 06_scenario_performance_radar.png
└── SCENARIO_COMPARISON_REPORT.txt
```

---

## 📈 Métricas Prometheus

### Métricas Customizadas

**Gateway P (8080/metrics)**:
- `http_requests_total{method,route,status_code}`
- `http_request_duration_seconds{method,route,status_code}`
- `grpc_client_requests_total{service,method,status}`
- `grpc_client_request_duration_seconds{service,method,status}`

**Service A (9101/metrics)**:
- `grpc_server_requests_total{method,status}`
- `grpc_server_request_duration_seconds{method}`

**Service B (9102/metrics)**:
- `grpc_server_requests_total{method,status}`
- `grpc_server_request_duration_seconds{method}`
- `grpc_server_stream_items_total{method}`

### Queries PromQL Úteis
```promql
# Taxa de requisições HTTP
rate(http_requests_total{app="p"}[1m])

# Latência P95 do Gateway
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{app="p"}[1m]))

# Taxa de erros
rate(http_requests_total{app="p",status_code=~"5.."}[1m])

# Chamadas gRPC do Gateway
rate(grpc_client_requests_total{app="p"}[1m])

# Latência do Service A
histogram_quantile(0.95, rate(grpc_server_request_duration_seconds_bucket{app="a"}[1m]))
```

---

## 🗂️ Estrutura do Projeto

```
.
├── k8s/                          # Manifests Kubernetes
│   ├── a.yaml                    # Deployment + Service A
│   ├── b.yaml                    # Deployment + Service B
│   ├── p.yaml                    # Deployment + Service Gateway P
│   ├── monitoring/               # HPA + ServiceMonitors
│   └── scenarios/                # 5 cenários de teste
│       ├── scenario1-base/
│       ├── scenario2-replicas/
│       ├── scenario3-distribution/
│       ├── scenario4-resources/
│       └── scenario5-no-hpa/
│
├── services/                     # Código dos microserviços
│   ├── a_py/                     # Service A (Python gRPC)
│   ├── b_py/                     # Service B (Python gRPC streaming)
│   └── gateway_p_node/           # Gateway P (Node.js + Express)
│
├── load/                         # Scripts k6
│   ├── baseline.js
│   ├── ramp.js
│   ├── spike.js
│   └── soak.js
│
└── scripts/                      # Automação
    ├── run_all_tests.sh
    ├── run_scenario_comparison.sh
    └── analyze_results.py
```

---

## 🔧 Comandos Úteis

### Cluster
```bash
# Status do cluster
minikube status
kubectl get nodes

# Ver pods
kubectl get pods -n pspd
kubectl get pods -n monitoring

# Logs
kubectl logs -n pspd -l app=p
kubectl logs -n pspd -l app=a
```

### Testes Manuais
```bash
# Port-forward do Gateway P
kubectl port-forward -n pspd svc/p-svc 8080:80

# Testar endpoints
curl "http://localhost:8080/api/content?type=all&limit=10"
curl "http://localhost:8080/api/metadata/m1?userId=teste"
curl "http://localhost:8080/api/browse?type=series&limit=5"
```

### Métricas
```bash
# Ver métricas do Service A
kubectl port-forward -n pspd svc/a-svc 9101:9101
curl http://localhost:9101/metrics | grep grpc_server

# Verificar targets no Prometheus
# → http://localhost:9090/targets
# Procurar: serviceMonitor/pspd/service-a-monitor/0
```

### Limpeza
```bash
# Deletar namespace
kubectl delete namespace pspd

# Parar cluster
minikube stop

# Deletar cluster
minikube delete
```

---

## 📚 Documentação Adicional

- **`docs/METRICAS_PROMETHEUS.md`** - Detalhes de todas as métricas e queries PromQL
- **`k8s/scenarios/README.md`** - Configuração dos 5 cenários de teste
- **`scenario-comparison/README.md`** - Interpretação dos gráficos comparativos

---

## 🐛 Troubleshooting

### Pods não iniciam
```bash
kubectl describe pod -n pspd <pod-name>
kubectl logs -n pspd <pod-name>
```

### HPA não escala
```bash
kubectl get hpa -n pspd
kubectl describe hpa -n pspd a-hpa
kubectl top pods -n pspd  # Verificar CPU
```

### Métricas não aparecem no Prometheus
```bash
# Verificar ServiceMonitors
kubectl get servicemonitor -n pspd

# Testar endpoint direto
kubectl exec -n pspd <pod-a> -- curl localhost:9101/metrics
```

### Port-forward falha (porta já em uso)
```bash
# Encontrar processo
ps aux | grep port-forward

# Matar processo
pkill -f "port-forward"
```

---

## 👥 Autores

Projeto Final - PSPD 2025.2
