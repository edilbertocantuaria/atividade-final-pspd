# 📊 Métricas Prometheus Customizadas

## Visão Geral

Todos os três serviços (A, B e P) foram instrumentados com métricas customizadas usando Prometheus client libraries:
- **Serviços A e B (Python)**: `prometheus-client==0.20.0`
- **Gateway P (Node.js)**: `prom-client==15.1.0`

---

## Serviço A (Python gRPC)

### Porta de Métricas
- **Porta**: `9101`
- **Endpoint**: `http://<pod-ip>:9101/metrics`

### Métricas Expostas

#### `grpc_server_requests_total`
- **Tipo**: Counter
- **Descrição**: Total de requisições gRPC recebidas pelo serviço A
- **Labels**:
  - `method`: Nome do método gRPC (ex: `GetContent`)
  - `status`: Resultado (`success` ou `error`)

#### `grpc_server_request_duration_seconds`
- **Tipo**: Histogram
- **Descrição**: Latência das requisições gRPC em segundos
- **Labels**:
  - `method`: Nome do método gRPC
- **Buckets**: `[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2, 5]`

### Queries PromQL Úteis

```promql
# Taxa de requisições por segundo
rate(grpc_server_requests_total{container="a"}[1m])

# Taxa de erros
rate(grpc_server_requests_total{container="a",status="error"}[1m])

# Latência P50
histogram_quantile(0.50, rate(grpc_server_request_duration_seconds_bucket{container="a"}[1m]))

# Latência P95
histogram_quantile(0.95, rate(grpc_server_request_duration_seconds_bucket{container="a"}[1m]))

# Latência P99
histogram_quantile(0.99, rate(grpc_server_request_duration_seconds_bucket{container="a"}[1m]))
```

---

## Serviço B (Python gRPC Streaming)

### Porta de Métricas
- **Porta**: `9102`
- **Endpoint**: `http://<pod-ip>:9102/metrics`

### Métricas Expostas

#### `grpc_server_requests_total`
- **Tipo**: Counter
- **Descrição**: Total de requisições gRPC recebidas pelo serviço B
- **Labels**:
  - `method`: Nome do método gRPC (ex: `StreamMetadata`)
  - `status`: Resultado (`success` ou `error`)

#### `grpc_server_request_duration_seconds`
- **Tipo**: Histogram
- **Descrição**: Latência das requisições gRPC em segundos (streaming completo)
- **Labels**:
  - `method`: Nome do método gRPC
- **Buckets**: `[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2, 5]`

#### `grpc_server_stream_items_total`
- **Tipo**: Counter
- **Descrição**: Total de items enviados via streaming
- **Labels**:
  - `method`: Nome do método gRPC

### Queries PromQL Úteis

```promql
# Taxa de requisições streaming por segundo
rate(grpc_server_requests_total{container="b",method="StreamMetadata"}[1m])

# Items streamed por segundo
rate(grpc_server_stream_items_total{container="b"}[1m])

# Latência média do streaming
rate(grpc_server_request_duration_seconds_sum{container="b"}[1m]) 
/ 
rate(grpc_server_request_duration_seconds_count{container="b"}[1m])

# Latência P95 do streaming
histogram_quantile(0.95, rate(grpc_server_request_duration_seconds_bucket{container="b"}[1m]))
```

---

## Gateway P (Node.js HTTP + gRPC Client)

### Porta de Métricas
- **Porta**: `8080` (mesma porta HTTP)
- **Endpoint**: `http://<pod-ip>:8080/metrics`

### Métricas Expostas

#### `http_requests_total`
- **Tipo**: Counter
- **Descrição**: Total de requisições HTTP recebidas pelo gateway
- **Labels**:
  - `method`: Método HTTP (ex: `GET`)
  - `route`: Rota acessada (ex: `/api/content`)
  - `status_code`: Código de resposta HTTP

#### `http_request_duration_seconds`
- **Tipo**: Histogram
- **Descrição**: Latência das requisições HTTP em segundos
- **Labels**:
  - `method`: Método HTTP
  - `route`: Rota acessada
  - `status_code`: Código de resposta HTTP
- **Buckets**: `[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2, 5]`

