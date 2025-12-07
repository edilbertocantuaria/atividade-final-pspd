# 📊 Queries PromQL para Análise de Cenários

Guia completo de queries PromQL otimizadas para análise de performance, latência, throughput e comportamento do sistema durante execução de cenários de teste.

---

## 🎯 Índice Rápido

- [Queries Básicas - Primeiros Passos](#queries-básicas---primeiros-passos)
- [Requisições HTTP - Taxa e Volume](#requisições-http---taxa-e-volume)
- [Latência e Performance](#latência-e-performance)
- [Análise de Erros](#análise-de-erros)
- [gRPC - Services A e B](#grpc---services-a-e-b)
- [Recursos - CPU e Memória](#recursos---cpu-e-memória)
- [HPA - Autoscaling](#hpa---autoscaling)
- [Comparação Entre Cenários](#comparação-entre-cenários)
- [Queries Avançadas - Análise Profunda](#queries-avançadas---análise-profunda)
- [Dashboard em Tempo Real](#dashboard-em-tempo-real)

---

## 🚀 Queries Básicas - Primeiros Passos

### Ver se métricas estão sendo coletadas
```promql
# Verificar se todos os serviços estão UP
up{namespace="pspd"}

# Última vez que Prometheus coletou métricas
time() - timestamp(up{namespace="pspd"})
```

### Total de requisições até agora
```promql
# Total geral
http_requests_total

# Por endpoint
http_requests_total{route="/api/content"}

# Por método HTTP
http_requests_total{method="GET"}

# Por status code
http_requests_total{status_code="200"}
```

### Primeira query para testar
```promql
# Quantas requisições aconteceram nos últimos 5 minutos
increase(http_requests_total[5m])
```

---

## 📈 Requisições HTTP - Taxa e Volume

### Taxa de Requisições (req/s)

```promql
# Taxa geral do Gateway P (últimos 1 min)
rate(http_requests_total{container="p"}[1m])

# Taxa por endpoint
sum by (route) (rate(http_requests_total{container="p"}[1m]))

# Taxa de sucesso (200-299)
sum(rate(http_requests_total{container="p",status_code=~"2.."}[1m]))

# Taxa total agregada (todas as rotas)
sum(rate(http_requests_total{container="p"}[1m]))
```

### Volume de Requisições

```promql
# Total nos últimos 5 minutos
sum(increase(http_requests_total{container="p"}[5m]))

# Por endpoint nos últimos 5 minutos
sum by (route) (increase(http_requests_total{container="p"}[5m]))

# Endpoints mais acessados (top 5)
topk(5, sum by (route) (increase(http_requests_total{container="p"}[5m])))

# Evolução ao longo do tempo (janela de 30s)
sum(rate(http_requests_total{container="p"}[30s]))
```

### Comparar Antes vs Durante vs Depois do Teste

```promql
# Taxa atual
sum(rate(http_requests_total{container="p"}[1m]))

# Taxa 5 minutos atrás
sum(rate(http_requests_total{container="p"}[1m] offset 5m))

# Diferença percentual
(sum(rate(http_requests_total{container="p"}[1m])) 
 - sum(rate(http_requests_total{container="p"}[1m] offset 5m))) 
/ sum(rate(http_requests_total{container="p"}[1m] offset 5m)) * 100
```

---

## ⏱️ Latência e Performance

### Latência Média

```promql
# Latência média geral (em segundos)
rate(http_request_duration_seconds_sum{container="p"}[1m]) 
/ rate(http_request_duration_seconds_count{container="p"}[1m])

# Latência média por endpoint
sum by (route) (rate(http_request_duration_seconds_sum{container="p"}[1m])) 
/ sum by (route) (rate(http_request_duration_seconds_count{container="p"}[1m]))

# Converter para milissegundos (multiplicar por 1000)
(rate(http_request_duration_seconds_sum{container="p"}[1m]) 
 / rate(http_request_duration_seconds_count{container="p"}[1m])) * 1000
```

### Percentis de Latência (P50, P95, P99)

```promql
# P50 (mediana) - 50% das requisições abaixo desse valor
histogram_quantile(0.50, 
  sum by (le) (rate(http_request_duration_seconds_bucket{container="p"}[1m]))
)

# P95 - 95% das requisições abaixo desse valor
histogram_quantile(0.95, 
  sum by (le) (rate(http_request_duration_seconds_bucket{container="p"}[1m]))
)

# P99 - 99% das requisições abaixo desse valor
histogram_quantile(0.99, 
  sum by (le) (rate(http_request_duration_seconds_bucket{container="p"}[1m]))
)

# P95 por endpoint (identificar gargalos)
histogram_quantile(0.95, 
  sum by (le, route) (rate(http_request_duration_seconds_bucket{container="p"}[5m]))
)

# Todos os percentis juntos (para dashboard)
label_replace(
  histogram_quantile(0.50, sum by (le) (rate(http_request_duration_seconds_bucket{container="p"}[1m]))),
  "quantile", "p50", "", ""
) or
label_replace(
  histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{container="p"}[1m]))),
  "quantile", "p95", "", ""
) or
label_replace(
  histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{container="p"}[1m]))),
  "quantile", "p99", "", ""
)
```

### Latência Máxima Observada

```promql
# Maior latência no bucket (aproximação)
max(http_request_duration_seconds_bucket{container="p"})

# Latência máxima por endpoint
max by (route) (http_request_duration_seconds_bucket{container="p"})
```

---

## 🚨 Análise de Erros

### Taxa de Erros

```promql
# Erros 4xx (client errors)
sum(rate(http_requests_total{container="p",status_code=~"4.."}[1m]))

# Erros 5xx (server errors)
sum(rate(http_requests_total{container="p",status_code=~"5.."}[1m]))

# Taxa de erro total (%)
sum(rate(http_requests_total{container="p",status_code=~"[45].."}[1m])) 
/ sum(rate(http_requests_total{container="p"}[1m])) * 100

# Erro por endpoint
sum by (route, status_code) (rate(http_requests_total{container="p",status_code=~"[45].."}[1m]))
```

### Erros por Tipo

```promql
# Contar cada tipo de erro
sum by (status_code) (increase(http_requests_total{container="p",status_code=~"[45].."}[5m]))

# Endpoints com mais erros
topk(5, sum by (route) (increase(http_requests_total{container="p",status_code=~"[45].."}[5m])))
```

### SLA - Service Level Agreement

```promql
# Availability (% de requisições com sucesso)
sum(rate(http_requests_total{container="p",status_code=~"2.."}[5m])) 
/ sum(rate(http_requests_total{container="p"}[5m])) * 100

# Uptime dos serviços
avg_over_time(up{namespace="pspd"}[5m]) * 100
```

---

## 🔌 gRPC - Services A e B

### Service A (Catálogo)

```promql
# Taxa de requisições gRPC
rate(grpc_server_requests_total{container="a"}[1m])

# Por método gRPC
sum by (method) (rate(grpc_server_requests_total{container="a"}[1m]))

# Taxa de sucesso
rate(grpc_server_requests_total{container="a",status="success"}[1m])

# Taxa de erro
rate(grpc_server_requests_total{container="a",status="error"}[1m])

# Latência gRPC (P95)
histogram_quantile(0.95, 
  rate(grpc_server_duration_seconds_bucket{container="a"}[1m])
)
```

### Service B (Metadata - Streaming)

```promql
# Taxa de streams iniciados
rate(grpc_server_requests_total{container="b"}[1m])

# Itens enviados por segundo (streaming)
rate(grpc_server_stream_items_total{container="b"}[1m])

# Média de itens por stream
rate(grpc_server_stream_items_total{container="b"}[1m]) 
/ rate(grpc_server_requests_total{container="b"}[1m])

# Latência do streaming
histogram_quantile(0.95, 
  rate(grpc_server_duration_seconds_bucket{container="b"}[1m])
)
```

### Comparar A vs B

```promql
# Taxa de requisições - Service A vs B
sum by (container) (rate(grpc_server_requests_total{container=~"a|b"}[1m]))

# Latência P95 - A vs B
histogram_quantile(0.95, 
  sum by (le, container) (rate(grpc_server_duration_seconds_bucket{container=~"a|b"}[1m]))
)
```

---

## 💻 Recursos - CPU e Memória

### CPU

```promql
# CPU por pod (em cores)
sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="pspd"}[1m]))

# CPU por container
sum by (container) (rate(container_cpu_usage_seconds_total{namespace="pspd"}[1m]))

# CPU total do namespace
sum(rate(container_cpu_usage_seconds_total{namespace="pspd"}[1m]))

# % de CPU usada (vs request)
sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="pspd"}[1m])) 
/ sum by (pod) (kube_pod_container_resource_requests{namespace="pspd",resource="cpu"}) * 100

# Picos de CPU (máximo nos últimos 5 min)
max_over_time(
  sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="pspd"}[1m]))[5m:30s]
)
```

### Memória

```promql
# Memória Working Set por pod (em MB)
sum by (pod) (container_memory_working_set_bytes{namespace="pspd"}) / 1024 / 1024

# Memória RSS (Resident Set Size)
sum by (pod) (container_memory_rss{namespace="pspd"}) / 1024 / 1024

# % de memória usada (vs limit)
sum by (pod) (container_memory_working_set_bytes{namespace="pspd"}) 
/ sum by (pod) (kube_pod_container_resource_limits{namespace="pspd",resource="memory"}) * 100

# Crescimento de memória (últimos 5 min)
delta(container_memory_working_set_bytes{namespace="pspd"}[5m]) / 1024 / 1024
```

### Uso de Recursos Combinado

```promql
# CPU e Memória juntos (para dashboard)
sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="pspd"}[1m]))
# E em outro painel:
sum by (pod) (container_memory_working_set_bytes{namespace="pspd"}) / 1024 / 1024
```

---

## 📊 HPA - Autoscaling

### Réplicas

```promql
# Número atual de réplicas
kube_horizontalpodautoscaler_status_current_replicas{namespace="pspd"}

# Réplicas desejadas pelo HPA
kube_horizontalpodautoscaler_status_desired_replicas{namespace="pspd"}

# Limite de réplicas (min e max)
kube_horizontalpodautoscaler_spec_min_replicas{namespace="pspd"}
kube_horizontalpodautoscaler_spec_max_replicas{namespace="pspd"}

# Todas juntas (para comparação)
kube_horizontalpodautoscaler_status_current_replicas{namespace="pspd"} or
kube_horizontalpodautoscaler_status_desired_replicas{namespace="pspd"} or
kube_horizontalpodautoscaler_spec_max_replicas{namespace="pspd"}
```

### Métricas que Disparam HPA

```promql
# CPU atual que o HPA está observando
sum(rate(container_cpu_usage_seconds_total{namespace="pspd"}[1m])) by (pod)

# Target de CPU do HPA (50% = 0.5)
kube_horizontalpodautoscaler_spec_target_metric{namespace="pspd",metric_name="cpu"}

# CPU vs Target (para ver se vai escalar)
(sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="pspd"}[1m])) 
 / sum by (pod) (kube_pod_container_resource_requests{namespace="pspd",resource="cpu"})) * 100
```

### Histórico de Scaling

```promql
# Mudanças nas réplicas (delta)
delta(kube_horizontalpodautoscaler_status_current_replicas{namespace="pspd"}[5m])

# Tempo desde última mudança
changes(kube_horizontalpodautoscaler_status_current_replicas{namespace="pspd"}[10m])
```

---

## 🔬 Comparação Entre Cenários

### Template para Comparar Dois Cenários

```promql
# Taxa de requisições - Cenário 1 (baseline) vs Cenário 2 (spike)
# Execute na hora do baseline:
sum(rate(http_requests_total{container="p"}[1m]))

# Execute na hora do spike:
sum(rate(http_requests_total{container="p"}[1m]))

# Para comparar depois, use offset:
# Baseline (5min atrás)
sum(rate(http_requests_total{container="p"}[1m] offset 5m))
# Spike (agora)
sum(rate(http_requests_total{container="p"}[1m]))
```

### Diferença Percentual

```promql
# Aumento de throughput (%)
(sum(rate(http_requests_total{container="p"}[1m])) 
 - sum(rate(http_requests_total{container="p"}[1m] offset 10m))) 
/ sum(rate(http_requests_total{container="p"}[1m] offset 10m)) * 100

# Redução de latência (%)
(histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{container="p"}[1m] offset 10m)))
 - histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{container="p"}[1m])))) 
/ histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{container="p"}[1m] offset 10m))) * 100
```

### Métricas Consolidadas por Cenário

Use estas queries durante cada cenário e anote os valores:

```promql
# 1. Throughput médio (req/s)
avg_over_time(sum(rate(http_requests_total{container="p"}[1m]))[5m:30s])

# 2. Latência P95 média (ms)
avg_over_time(
  histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{container="p"}[1m])))[5m:30s]
) * 1000

# 3. Taxa de erro média (%)
avg_over_time(
  (sum(rate(http_requests_total{container="p",status_code=~"[45].."}[1m])) 
   / sum(rate(http_requests_total{container="p"}[1m])) * 100)[5m:30s]
)

# 4. CPU médio (cores)
avg_over_time(sum(rate(container_cpu_usage_seconds_total{namespace="pspd"}[1m]))[5m:30s])

# 5. Réplicas médias
avg_over_time(kube_horizontalpodautoscaler_status_current_replicas{namespace="pspd"}[5m])
```

---

## 🎓 Queries Avançadas - Análise Profunda

### Correlação Latência vs Carga

```promql
# Latência aumenta quando throughput sobe?
# Gráfico 1: Throughput
sum(rate(http_requests_total{container="p"}[1m]))

# Gráfico 2: Latência P95 (sobrepor no mesmo gráfico)
histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{container="p"}[1m]))) * 1000
```

### Distribuição de Latência (Heatmap)

```promql
# Ver quantas requisições caem em cada bucket de latência
sum by (le) (increase(http_request_duration_seconds_bucket{container="p"}[1m]))
```

### Predição de Escala (Extrapolação)

```promql
# Se throughput continuar crescendo, quantas réplicas serão necessárias?
predict_linear(
  kube_horizontalpodautoscaler_status_current_replicas{namespace="pspd"}[5m], 300
)
# 300 = predizer 5 minutos no futuro (300 segundos)
```

### Eficiência por Réplica

```promql
# Throughput por réplica (req/s por pod)
sum(rate(http_requests_total{container="p"}[1m])) 
/ kube_horizontalpodautoscaler_status_current_replicas{namespace="pspd"}

# CPU por requisição (quanto CPU consome cada req/s)
sum(rate(container_cpu_usage_seconds_total{namespace="pspd",pod=~"p-.*"}[1m])) 
/ sum(rate(http_requests_total{container="p"}[1m]))
```

### Identificar Outliers (Pods Problemáticos)

```promql
# Pods com latência acima da média
sum by (pod) (rate(http_request_duration_seconds_sum{container="p"}[1m])) 
/ sum by (pod) (rate(http_request_duration_seconds_count{container="p"}[1m]))
> on() group_left()
avg(
  sum by (pod) (rate(http_request_duration_seconds_sum{container="p"}[1m])) 
  / sum by (pod) (rate(http_request_duration_seconds_count{container="p"}[1m]))
)

# Pods usando mais CPU que a média
sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="pspd"}[1m]))
> on() group_left()
avg(sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="pspd"}[1m])))
```

### Network - I/O

```promql
# Bytes recebidos por segundo
rate(container_network_receive_bytes_total{namespace="pspd"}[1m]) / 1024 / 1024

# Bytes enviados por segundo
rate(container_network_transmit_bytes_total{namespace="pspd"}[1m]) / 1024 / 1024

# Total de I/O (MB/s)
(rate(container_network_receive_bytes_total{namespace="pspd"}[1m]) 
 + rate(container_network_transmit_bytes_total{namespace="pspd"}[1m])) / 1024 / 1024
```

---

## 📺 Dashboard em Tempo Real

### Painel Completo (Uma Query por Painel)

#### **Painel 1: Overview**
```promql
# Taxa de requisições (req/s)
sum(rate(http_requests_total{container="p"}[1m]))
```

#### **Painel 2: Latência**
```promql
# P50, P95, P99 (criar 3 queries no mesmo painel)
histogram_quantile(0.50, sum by (le) (rate(http_request_duration_seconds_bucket{container="p"}[1m]))) * 1000
histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{container="p"}[1m]))) * 1000
histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{container="p"}[1m]))) * 1000
```

#### **Painel 3: Errors**
```promql
# Taxa de erro (%)
sum(rate(http_requests_total{container="p",status_code=~"[45].."}[1m])) 
/ sum(rate(http_requests_total{container="p"}[1m])) * 100
```

#### **Painel 4: Recursos**
```promql
# CPU (cores)
sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="pspd"}[1m]))

# Memória (MB)
sum by (pod) (container_memory_working_set_bytes{namespace="pspd"}) / 1024 / 1024
```

#### **Painel 5: HPA**
```promql
# Réplicas
kube_horizontalpodautoscaler_status_current_replicas{namespace="pspd"}
```

#### **Painel 6: Top Endpoints**
```promql
# Endpoints mais acessados
topk(5, sum by (route) (rate(http_requests_total{container="p"}[1m])))
```

---

## 🎯 Queries para Relatório

### Resumo de Um Cenário (Copiar Resultados)

```promql
# ====== CENÁRIO: [NOME] ======

# 1. Throughput Médio (req/s)
avg_over_time(sum(rate(http_requests_total{container="p"}[1m]))[5m:30s])

# 2. Throughput Máximo (req/s)
max_over_time(sum(rate(http_requests_total{container="p"}[1m]))[5m:30s])

# 3. Latência P95 Média (ms)
avg_over_time(
  histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{container="p"}[1m])))[5m:30s]
) * 1000

# 4. Latência P95 Máxima (ms)
max_over_time(
  histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{container="p"}[1m])))[5m:30s]
) * 1000

# 5. Taxa de Erro Média (%)
avg_over_time(
  (sum(rate(http_requests_total{container="p",status_code=~"[45].."}[1m])) 
   / sum(rate(http_requests_total{container="p"}[1m])) * 100)[5m:30s]
)

# 6. CPU Médio (cores)
avg_over_time(sum(rate(container_cpu_usage_seconds_total{namespace="pspd"}[1m]))[5m:30s])

# 7. CPU Máximo (cores)
max_over_time(sum(rate(container_cpu_usage_seconds_total{namespace="pspd"}[1m]))[5m:30s])

# 8. Memória Média (MB)
avg_over_time(sum(container_memory_working_set_bytes{namespace="pspd"})[5m:30s]) / 1024 / 1024

# 9. Réplicas Mínimas
min_over_time(kube_horizontalpodautoscaler_status_current_replicas{namespace="pspd"}[5m])

# 10. Réplicas Máximas
max_over_time(kube_horizontalpodautoscaler_status_current_replicas{namespace="pspd"}[5m])
```

### Exportar Dados (via API do Prometheus)

```bash
# Salvar resultado de uma query em JSON
curl -G 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=sum(rate(http_requests_total{container="p"}[1m]))' \
  | jq '.data.result[0].value[1]'

# Range query (série temporal completa)
curl -G 'http://localhost:9090/api/v1/query_range' \
  --data-urlencode 'query=sum(rate(http_requests_total{container="p"}[1m]))' \
  --data-urlencode 'start=2024-12-07T10:00:00Z' \
  --data-urlencode 'end=2024-12-07T10:05:00Z' \
  --data-urlencode 'step=15s' \
  > throughput_cenario1.json
```

---

## 💡 Dicas de Uso

### Intervalo de Tempo (`[Xm]`)

- **`[30s]`**: Para variações rápidas (spikes)
- **`[1m]`**: Padrão para monitoramento em tempo real
- **`[5m]`**: Para tendências médias
- **`[10m]`**: Para análise de período completo

### Funções Úteis

- **`rate()`**: Taxa por segundo (use para contadores)
- **`increase()`**: Total no período (soma)
- **`avg_over_time()`**: Média no intervalo
- **`max_over_time()`**: Valor máximo no intervalo
- **`min_over_time()`**: Valor mínimo no intervalo
- **`delta()`**: Diferença entre primeiro e último valor
- **`predict_linear()`**: Extrapolação linear
- **`histogram_quantile()`**: Percentis (P50, P95, P99)

### Auto-refresh no Prometheus

No Prometheus UI, clique no dropdown **"- off -"** e selecione:
- **10s**: Para testes rápidos (spike)
- **30s**: Para testes longos (soak)
- **1m**: Para monitoramento contínuo

---

## 🚀 Workflow Recomendado

### Antes do Teste
```promql
# Baseline - anotar valores
sum(rate(http_requests_total{container="p"}[1m]))
histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{container="p"}[1m])))
kube_horizontalpodautoscaler_status_current_replicas{namespace="pspd"}
```

### Durante o Teste
```promql
# Monitorar em tempo real (auto-refresh 10s)
sum(rate(http_requests_total{container="p"}[30s]))
histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{container="p"}[30s])))
kube_horizontalpodautoscaler_status_current_replicas{namespace="pspd"}
```

### Depois do Teste
```promql
# Métricas consolidadas (5 minutos de teste)
avg_over_time(sum(rate(http_requests_total{container="p"}[1m]))[5m:30s])
max_over_time(histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{container="p"}[1m])))[5m:30s])
max_over_time(kube_horizontalpodautoscaler_status_current_replicas{namespace="pspd"}[5m])
```


