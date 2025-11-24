# 📊 Guia de Acesso ao Grafana

## 🚀 Acesso Rápido

### 1. Iniciar Port-Forward

```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

Deixe este comando rodando em um terminal separado.

### 2. Acessar o Grafana

- **URL**: http://localhost:3000
- **Usuário**: `admin`
- **Senha**: `admin`

> **Nota**: Na primeira vez que acessar, o Grafana pode pedir para trocar a senha. Você pode pular ou definir uma nova senha.

---

## 📈 Navegando nos Dashboards

### Dashboards Pré-instalados

Após o login, clique no menu **☰** → **Dashboards** para ver os dashboards disponíveis:

1. **Kubernetes / Compute Resources / Namespace (Pods)**
   - Visualização de recursos por namespace
   - CPU e memória de todos os pods

2. **Kubernetes / Compute Resources / Pod**
   - Métricas detalhadas de um pod específico
   - Útil para debug de performance

3. **Node Exporter / Nodes**
   - Métricas dos nós do cluster
   - CPU, memória, disco, rede

4. **Prometheus / Overview**
   - Visão geral do Prometheus
   - Status de targets e alertas

---

## 🔧 Criar Dashboard Customizado

### Para os Serviços da Aplicação

1. Clique em **"+"** → **Create Dashboard** → **Add visualization**

2. Selecione **prometheus** como data source

3. Use queries PromQL para seus serviços:

#### Queries Úteis

**Taxa de Requisições HTTP**:
```promql
rate(http_requests_total{namespace="default"}[5m])
```

**Latência P95**:
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{namespace="default"}[5m]))
```

**Uso de CPU por Pod**:
```promql
rate(container_cpu_usage_seconds_total{namespace="default", pod=~"service-.*"}[5m])
```

**Uso de Memória por Pod**:
```promql
container_memory_working_set_bytes{namespace="default", pod=~"service-.*"}
```

**Taxa de Erros HTTP**:
```promql
rate(http_requests_total{namespace="default", status=~"5.."}[5m])
```

**Número de Réplicas HPA**:
```promql
kube_horizontalpodautoscaler_status_current_replicas{namespace="default"}
```

**Throughput Total**:
```promql
sum(rate(http_requests_total{namespace="default"}[5m]))
```

### Configurar Painel

4. Configure o painel:
   - **Title**: Nome descritivo (ex: "Taxa de Requisições - Service A")
   - **Legend**: `{{pod}}` ou `{{service}}` para diferenciar
   - **Unit**: Selecione a unidade apropriada (req/s, bytes, ms, etc.)

5. Clique em **Apply** para salvar o painel

6. Adicione mais painéis repetindo os passos acima

7. Salve o dashboard: **💾** (ícone de salvar) no topo → Nome do dashboard

---

## 🎯 Dashboard Recomendado para os Testes

### Layout Sugerido

Crie um dashboard com 6 painéis:

| Painel | Query | Tipo |
|--------|-------|------|
| **Requisições/seg** | `sum(rate(http_requests_total[5m]))` | Graph |
| **Latência P95** | `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))` | Graph |
| **CPU por Serviço** | `rate(container_cpu_usage_seconds_total{pod=~"(gateway\|service-a\|service-b)-.*"}[5m])` | Graph |
| **Memória por Serviço** | `container_memory_working_set_bytes{pod=~"(gateway\|service-a\|service-b)-.*"}` | Graph |
| **Réplicas HPA** | `kube_horizontalpodautoscaler_status_current_replicas` | Graph |
| **Taxa de Erro** | `rate(http_requests_total{status=~"5.."}[5m])` | Graph |

---

## 🔍 Filtrar por Teste

Para visualizar métricas durante um teste específico:

1. Use o **Time Range Picker** (canto superior direito)
2. Selecione o período do teste (ex: Last 15 minutes)
3. Ou defina manualmente: **From/To** com data/hora exata

---

## 🛠️ Troubleshooting

### Port-Forward Parou

Se o port-forward parar, reinicie o comando:

```bash
# Matar processos na porta 3000 (se necessário)
lsof -ti:3000 | xargs kill -9 2>/dev/null

# Reiniciar port-forward
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

### Não Vejo Métricas dos Meus Serviços

Verifique se os ServiceMonitors estão criados:

```bash
kubectl get servicemonitor -n default
```

Deve listar:
- `gateway-p-monitor`
- `service-a-monitor`
- `service-b-monitor`

### Verificar se Prometheus Está Coletando

1. Acesse Prometheus: http://localhost:9090
   ```bash
   kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
   ```

2. Vá em **Status** → **Targets**

3. Procure por seus serviços em `default/service-*`

### Dashboards Não Aparecem

Se os dashboards pré-instalados não aparecerem:

1. Verifique os ConfigMaps:
   ```bash
   kubectl get configmap -n monitoring | grep grafana
   ```

2. Reinicie o pod do Grafana:
   ```bash
   kubectl delete pod -n monitoring -l app.kubernetes.io/name=grafana
   ```

---

## 📚 Recursos Adicionais

### Documentação PromQL

- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [PromQL Functions](https://prometheus.io/docs/prometheus/latest/querying/functions/)

### Exemplos de Dashboards

- [Grafana Dashboard Gallery](https://grafana.com/grafana/dashboards/)
- Filtrar por: **Prometheus** + **Kubernetes**

### Exportar/Importar Dashboard

**Exportar**:
1. Abra o dashboard
2. Clique em **⚙️** (Settings) → **JSON Model**
3. Copie o JSON

**Importar**:
1. **☰** → **Dashboards** → **Import**
2. Cole o JSON ou use um ID da galeria
3. Selecione **prometheus** como data source

---

## 🎨 Dicas de Visualização

### Cores por Criticidade

- **Verde**: Métricas normais (CPU < 70%, latência boa)
- **Amarelo**: Atenção (CPU 70-90%, latência moderada)
- **Vermelho**: Crítico (CPU > 90%, alta latência, erros)

### Alertas Visuais

Configure thresholds nos painéis:
1. Edit panel → **Thresholds**
2. Defina valores críticos
3. Escolha cores (verde → amarelo → vermelho)

### Templates

Use variáveis para filtros dinâmicos:
1. Dashboard settings → **Variables** → **New variable**
2. Exemplo: `$namespace`, `$pod`, `$service`
3. Use na query: `{namespace="$namespace", pod=~"$pod"}`

---

## 💡 Exemplo Completo: Painel de Latência

```promql
# Query
histogram_quantile(0.95, 
  rate(http_request_duration_seconds_bucket{
    namespace="default",
    service=~"service-a|service-b|gateway-p"
  }[5m])
)

# Legend: {{service}} - P95

# Thresholds:
# - Verde: < 500ms
# - Amarelo: 500-1000ms
# - Vermelho: > 1000ms

# Unit: milliseconds (ms)
# Decimals: 2
```

Salve e o painel mostrará a latência P95 de cada serviço com cores indicando a saúde.
