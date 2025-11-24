# Projeto Final PSPD - Monitoramento e Observabilidade em Kubernetes

> Projeto de pesquisa focado em monitoramento e observabilidade de aplicações baseadas em microserviços em clusters Kubernetes multi-node, com Prometheus, Grafana e ênfase em métricas de desempenho.

## 📋 Índice

- [Arquitetura](#-arquitetura)
- [Setup Multi-Node](#-setup-multi-node-novo)
- [Quick Start](#-quick-start)
- [Sistema de Checkpoints](#-sistema-de-checkpoints-novo)
- [Como Executar](#-como-executar)
- [Testes de Carga](#-testes-de-carga)
- [Monitoramento](#-monitoramento)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Troubleshooting](#-troubleshooting)

---

## 🏗️ Arquitetura

### Cluster Kubernetes Multi-Node

```
┌─────────────────────────────────────────────────────────┐
│  Cluster K8s (1 Master + 2 Workers)                     │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Namespace: pspd                                   │ │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐     │ │
│  │  │ Gateway P │  │ Service A │  │ Service B │     │ │
│  │  │  (Node.js)│  │  (Python) │  │  (Python) │     │ │
│  │  │  :8080    │  │  :9101    │  │  :9102    │     │ │
│  │  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘     │ │
│  │        │ gRPC         │                │          │ │
│  │        └──────────────┴────────────────┘          │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Namespace: monitoring                             │ │
│  │  ┌──────────────┐  ┌──────────────┐               │ │
│  │  │  Prometheus  │  │   Grafana    │               │ │
│  │  │  :9090       │  │   :3000      │               │ │
│  │  └──────┬───────┘  └──────────────┘               │ │
│  │         │ scrape                                   │ │
│  │         └─────► ServiceMonitors                    │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### Microserviços gRPC
```
Cliente HTTP → Gateway P (Node.js + Express)
                    ↓ gRPC
              ┌─────┴─────┐
              ↓           ↓
        Service A    Service B
        (Python)     (Python)
```

- **Gateway P**: WEB API que recebe requisições HTTP e distribui via gRPC
- **Service A**: Microserviço gRPC com mensagens personalizadas
- **Service B**: Microserviço gRPC com streaming de números

### Instrumentação Prometheus

Todos os serviços expõem métricas em `/metrics`:

**Gateway P (porta 8080)**:
- `http_requests_total`, `http_request_duration_seconds`
- `grpc_client_requests_total`, `grpc_client_request_duration_seconds`

**Services A/B (portas 9101/9102)**:
- `grpc_server_requests_total`, `grpc_server_request_duration_seconds`
- `grpc_server_stream_items_total` (apenas B)

---

## 🚀 Setup Multi-Node (NOVO)

### Opção 1: Setup Completo Automatizado

```bash
# Criar cluster multi-node + Prometheus + Grafana (5-10 min)
./scripts/setup_multinode_cluster.sh

# Deploy das aplicações
./scripts/deploy.sh setup

# Configurar ServiceMonitors
./scripts/deploy.sh monitoring
```

✅ **Resultado**: Cluster com 1 master + 2 workers + Prometheus + Grafana instalados

### Opção 2: Setup Passo a Passo

Ver documentação detalhada em: **[GUIA_MULTINODE.md](docs/GUIA_MULTINODE.md)**

---

## 🚀 Quick Start

### Execução Completa Automatizada ⚡

```bash
# Uma linha - setup completo!
./RUN_COMPLETE.sh

# ✅ Cria cluster multi-node (1 master + 2 workers)
# ✅ Instala Prometheus + Grafana
# ✅ Deploy das aplicações
# ✅ Configura ServiceMonitors
# ✅ Executa testes de carga
# ✅ Gera análises e gráficos
# ⏱️  Tempo total: 15-20 minutos
```

### 🔄 Sistema de Checkpoints (NOVO!)

Se algo der erro, **não precisa recomeçar do zero**!

```bash
./RUN_COMPLETE.sh

# Se der erro, execute novamente:
./RUN_COMPLETE.sh

# 📍 Checkpoint encontrado! Última etapa concluída: 2/5
# 
# Opções:
#   1. ✅ Continuar de onde parou (Etapa 3)
#   2. 🔄 Recomeçar do zero
#   3. ❌ Cancelar

# Escolha "1" e economize tempo! 🚀
```

📖 **Guia completo**: [COMO_CONTINUAR.md](docs/COMO_CONTINUAR.md)

### Pré-requisitos
```bash
# Verificar ferramentas instaladas
minikube version
kubectl version --client
docker --version
k6 version
python3 --version
```

### Setup Manual (se preferir controle total)

```bash
# 1. Criar cluster multi-node
./scripts/setup_multinode_cluster.sh

# 2. Deploy aplicações
./scripts/deploy.sh setup

# 3. Configurar monitoramento
./scripts/deploy.sh monitoring

# 4. Executar testes
./scripts/run_all_tests.sh all
```

---

## 💻 Como Executar

### Execução Automática (Recomendado)

```bash
# Terminal 1: Port-forward monitorado (auto-restart)
./scripts/stable_port_forward.sh

# Terminal 2: Executar todos os testes
BASE_URL=http://localhost:8080 ./scripts/run_all_tests.sh

# Terminal 3 (opcional): Monitorar em tempo real
./scripts/monitor.sh
```

### Execução Manual

```bash
# Terminal 1: Port-forward simples
kubectl port-forward -n pspd svc/p-svc 8080:80

# Terminal 2: Teste individual
BASE_URL=http://localhost:8080 k6 run load/baseline.js
BASE_URL=http://localhost:8080 k6 run load/ramp.js
BASE_URL=http://localhost:8080 k6 run load/spike.js

# Para teste longo (11 min), use port-forward monitorado
```

### Gerar Análise

```bash
# Após executar testes
python3 scripts/analyze_results.py

# Resultados em:
# - results/plots/*.png (6 gráficos comparativos)
# - results/plots/SUMMARY_REPORT.txt
```

---

## 📊 Testes de Carga

### Cenários K6 (Testes de Carga)

| Teste | Duração | Carga | Objetivo |
|-------|---------|-------|----------|
| **baseline.js** | 2 min | 10 VUs constantes | Linha de base de performance |
| **ramp.js** | 4 min | 10→150 VUs gradual | Testar autoscaling (HPA) |
| **spike.js** | 1.5 min | 10→200 VUs súbito | Resiliência a picos (~33% erro esperado) |
| **soak.js** | 11 min | 50 VUs sustentado | Estabilidade long-term |
| **stress.js** | 1.5 min | 10→200 VUs | Encontrar limite (PODE ter erros) |

### Cenários de Configuração K8s (Análise Comparativa)

**5 cenários distintos** para avaliar impacto de configurações no desempenho:

| Cenário | Descrição | Foco |
|---------|-----------|------|
| **1. Base** | HPA enabled, 1 replica inicial | Autoscaling padrão |
| **2. Replicas** | 2 replicas iniciais | Warm start |
| **3. Distribution** | Anti-affinity forçada | Alta disponibilidade |
| **4. Resources** | CPU/Memory -50% | Economia de recursos |
| **5. No HPA** | Réplicas fixas (3/5) | Sem autoscaling |

**Comandos**:

```bash
# Executar todos os 5 cenários (2-3 horas)
./scripts/run_scenario_comparison.sh --all

# Menu interativo para escolher cenário específico
./scripts/run_scenario_comparison.sh

# Gerar apenas gráficos comparativos (dados já existentes)
./scripts/run_scenario_comparison.sh --compare
```

**📈 Saída**: 6 gráficos comparativos + relatórios (ver `scenario-comparison/README.md`)

**Documentação completa**: `k8s/scenarios/README.md`

---

### Métricas Coletadas

**Performance**:
- Latência (p50/p90/p95/p99)
- Throughput (req/s)
- Taxa de sucesso/falha

**Infraestrutura**:
- CPU/Memória por pod
- Número de réplicas (HPA)
- Eventos de scaling

**Exemplo de Resultados**:
```
Baseline: ~150 req/s, p95 < 25ms, 100% sucesso
Ramp: HPA escala 1→3 réplicas, p95 < 500ms, 100% sucesso
Spike: Pico de 200 VUs, p95 < 2s, taxa erro < 10%, recuperação rápida
Soak: Estável por 11 min, p95 < 10ms, 100% sucesso
Stress (opcional): 200 VUs, identifica limite máximo (pode ter erros)
```

---

## 📊 Monitoramento

### Acessar Grafana

```bash
# Opção 1: Port-forward
./scripts/deploy.sh grafana
# Acesse: http://localhost:3000
# User: admin | Password: admin

# Opção 2: NodePort (mais estável)
MINIKUBE_IP=$(minikube ip -p pspd-cluster)
GRAFANA_PORT=$(kubectl get svc -n monitoring prometheus-grafana -o jsonpath='{.spec.ports[0].nodePort}')
echo "http://$MINIKUBE_IP:$GRAFANA_PORT"
```

### Importar Dashboard

1. Acesse Grafana
2. Vá em **+** → **Import** → **Upload JSON file**
3. Selecione `k8s/monitoring/grafana-dashboard.json`
4. Dashboard inclui:
   - 📈 HTTP Request Rate
   - ⏱️ Request Duration (p95, p99)
   - 🔢 Pod Replicas (HPA)
   - 💻 CPU/Memory Usage
   - ❌ Error Rate

### Acessar Prometheus

```bash
# Port-forward
./scripts/deploy.sh prometheus
# Acesse: http://localhost:9090

# Queries úteis:
# rate(http_requests_total{namespace="pspd"}[1m])
# histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[1m]))
```

### Verificar ServiceMonitors

```bash
# Listar ServiceMonitors
kubectl get servicemonitor -n pspd

# Verificar targets no Prometheus
# Acesse: http://localhost:9090/targets
# Deve mostrar 3 targets UP:
# - pspd/service-a-monitor
# - pspd/service-b-monitor
# - pspd/gateway-p-monitor
```

---

## 📁 Estrutura do Projeto

```
atividade-final-pspd/
├── gateway_p_node/          # Gateway HTTP→gRPC (Node.js + prom-client)
├── services/
│   ├── a_py/                # Service A (Python + prometheus_client)
│   └── b_py/                # Service B (Python + prometheus_client)
├── k8s/
│   ├── *.yaml               # Deployments, Services
│   ├── p-nodeport.yaml      # NodePort para acesso estável
│   └── monitoring/
│       ├── hpa.yaml         # Autoscaling (CPU 70%, Memory 80%)
│       ├── servicemonitor-*.yaml      # Prometheus ServiceMonitors
│       └── grafana-dashboard.json     # Dashboard customizado
├── load/                    # 4 cenários k6
├── scripts/
│   ├── setup_multinode_cluster.sh  # Criar cluster 1+2 nodes
│   ├── deploy.sh            # Deploy K8s + monitoramento
│   ├── run_all_tests.sh     # Suite completa + análise
│   └── analyze_results.py   # Gerar gráficos
├── results/
│   ├── baseline/            # Resultados baseline
│   ├── ramp/                # Resultados ramp
│   ├── spike/               # Resultados spike
│   ├── soak/                # Resultados soak
│   └── plots/               # Gráficos + relatório
├── GUIA_MULTINODE.md        # Guia detalhado multi-node
└── README.md                # Este arquivo
```

---

## 🔧 Troubleshooting

### Cluster multi-node não inicia

**Solução**:
```bash
# Aumentar recursos
minikube delete -p pspd-cluster
minikube start -p pspd-cluster --nodes 3 --cpus 4 --memory 8192
```

### Prometheus não coleta métricas

**Solução**:
```bash
# Verificar ServiceMonitors
kubectl get servicemonitor -n pspd

# Recriar
./scripts/deploy.sh monitoring

# Ver logs
kubectl logs -n monitoring prometheus-kube-prometheus-prometheus-0
```

### Port-forward cai durante testes

**Problema**: `connection reset by peer` em testes longos

**Solução**:
```bash
# Usar port-forward monitorado (reinicia automaticamente)
./scripts/deploy.sh port-forward
```

### HPA mostra `<unknown>` em TARGETS

**Normal** logo após deploy. Aguardar 30-60s para metrics-server coletar dados.

```bash
# Forçar coleta
kubectl top pods -n pspd
kubectl get hpa -n pspd  # Verificar novamente
```

### Pods não iniciam

```bash
# Ver logs
kubectl logs -n pspd <pod-name>

# Ver eventos
kubectl describe pod -n pspd <pod-name>

# Rebuild e redeploy
./scripts/build_images.sh
kubectl rollout restart deployment -n pspd p-deploy a-deploy b-deploy
```

### k6 não encontrado

```bash
# Ubuntu/Debian
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg \
  --keyserver hkp://keyserver.ubuntu.com:80 \
  --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" \
  | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6
```

### Verificar conectividade

```bash
# Executar guia de diagnóstico
./COMO_EXECUTAR.sh

# Deve mostrar:
# ✅ Gateway respondendo
# ✅ Métricas Prometheus expostas
```

---

## 🎯 Requisitos Acadêmicos Atendidos

### ✅ Cluster Multi-Node Implementado

**Requisito**: "Cluster composto por um nó mestre (plano de controle) e pelo menos dois nós escravos (worker nodes)"

**Implementação**:
```bash
./scripts/setup_multinode_cluster.sh
# Cria: 1 master (pspd-cluster) + 2 workers (pspd-cluster-m02, m03)
```

**Verificação**:
```bash
kubectl get nodes
# NAME               STATUS   ROLES           AGE
# pspd-cluster       Ready    control-plane   10m
# pspd-cluster-m02   Ready    worker          9m
# pspd-cluster-m03   Ready    worker          8m
```

### ✅ Prometheus Instalado no K8s

**Requisito**: "Estudar e instalar, no K8S, o Prometheus"

**Implementação**:
- kube-prometheus-stack via Helm
- Inclui: Prometheus Operator + Alertmanager
- ServiceMonitors configurados para scraping automático

**Verificação**:
```bash
kubectl get pods -n monitoring | grep prometheus
# prometheus-kube-prometheus-prometheus-0   2/2   Running

kubectl get servicemonitor -n pspd
# gateway-p-monitor, service-a-monitor, service-b-monitor
```

**Acesso**:
```bash
./scripts/deploy.sh prometheus
# http://localhost:9090
```

### ✅ Interface Web de Monitoramento

**Requisito**: "Interface web de monitoramento do cluster"

**Implementação**:
- Grafana instalado com kube-prometheus-stack
- Dashboard customizado em `k8s/monitoring/grafana-dashboard.json`
- Métricas: Request Rate, Duration, Replicas, CPU, Memory, Error Rate

**Verificação**:
```bash
kubectl get pods -n monitoring | grep grafana
# prometheus-grafana-xxx   3/3   Running
```

**Acesso**:
```bash
./scripts/deploy.sh grafana
# http://localhost:3000
# User: admin | Password: admin
```

**Dashboard inclui**:
- 📈 HTTP Request Rate por serviço
- ⏱️ Request Duration (p95, p99)
- 🔢 Pod Replicas (HPA)
- 💻 CPU Usage por pod
- 💾 Memory Usage por pod
- ❌ Error Rate

### ✅ Aplicação Instrumentada

- ✅ Gateway P: Express + prom-client
- ✅ Service A: Python + prometheus_client
- ✅ Service B: Python + prometheus_client
- ✅ Métricas HTTP e gRPC
- ✅ Histogramas de latência

### ✅ Testes de Carga e Análise

- ✅ 4 cenários k6 (baseline, ramp, spike, soak)
- ✅ Análise comparativa automatizada
- ✅ 6 gráficos gerados
- ✅ Captura de métricas K8s (HPA, CPU, Memory)

---

## 📈 Análise de Resultados

### Queries PromQL Úteis

```promql
# Throughput
rate(http_requests_total[1m])

# Latência p95
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[1m]))

# Taxa de erro
rate(http_requests_total{status_code=~"5.."}[1m]) / rate(http_requests_total[1m])

# CPU por pod
rate(container_cpu_usage_seconds_total{namespace="pspd"}[1m])
```

### Gráficos Gerados

Após `python3 scripts/analyze_results.py`:

1. `01_latency_comparison.png` - Latências médias/p90/p95
2. `02_throughput_comparison.png` - Req/s + total de requisições
3. `03_success_rate.png` - Taxa de sucesso vs falha
4. `04_hpa_scaling.png` - Evolução de réplicas (P, A, B)
5. `05_resource_usage.png` - CPU e memória
6. `06_latency_percentiles.png` - Distribuição completa

---

## 🎯 Próximos Passos (Opcional)

### Melhorias Futuras

1. **Alertas Prometheus**
   - Configurar AlertManager
   - Regras de alerta para latência alta, erro rate, etc.

2. **Testes Adicionais**
   - Variar réplicas mínimas/máximas do HPA
   - Testar distribuição de carga nos 2 workers
   - Cenários com falhas de nós

3. **Dashboards Adicionais**
   - Dashboard de infraestrutura K8s
   - Dashboard de rede (ingress/egress)
   - Dashboard de custos (resource quotas)

4. **CI/CD**
   - Pipeline GitHub Actions
   - Deploy automatizado
   - Testes automatizados

---

## 📚 Referências

- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [k6 Load Testing](https://k6.io/docs/)
- [Kubernetes HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [gRPC Observability](https://grpc.io/docs/guides/monitoring/)

---

## 👥 Autores

Projeto desenvolvido para a disciplina **PSPD - Programação para Sistemas Paralelos e Distribuídos**.

**Repositório**: [github.com/edilbertocantuaria/atividade-final-pspd](https://github.com/edilbertocantuaria/atividade-final-pspd)