#### `grpc_client_requests_total`
- **Tipo**: Counter
- **Descrição**: Total de requisições gRPC feitas pelo gateway aos serviços A e B
- **Labels**:
  - `service`: Serviço destino (`ServiceA` ou `ServiceB`)
  - `method`: Método gRPC chamado
  - `status`: Resultado (`success` ou `error`)

#### `grpc_client_request_duration_seconds`
- **Tipo**: Histogram
- **Descrição**: Latência das chamadas gRPC feitas pelo gateway
- **Labels**:
  - `service`: Serviço destino
  - `method`: Método gRPC chamado
  - `status`: Resultado
- **Buckets**: `[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2, 5]`

#### Métricas Padrão do Node.js
O gateway também expõe métricas padrão do processo Node.js:
- `process_cpu_user_seconds_total`
- `process_resident_memory_bytes`
- `nodejs_heap_size_total_bytes`
- `nodejs_eventloop_lag_seconds`

### Queries PromQL Úteis

```promql
# Taxa de requisições HTTP por segundo
rate(http_requests_total{container="p"}[1m])

# Taxa de erros HTTP (5xx)
rate(http_requests_total{container="p",status_code=~"5.."}[1m])

# Latência P95 HTTP
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{container="p"}[1m]))

# Taxa de chamadas gRPC para serviço A
rate(grpc_client_requests_total{container="p",service="ServiceA"}[1m])

# Latência P95 das chamadas gRPC
histogram_quantile(0.95, rate(grpc_client_request_duration_seconds_bucket{container="p"}[1m]))

# Erros gRPC por serviço
rate(grpc_client_requests_total{container="p",status="error"}[1m])

# Uso de memória do processo Node.js
process_resident_memory_bytes{container="p"}
```

---

## ServiceMonitors Configurados

### Service A Monitor
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: service-a-monitor
  namespace: pspd
spec:
  selector:
    matchLabels:
      app: a
  endpoints:
  - port: metrics
    interval: 15s
    path: /metrics
```

### Service B Monitor
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: service-b-monitor
  namespace: pspd
spec:
  selector:
    matchLabels:
      app: b
  endpoints:
  - port: metrics
    interval: 15s
    path: /metrics
```

### Gateway P Monitor
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: gateway-p-metrics
  namespace: pspd
spec:
  selector:
    matchLabels:
      app: p
  endpoints:
    - port: metrics
      path: /metrics
      interval: 15s
```

---

## Verificação de Métricas

### Verificação Manual via port-forward

#### Teste local via port-forward
```bash
# Serviço A
kubectl port-forward -n pspd svc/a-svc 9101:9101
curl http://localhost:9101/metrics | grep grpc_server

# Serviço B
kubectl port-forward -n pspd svc/b-svc 9102:9102
curl http://localhost:9102/metrics | grep grpc_server

# Gateway P
kubectl port-forward -n pspd svc/p-svc 8080:8080
curl http://localhost:8080/metrics | grep -E "(http_|grpc_client)"
```

#### Verificar targets no Prometheus
```bash
# Port-forward do Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Acessar: http://localhost:9090/targets
# Procurar por: serviceMonitor/pspd/service-a-monitor/0
```

---

## 📊 Acessar Grafana

### Port-Forward
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```
Acesse: http://localhost:3000

### Credenciais
- **Usuário**: `admin`
- **Senha**: Recuperar do secret:
```bash
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d
```

### Importar Dashboard Customizado

1. Acesse Grafana → **+** → **Import**
2. Upload: `k8s/monitoring/grafana-dashboard.json`
3. Selecione **prometheus** como data source
4. Clique em **Import**

---

## Dashboards Grafana Sugeridos

### Dashboard: Visão Geral da Aplicação

#### Painel 1: Taxa de Requisições
```promql
# HTTP (Gateway P)
sum(rate(http_requests_total{container="p"}[1m])) by (route)

# gRPC Serviço A
sum(rate(grpc_server_requests_total{container="a"}[1m])) by (method)

# gRPC Serviço B
sum(rate(grpc_server_requests_total{container="b"}[1m])) by (method)
```

