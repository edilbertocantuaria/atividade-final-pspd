# Projeto Final PSPD - Monitoramento e Observabilidade em Kubernetes

Projeto de pesquisa focado em monitoramento e observabilidade de aplicações baseadas em microserviços em clusters Kubernetes, com ênfase em métricas de desempenho.

## Arquitetura da Aplicação

A aplicação segue a arquitetura de microserviços gRPC proposta:

```
Cliente HTTP → Gateway P (Node.js + Express)
                    ↓ gRPC
              ┌─────┴─────┐
              ↓           ↓
        Service A    Service B
        (Python)     (Python)
```

- **Gateway P**: WEB API que recebe requisições HTTP e as distribui via gRPC
- **Service A**: Microserviço gRPC que responde com mensagens personalizadas
- **Service B**: Microserviço gRPC que retorna streams de números

## Instrumentação para Observabilidade

### Métricas Expostas

#### Gateway P (`/metrics` na porta 8080)
- `http_requests_total`: Total de requisições HTTP (labels: method, route, status_code)
- `http_request_duration_seconds`: Histograma de latência HTTP
- `grpc_client_requests_total`: Total de chamadas gRPC feitas
- `grpc_client_request_duration_seconds`: Latência das chamadas gRPC (por serviço)
- Métricas padrão Node.js (heap, event loop, etc.)

#### Service A (porta 9101/metrics)
- `grpc_server_requests_total`: Total de requisições gRPC recebidas
- `grpc_server_request_duration_seconds`: Latência do processamento

#### Service B (porta 9102/metrics)
- `grpc_server_requests_total`: Total de requisições gRPC recebidas
- `grpc_server_request_duration_seconds`: Latência do processamento
- `grpc_server_stream_items_total`: Total de itens enviados via streaming

## Estrutura do Projeto

```
atividade-final-pspd/
├── gateway_p_node/          # Gateway HTTP → gRPC
│   ├── server.js            # Instrumentado com prom-client
│   ├── package.json
│   └── Dockerfile
├── services/
│   ├── a_py/                # Service A (gRPC)
│   │   ├── server.py        # Instrumentado com prometheus_client
│   │   └── Dockerfile
│   └── b_py/                # Service B (gRPC)
│       ├── server.py        # Instrumentado com prometheus_client
│       └── Dockerfile
├── proto/                   # Definições Protocol Buffers
│   └── services.proto
├── k8s/                     # Manifestos Kubernetes
│   ├── namespace.yaml
│   ├── p.yaml               # Gateway deployment + service
│   ├── a.yaml               # Service A deployment + service
│   ├── b.yaml               # Service B deployment + service
│   ├── ingress.yaml
│   └── monitoring/
│       ├── hpa.yaml         # Horizontal Pod Autoscaler
│       ├── servicemonitor-p.yaml
│       └── servicemonitor-services.yaml
├── load/                    # Testes de carga (k6)
│   ├── baseline.js          # Teste base (10 VUs, 2min)
│   ├── ramp.js              # Teste de rampa (10→150 VUs)
│   ├── spike.js             # Teste de pico (10→200 VUs)
│   └── soak.js              # Teste de resistência (50 VUs, 10min)
├── scripts/                 # Scripts de automação
│   ├── build_images.sh      # Construir imagens Docker
│   ├── deploy.sh            # Deploy no K8s
│   ├── run_all_tests.sh     # Executar todos os testes
│   └── collect_metrics.sh   # Coletar métricas do Prometheus
└── results/                 # Resultados dos testes
    └── README.md
```

## Pré-requisitos

### Software Necessário
- Docker
- Kubernetes (minikube, kind, ou cluster multi-node)
- kubectl
- k6 (ferramenta de teste de carga)
- Prometheus Operator (instalado no cluster)

### Instalação do Prometheus Operator

```bash
# Usando Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace
```

## Quick Start

### 1. Construir Imagens Docker

```bash
./scripts/build_images.sh
```

### 2. Deploy no Kubernetes

```bash
./scripts/deploy.sh
```

### 3. Aplicar Configurações de Monitoramento

```bash
kubectl apply -f k8s/monitoring/
```

### 4. Verificar Pods

