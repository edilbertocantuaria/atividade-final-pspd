# Guia Rápido de Execução

## 🚀 Setup (executar 1 vez)

### 1. Criar Cluster Multi-Node
```bash
./scripts/setup_multinode_cluster.sh
```
**O que faz**: Cria cluster (1 master + 2 workers) + instala Prometheus/Grafana  
**Tempo**: ~10 minutos

### 2. Deploy da Aplicação
```bash
kubectl apply -f k8s/
kubectl apply -f k8s/monitoring/
```
**O que faz**: Deploya serviços A, B, P + HPA + ServiceMonitors  
**Verificar**: `kubectl get pods -n pspd` (todos devem estar `Running`)

---

## 🧪 Executar Testes de Carga

### Testes Básicos (4 cenários k6)
```bash
./scripts/run_all_tests.sh all
```
**O que faz**: Executa baseline, ramp, spike, soak  
**Tempo**: ~20 minutos  
**Resultados**: `results/plots/*.png`

### Análise Comparativa (5 cenários K8s)
```bash
./scripts/run_scenario_comparison.sh --all
```
**O que faz**: Testa 5 configurações diferentes de deployment  
**Tempo**: 2-3 horas  
**Resultados**: `scenario-comparison/*.png`

---

## 📊 Acessar Monitoramento

### Grafana
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```
Acesse: http://localhost:3000  
Login: **admin** / **admin**

### Prometheus
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```
Acesse: http://localhost:9090  
Ir em: **Status → Targets** (verificar se `serviceMonitor/pspd/*` estão UP)

---

## 📈 Queries Prometheus Essenciais

Copie e cole no Prometheus (aba Graph):

```promql
# Taxa de requisições HTTP (req/s)
rate(http_requests_total{app="p"}[1m])

# Latência P95 do Gateway P
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{app="p"}[1m]))

# Latência P95 do Service A
histogram_quantile(0.95, rate(grpc_server_request_duration_seconds_bucket{app="a"}[1m]))

# Taxa de erros
rate(http_requests_total{app="p",status_code=~"5.."}[1m])

# Chamadas gRPC por segundo
rate(grpc_client_requests_total{app="p"}[1m])
```

---

## 🧹 Comandos Úteis

### Ver status
```bash
# Cluster
minikube status
kubectl get nodes

# Pods
kubectl get pods -n pspd
kubectl get hpa -n pspd
kubectl top pods -n pspd

# Logs
kubectl logs -n pspd -l app=p --tail=50
```

### Testar manualmente
```bash
# Port-forward do Gateway
kubectl port-forward -n pspd svc/p-svc 8080:80

# Fazer requisições
curl http://localhost:8080/a/hello?name=teste
curl http://localhost:8080/b/numbers?count=5

# Ver métricas direto
kubectl port-forward -n pspd svc/a-svc 9101:9101
curl http://localhost:9101/metrics | grep grpc_server
```

### Limpar tudo
```bash
# Deletar aplicação
kubectl delete namespace pspd

# Parar cluster
minikube stop

# Deletar cluster
minikube delete
```

---

## 🐛 Solução de Problemas

### Pod não inicia
```bash
kubectl describe pod -n pspd <nome-do-pod>
kubectl logs -n pspd <nome-do-pod>
```

### HPA não escala
```bash
kubectl describe hpa -n pspd a-hpa
kubectl top pods -n pspd  # Ver se metrics-server está funcionando
```

### Port-forward falha (porta ocupada)
```bash
pkill -f "port-forward"  # Mata todos os port-forwards
```

### Métricas não aparecem no Prometheus
```bash
# 1. Verificar ServiceMonitors
kubectl get servicemonitor -n pspd

# 2. Testar endpoint
kubectl exec -n pspd <pod-name> -- curl localhost:9101/metrics

# 3. Ver targets no Prometheus
# http://localhost:9090/targets → procurar "pspd"
```

---

## 📁 Estrutura de Resultados

```
results/                           # Testes básicos
├── baseline/
│   ├── output.txt
│   ├── pod-metrics-pre.txt
│   └── hpa-status-post.txt
├── ramp/
├── spike/
├── soak/
└── plots/                         # 6 gráficos gerados
    ├── 01_latency_comparison.png
    ├── 02_throughput_comparison.png
    ├── 03_success_rate.png
    ├── 04_hpa_scaling.png
    ├── 05_resource_usage.png
    └── 06_latency_percentiles.png

scenario-comparison/               # Análise comparativa
├── 01_scenario_latency_comparison.png
├── 02_scenario_throughput_comparison.png
├── 03_scenario_hpa_scaling.png
├── 04_scenario_success_rate.png
├── 05_scenario_cost_analysis.png
├── 06_scenario_performance_radar.png
└── SCENARIO_COMPARISON_REPORT.txt

results-scenario-1-base/          # Resultados por cenário
results-scenario-2-replicas/
results-scenario-3-distribution/
results-scenario-4-resources/
results-scenario-5-no-hpa/
```

---

## 📚 Documentação Detalhada

- **README.md** - Visão geral e comandos principais
- **docs/METRICAS_PROMETHEUS.md** - Todas as métricas detalhadas
- **k8s/scenarios/README.md** - Configuração dos 5 cenários
- **scenario-comparison/README.md** - Como interpretar os gráficos
