# Projeto Final PSPD - Monitoramento e Observabilidade em Kubernetes

> Projeto de pesquisa focado em monitoramento e observabilidade de aplicações baseadas em microserviços em clusters Kubernetes, com ênfase em métricas de desempenho.

## 📋 Índice

- [Arquitetura](#-arquitetura)
- [Quick Start](#-quick-start)
- [Como Executar](#-como-executar)
- [Testes de Carga](#-testes-de-carga)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Troubleshooting](#-troubleshooting)

---

## 🏗️ Arquitetura

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

## 🚀 Quick Start

### Pré-requisitos
```bash
# Verificar ferramentas instaladas
minikube version
kubectl version --client
docker --version
k6 version
python3 --version
```

### Setup Completo (5 minutos)

```bash
# 1. Iniciar cluster
minikube start --cpus=4 --memory=8192
minikube addons enable ingress metrics-server

# 2. Build e Deploy
./scripts/build_images.sh
./scripts/deploy.sh
kubectl wait --for=condition=ready pod --all -n pspd --timeout=180s

# 3. Verificar
kubectl get pods -n pspd        # 3 pods Running
kubectl get hpa -n pspd         # 3 HPAs criados
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

### Cenários Implementados

| Teste | Duração | Carga | Objetivo |
|-------|---------|-------|----------|
| **baseline.js** | 2 min | 10 VUs constantes | Linha de base de performance |
| **ramp.js** | 4 min | 10→150 VUs gradual | Testar autoscaling (HPA) |
| **spike.js** | 2 min | 10→200 VUs súbito | Resiliência a picos |
| **soak.js** | 11 min | 50 VUs sustentado | Estabilidade long-term |

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
Ramp: HPA escala 1→3 réplicas, p95 < 500ms
Spike: Taxa erro < 5%, p95 ~2s durante pico
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
│       └── servicemonitor-*.yaml  # Prometheus ServiceMonitors
├── load/                    # 4 cenários k6
├── scripts/
│   ├── build_images.sh      # Build Docker
│   ├── deploy.sh            # Deploy K8s
│   ├── run_all_tests.sh     # Suite completa
│   ├── stable_port_forward.sh  # Port-forward com auto-restart
│   ├── monitor.sh           # Dashboard tempo real
│   └── analyze_results.py   # Gerar gráficos
├── results/
│   ├── baseline/            # Resultados baseline
│   ├── ramp/                # Resultados ramp
│   ├── spike/               # Resultados spike
│   ├── soak/                # Resultados soak
│   └── plots/               # Gráficos + relatório
└── README.md                # Este arquivo
```

---

## 🔧 Troubleshooting

### Port-forward cai durante testes

**Problema**: `connection reset by peer` em testes longos

**Solução**:
```bash
# Usar port-forward monitorado (reinicia automaticamente)
./scripts/stable_port_forward.sh
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

## 🎯 Próximos Passos (Trabalho Acadêmico)

Para atender completamente a especificação do projeto:

### ❌ Falta Implementar

1. **Cluster Multi-Node** (CRÍTICO)
   - Especificação requer: 1 master + 2 workers
   - Atual: Minikube single-node
   - Ação: Migrar para kubeadm, kind multi-node, ou cluster cloud

2. **Prometheus Instalado no K8s** (CRÍTICO)
   - ServiceMonitors criados mas Prometheus não instalado
   - Ação: `helm install prometheus-community/kube-prometheus-stack`

3. **Interface Web de Monitoramento** (CRÍTICO)
   - Grafana com dashboards customizados
   - Ou Kubernetes Dashboard

4. **Cenários Comparativos Expandidos**
   - Variar: réplicas, recursos, distribuição multi-node
   - Documentar conclusões de cada cenário

### ✅ Já Implementado

- ✅ Aplicação gRPC (Gateway P + Service A + Service B)
- ✅ Instrumentação Prometheus completa
- ✅ Testes de carga (4 cenários)
- ✅ HPA (autoscaling)
- ✅ Scripts de automação
- ✅ Análise comparativa com gráficos

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