#### Painel 2: Latência P95
```promql
# Gateway P (HTTP)
histogram_quantile(0.95, 
  sum(rate(http_request_duration_seconds_bucket{container="p"}[1m])) by (le, route)
)

# Serviço A
histogram_quantile(0.95, 
  sum(rate(grpc_server_request_duration_seconds_bucket{container="a"}[1m])) by (le)
)

# Serviço B
histogram_quantile(0.95, 
  sum(rate(grpc_server_request_duration_seconds_bucket{container="b"}[1m])) by (le)
)
```

#### Painel 3: Taxa de Erros
```promql
# HTTP 5xx
sum(rate(http_requests_total{container="p",status_code=~"5.."}[1m]))

# gRPC Errors (Gateway → A/B)
sum(rate(grpc_client_requests_total{container="p",status="error"}[1m])) by (service)

# gRPC Errors (Serviços A e B)
sum(rate(grpc_server_requests_total{status="error"}[1m])) by (app)
```

#### Painel 4: Throughput gRPC Client (Gateway P)
```promql
sum(rate(grpc_client_requests_total{container="p",status="success"}[1m])) by (service, method)
```

#### Painel 5: Streaming (Serviço B)
```promql
# Items por segundo
rate(grpc_server_stream_items_total{container="b"}[1m])

# Streams ativos
grpc_server_requests_total{container="b",method="StreamMetadata"} - grpc_server_requests_total{container="b",method="StreamMetadata"} offset 1m
```

---

## Integração com Testes k6

Durante os testes de carga, você pode correlacionar:

1. **Métricas k6** (cliente):
   - `http_req_duration` → Latência percebida pelo cliente
   - `http_reqs` → Taxa de requisições enviadas
   - `http_req_failed` → Taxa de falhas

2. **Métricas Prometheus** (servidor):
   - `http_request_duration_seconds` → Latência no gateway
   - `grpc_client_request_duration_seconds` → Latência nas chamadas gRPC
   - `grpc_server_request_duration_seconds` → Latência nos serviços A/B

**Análise útil**:
```
Latência Total (k6) = 
  Latência Gateway (http_request_duration) + 
  Latência gRPC A (grpc_client_request_duration) + 
  Latência gRPC B (grpc_client_request_duration) +
  Network overhead
```

---

## Troubleshooting

### Métricas não aparecem no Prometheus

1. **Verificar ServiceMonitor**:
```bash
kubectl get servicemonitor -n pspd
kubectl describe servicemonitor service-a-monitor -n pspd
```

2. **Verificar labels no Prometheus Operator**:
```bash
kubectl get prometheus -n monitoring -o yaml | grep serviceMonitorSelector -A 5
```

3. **Verificar targets no Prometheus**:
   - Acesse `http://localhost:9090/targets`
   - Procure por `pspd/service-a-monitor`
   - Se estiver **DOWN**, verifique logs do pod

4. **Testar endpoint manualmente**:
```bash
kubectl exec -n pspd <pod-a> -- curl localhost:9101/metrics
```

### Métricas vazias após deploy

- Métricas tipo **Counter** e **Histogram** só aparecem após receber dados
- Faça requisições de teste:
```bash
curl "http://localhost:8080/api/content?type=all&limit=5"
curl "http://localhost:8080/api/metadata/m1?userId=test"
```

### Port-forward falha

```bash
# Verificar se pod está Ready
kubectl get pods -n pspd

# Verificar logs
kubectl logs -n pspd <pod-name>

# Verificar se porta está ouvindo
kubectl exec -n pspd <pod-name> -- netstat -tuln | grep 9101
```

---

## Resumo das Portas

| Serviço | Porta gRPC | Porta Métricas | Endpoint |
|---------|-----------|----------------|----------|
| A       | 50051     | 9101          | `/metrics` |
| B       | 50052     | 9102          | `/metrics` |
| P       | 8080      | 8080          | `/metrics` |

---

## Próximos Passos

1. ✅ Métricas implementadas
2. ✅ ServiceMonitors configurados
3. ⏳ Verificar métricas via port-forward (comandos acima)
4. ⏳ Criar dashboards Grafana customizados
5. ⏳ Executar testes de carga e correlacionar métricas
6. ⏳ Documentar insights obtidos das métricas
