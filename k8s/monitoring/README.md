# Monitoramento e Observabilidade

Configurações de HPA e ServiceMonitors para coleta de métricas Prometheus.

## Arquivos

### HPA (Horizontal Pod Autoscaler)
- **`hpa.yaml`**: Configuração de autoscaling para os 3 serviços (A, B, P)
  - Target CPU: 70%
  - Min replicas: 1
  - Max replicas: 10

### ServiceMonitors (Prometheus Operator)
- **`servicemonitor-a.yaml`**: Scraping de métricas do Serviço A (porta 9101)
- **`servicemonitor-b.yaml`**: Scraping de métricas do Serviço B (porta 9102)
- **`servicemonitor-p.yaml`**: Scraping de métricas do Gateway P (porta 8080)

## Como Aplicar

```bash
# Aplicar todas as configurações
kubectl apply -f k8s/monitoring/

# Verificar HPA
kubectl get hpa -n pspd

# Verificar ServiceMonitors
kubectl get servicemonitor -n pspd

# Ver targets no Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Acessar: http://localhost:9090/targets
```

## Métricas Coletadas

### Serviço A (9101/metrics)
- `grpc_server_requests_total{method,status}`
- `grpc_server_request_duration_seconds{method}`

### Serviço B (9102/metrics)
- `grpc_server_requests_total{method,status}`
- `grpc_server_request_duration_seconds{method}`
- `grpc_server_stream_items_total{method}`

### Gateway P (8080/metrics)
- `http_requests_total{method,route,status_code}`
- `http_request_duration_seconds{method,route,status_code}`
- `grpc_client_requests_total{service,method,status}`
- `grpc_client_request_duration_seconds{service,method,status}`

## Troubleshooting

### ServiceMonitor não aparece no Prometheus

1. Verificar se Prometheus Operator está rodando:
```bash
kubectl get pods -n monitoring | grep prometheus-operator
```

2. Verificar labels do ServiceMonitor:
```bash
kubectl describe servicemonitor service-a-monitor -n pspd
```

3. Verificar se Prometheus está configurado para buscar ServiceMonitors no namespace `pspd`:
```bash
kubectl get prometheus -n monitoring -o yaml | grep serviceMonitorNamespaceSelector -A 5
```

Se necessário, editar Prometheus para aceitar todos os namespaces:
```yaml
serviceMonitorNamespaceSelector: {}
```

### Métricas não aparecem

1. Testar endpoint diretamente:
```bash
kubectl port-forward -n pspd svc/a-svc 9101:9101
curl http://localhost:9101/metrics | grep grpc_server
```

2. Verificar logs do pod:
```bash
kubectl logs -n pspd <pod-a-name>
```

3. Executar script de verificação:
```bash
./scripts/verify_metrics.sh
```

## Documentação Completa

Ver: `docs/METRICAS_PROMETHEUS.md`
