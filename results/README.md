# Resultados dos Testes de Observabilidade

Este diretório armazena os resultados dos testes de carga e métricas coletadas do Prometheus.

## Estrutura

```
results/
├── baseline.json         # Dados brutos k6 - teste baseline
├── baseline.txt          # Sumário k6 - teste baseline
├── ramp.json            # Dados brutos k6 - teste rampa
├── ramp.txt             # Sumário k6 - teste rampa
├── spike.json           # Dados brutos k6 - teste spike
├── spike.txt            # Sumário k6 - teste spike
├── soak.json            # Dados brutos k6 - teste soak (opcional)
├── soak.txt             # Sumário k6 - teste soak (opcional)
├── metrics/             # Métricas do Prometheus
│   ├── http_requests_total.json
│   ├── http_req_duration_p95.json
│   ├── cpu_usage.json
│   └── ...
└── cenarios/            # Resultados de cenários específicos
    ├── baseline/
    ├── scale_p/
    ├── scale_services/
    └── ...
```

## Métricas Coletadas

### Do k6 (Testes de Carga)
- `http_reqs`: Total de requisições HTTP
- `http_req_duration`: Latência das requisições (p50, p95, p99)
- `http_req_failed`: Taxa de falhas
- `vus`: Virtual users ativos
- `iterations`: Número de iterações completadas

### Do Prometheus (Aplicação)
- `http_requests_total`: Total de requisições (por método, rota, status)
- `http_request_duration_seconds`: Histograma de latência HTTP
- `grpc_client_requests_total`: Total de requisições gRPC
- `grpc_client_request_duration_seconds`: Latência das chamadas gRPC
- `grpc_server_requests_total`: Requisições recebidas pelos serviços
- `grpc_server_request_duration_seconds`: Latência do processamento

### Do Kubernetes (Infraestrutura)
- `container_cpu_usage_seconds_total`: Uso de CPU por container
- `container_memory_working_set_bytes`: Uso de memória
- `kube_pod_container_status_restarts_total`: Número de restarts
- `kube_deployment_spec_replicas`: Número de réplicas desejadas
- `kube_deployment_status_replicas_available`: Réplicas disponíveis

## Análise

Use `../scripts/collect_metrics.sh` para coletar métricas específicas durante os testes.