```bash
kubectl get pods -n pspd
kubectl get servicemonitor -n monitoring
kubectl get hpa -n pspd
```

### 5. Expor Serviços para Teste

```bash
# Gateway P
kubectl port-forward -n pspd svc/p-svc 8080:80

# Prometheus (se necessário)
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

### 6. Executar Testes de Carga

```bash
# Todos os testes
BASE_URL=http://localhost:8080 ./scripts/run_all_tests.sh

# Ou teste individual
k6 run -e BASE_URL=http://localhost:8080 load/baseline.js
```

## Cenários de Teste Propostos

### 1. **Baseline** (Configuração Base)
- 1 réplica de cada serviço (P, A, B)
- Sem autoscaling
- Teste: `baseline.js` (10 VUs, 2min)
- **Objetivo**: Estabelecer linha de base de desempenho

### 2. **Escala Horizontal do Gateway**
- Aumentar réplicas do Gateway P (2, 3, 5)
- A e B mantêm 1 réplica
- Teste: `ramp.js`
- **Objetivo**: Identificar impacto do scaling no frontend

### 3. **Escala dos Serviços Backend**
- Aumentar réplicas de A e B (2, 3)
- Gateway P mantém 1 réplica
- Teste: `ramp.js`
- **Objetivo**: Avaliar benefício de escalar serviços gRPC

### 4. **Autoscaling Ativo**
- Aplicar HPAs (CPU 70%)
- Teste: `spike.js` (10→200 VUs)
- **Objetivo**: Observar elasticidade automática e tempo de resposta

### 5. **Distribuição Multi-Node** (requer cluster real)
- P em node1, A em node2, B em node3
- Usar nodeAffinity/nodeSelector
- Teste: `baseline.js` e `ramp.js`
- **Objetivo**: Comparar latência de rede inter-node

### 6. **Resource Limits Agressivos**
- Reduzir limits de CPU/memória
- Teste: `soak.js`
- **Objetivo**: Observar throttling e impacto em latência

### 7. **Teste de Resiliência**
- Deletar pod durante teste
- Observar restarts e recuperação
- **Objetivo**: Medir impacto de falhas em SLOs

## Métricas a Observar

### Performance
- **Latência p50/p95/p99**: Tempo de resposta sob diferentes percentis
- **Throughput**: Requisições por segundo (`rate(http_requests_total[1m])`)
- **Taxa de Erro**: Percentual de requisições falhadas

### Infraestrutura
- **CPU/Memória**: Uso de recursos por pod
- **Restarts**: Número de reinicializações de containers
- **Réplicas**: Quantidade de pods ativos (autoscaling)

### Aplicação
- **Latência gRPC**: Tempo de resposta dos serviços A e B
- **Distribuição de Carga**: Requests distribuídos entre réplicas

## Queries PromQL Úteis

```promql
# Throughput total
rate(http_requests_total[1m])

# Latência p95 HTTP
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[1m]))

# Latência p99 gRPC
histogram_quantile(0.99, rate(grpc_client_request_duration_seconds_bucket[1m]))

# Taxa de erro
rate(http_requests_total{status_code=~"5.."}[1m]) / rate(http_requests_total[1m])

# CPU por pod
rate(container_cpu_usage_seconds_total{namespace="pspd"}[1m])

# Memória por pod
container_memory_working_set_bytes{namespace="pspd"}
```

## Próximos Passos

1. **Setup do Cluster**: Configurar cluster K8s multi-node
2. **Instalação do Prometheus**: Deploy do Prometheus Operator
3. **Validação Base**: Executar teste baseline e validar coleta de métricas
4. **Execução de Cenários**: Implementar e testar cada cenário proposto
5. **Coleta de Dados**: Capturar métricas de cada cenário via Prometheus
6. **Análise Comparativa**: Gerar gráficos e relatórios comparando cenários
7. **Documentação**: Consolidar resultados em relatório final

## Referências

- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [k6 Load Testing](https://k6.io/docs/)
- [Kubernetes Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [gRPC Observability](https://grpc.io/docs/guides/monitoring/)

## Autores

Projeto desenvolvido para a disciplina PSPD - Programação para Sistemas Paralelos e Distribuídos.
# atividade-final-pspd
