# Guia Rápido de Execução

## 🚀 Setup (executar 1 vez)

### 1. Criar Cluster Kubernetes
```bash
# Criar cluster Minikube
minikube start --nodes 3 --cpus 4 --memory 8192

# Habilitar addons necessários
minikube addons enable metrics-server
minikube addons enable ingress

# Verificar nodes
kubectl get nodes
```
**Tempo**: ~5 minutos  
**Resultado**: 1 control-plane + 2 workers

### 2. Instalar Prometheus Stack (opcional)
```bash
# Adicionar repositório Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Instalar Prometheus + Grafana
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```
**Tempo**: ~5 minutos  
**Opcional**: Pode pular este passo se não precisar de monitoramento

> ℹ️ **Avisos normais durante instalação**:
> - `Warning: unrecognized format "int32"/"int64"` - Avisos cosméticos, pode ignorar
> - `Warning: spec.SessionAffinity is ignored` - Comportamento esperado de headless services
> - Se aparecer `STATUS: deployed` no final, instalação foi bem-sucedida! ✅

**Verificar instalação**:
```bash
# Aguardar pods ficarem prontos (~2-3 min)
kubectl get pods -n monitoring

# Todos devem estar Running/Completed
```

### 3. Deploy da Aplicação
```bash
# Build das imagens (dentro do contexto Docker do Minikube)
eval $(minikube -p minikube docker-env)
docker build -t a-py:latest ./services/a_py
docker build -t b-py:latest ./services/b_py
docker build -t p-node:latest ./gateway_p_node

# Deploy dos serviços
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/
kubectl apply -f k8s/monitoring/  # Apenas se instalou Prometheus
```
**Tempo**: ~3 minutos  
**Verificar**: `kubectl get pods -n pspd` (todos devem estar `Running`)

---

## 🧪 Executar Testes de Carga

### Opção 1: Testes Rápidos em Cenário Único
```bash
# Executar 4 testes k6 no cenário atual (baseline, ramp, spike, soak)
./scripts/run_all_tests.sh all
```
**O que faz**: Executa baseline, ramp, spike, soak no cenário deployado  
**Tempo**: ~20 minutos  
**Resultados**: `results/plots/*.png`

**Testes individuais**:
```bash
./scripts/run_all_tests.sh baseline  # Apenas baseline
./scripts/run_all_tests.sh spike     # Apenas spike
./scripts/run_all_tests.sh monitor   # Monitor em tempo real
```

### Opção 2: Análise Comparativa Completa (5 Cenários)
```bash
# Executa TODOS os 5 cenários com 4 testes cada = 20 execuções
./test/run_all_scenarios.sh
```
**O que faz**: 
- Setup do Cenário 1 → 4 testes → Coleta métricas
- Setup do Cenário 2 → 4 testes → Coleta métricas
- ... repete para todos os 5 cenários

**Tempo**: 2-3 horas  
**Resultados**: `test_results/scenario_*/*.png`

**Gerar comparação entre cenários**:
```bash
./scripts/run_scenario_comparison.sh --all
```
**Resultados**: `test_results/scenario-comparison/*.png`

---

## 📊 Acessar Monitoramento

> ⚠️ **Importante**: Os serviços estão dentro do cluster (ClusterIP), não expostos externamente.  
> Você precisa fazer **port-forward** para acessá-los do seu navegador.

### Grafana
```bash
# Em um terminal separado (deixe rodando)
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```
Acesse: http://localhost:3000  
Login: **admin**
senha: **admin**

**Caso precise recuperar senha**:
```bash
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d && echo
```

> 💡 A senha é gerada aleatoriamente durante a instalação do Helm.  
> Se esquecer, use o comando acima para recuperá-la.

### Prometheus
```bash
# Em outro terminal separado (deixe rodando)
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```
Acesse: http://localhost:9090  
Ir em: **Status → Targets** (verificar se `serviceMonitor/pspd/*` estão UP)

### Atalho: Abrir ambos em background
```bash
# Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &

# Prometheus  
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 &

# Para parar depois:
pkill -f "port-forward.*monitoring"
```

---

## 📊 Visualizar Métricas e Dashboards

### Guia Completo Passo a Passo

📖 **[VISUALIZAR_METRICAS.md](./VISUALIZAR_METRICAS.md)** - Guia detalhado com screenshots e troubleshooting

### Acesso Rápido

**Prometheus** (métricas brutas):
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# → http://localhost:9090
```

**Grafana** (dashboards visuais):
```bash
# Port-forward
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# → http://localhost:3000

# Recuperar senha
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d
# User: admin
```

**Dashboard customizado**: Importar `k8s/monitoring/grafana-dashboard.json`

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
curl "http://localhost:8080/api/content?type=all&limit=10"
curl "http://localhost:8080/api/content?type=movies&limit=5"
curl "http://localhost:8080/api/metadata/m1?userId=teste"
curl "http://localhost:8080/api/browse?type=series&limit=3"

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

### Avisos durante instalação do Helm
```
Warning: unrecognized format "int32"/"int64"
Warning: spec.SessionAffinity is ignored
```
**Solução**: Ignorar completamente! São avisos cosméticos que não afetam o funcionamento.  
**Verificar sucesso**: Se aparecer `STATUS: deployed`, instalação foi bem-sucedida ✅

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
