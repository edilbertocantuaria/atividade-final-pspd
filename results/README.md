# Resultados dos Testes de Observabilidade

Este diretório armazena os resultados dos testes de carga e métricas coletadas.

## Estrutura

```
results/
├── baseline/                    # Teste baseline (10 VUs constante)
│   ├── metrics.json             # Dados brutos k6
│   ├── output.txt               # Sumário k6
│   ├── pod-metrics-{pre|post}.txt
│   └── hpa-status-{pre|post}.txt
├── ramp/                        # Teste ramp (10→150 VUs gradual)
├── spike/                       # Teste spike (10→200 VUs súbito)
│   └── events.txt               # Eventos K8s (scaling)
├── stress/                      # Teste stress (10→200 VUs progressivo) [opcional]
├── soak/                        # Teste soak (50 VUs por 10 min)
├── plots/                       # GRÁFICOS GERADOS
│   ├── 01_latency_comparison.png
│   ├── 02_throughput_comparison.png
│   ├── 03_success_rate.png
│   ├── 04_hpa_scaling.png
│   ├── 05_resource_usage.png
│   ├── 06_latency_percentiles.png
│   └── SUMMARY_REPORT.txt
├── hpa-final.yaml               # Configuração HPA após testes
├── pods-final.txt               # Estado final dos pods
├── events-history.txt           # Histórico de eventos K8s
├── prometheus-metrics.txt       # Snapshot de métricas Prometheus
├── gateway-logs.txt             # Logs do gateway
├── service-a-logs.txt           # Logs do serviço A
└── service-b-logs.txt           # Logs do serviço B
```

## Métricas Coletadas

### Do k6 (Testes de Carga)
- `http_reqs`: Total de requisições HTTP
- `http_req_duration`: Latência (p50, p95, p99)
- `http_req_failed`: Taxa de falhas
- `vus`: Virtual users ativos
- `iterations`: Iterações completadas

### Do Prometheus (Aplicação)
- `http_requests_total`: Total de requisições por método/rota/status
- `http_request_duration_seconds`: Histograma de latência HTTP
- `grpc_client_requests_total`: Total de requisições gRPC cliente
- `grpc_client_request_duration_seconds`: Latência gRPC cliente
- `grpc_server_requests_total`: Requisições recebidas (servidor)
- `grpc_server_request_duration_seconds`: Latência gRPC servidor

### Do Kubernetes (Infraestrutura)
- `container_cpu_usage_seconds_total`: Uso de CPU
- `container_memory_working_set_bytes`: Uso de memória
- `kube_pod_container_status_restarts_total`: Restarts
- `kube_deployment_spec_replicas`: Réplicas desejadas
- `kube_deployment_status_replicas_available`: Réplicas disponíveis

## Análise

Gerar gráficos e relatório:
```bash
python3 scripts/analyze_results.py
```

Executar testes:
```bash
./scripts/run_all_tests.sh all
```
