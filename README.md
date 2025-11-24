# Monitoramento K8s - Projeto PSPD

Aplicação gRPC distribuída (P→A,B) com Prometheus/Grafana em cluster multi-node Kubernetes.

---

## ⚡ Comandos Essenciais

### Setup Inicial (uma vez)
```bash
# Criar cluster (1 master + 2 workers)
./scripts/setup_multinode_cluster.sh

# Deploy aplicação + monitoramento
kubectl apply -f k8s/
kubectl apply -f k8s/monitoring/
```

### Executar Testes
```bash
# Testes de carga (baseline, ramp, spike, soak)
./scripts/run_all_tests.sh all

# Análise comparativa de 5 cenários (2-3 horas)
./scripts/run_scenario_comparison.sh --all
```

### Acessar Dashboards
```bash
# Grafana (admin/admin)
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# → http://localhost:3000

# Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# → http://localhost:9090
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

| Teste | Duração | VUs | Objetivo |
|-------|---------|-----|----------|
| **baseline** | 2min | 10 | Linha de base |
| **ramp** | 4.5min | 10→150 | Testar HPA |
| **spike** | 1.5min | 10→200→10 | Resiliência |
| **soak** | 11.5min | 50 | Estabilidade |

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
    ├── setup_multinode_cluster.sh
    ├── run_all_tests.sh
    └── run_scenario_comparison.sh
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
curl http://localhost:8080/a/hello?name=teste
curl http://localhost:8080/b/numbers?count=5
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
