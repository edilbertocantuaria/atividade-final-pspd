# 📊 Como Visualizar Métricas e Dashboards

Guia passo a passo para acessar Prometheus, Grafana e visualizar as métricas coletadas.

---

## 🎯 Pré-requisitos

Certifique-se de que:
- ✅ Cluster Kubernetes está rodando (`minikube status`)
- ✅ Prometheus está instalado (`kubectl get pods -n monitoring`)
- ✅ Aplicação está deployada (`kubectl get pods -n pspd`)
- ✅ ServiceMonitors estão configurados (`kubectl get servicemonitor -n pspd`)

---

## ⚠️ IMPORTANTE: Geração de Métricas

**As métricas só aparecem quando há tráfego na aplicação!**

- 📊 **Prometheus coleta métricas**, mas se ninguém está fazendo requisições, os valores ficam zerados ou inexistentes
- 🚀 **Para visualizar dados reais**: execute testes de carga ou faça requisições manuais
- ⏱️ **Tempo de atualização**: Prometheus faz scrape a cada 15-30 segundos

**Formas de gerar tráfego**:

1. **Testes de carga automatizados** (recomendado):
   ```bash
   k6 run load/spike.js       # Pico de tráfego (1min)
   k6 run load/baseline.js    # Carga constante (5min)
   k6 run load/soak.js        # Teste longo (10min)
   ```

2. **Requisições manuais**:
   ```bash
   # Abrir acesso ao Gateway
   kubectl port-forward -n pspd svc/p-svc 8080:80
   
   # Fazer requisições
   curl "http://localhost:8080/api/content?type=all"
   curl "http://localhost:8080/api/metadata/m1"
   curl "http://localhost:8080/api/browse?type=movies"
   ```

3. **Loop simples** (para testes):
   ```bash
   kubectl port-forward -n pspd svc/p-svc 8080:80 &
   while true; do curl -s "http://localhost:8080/api/content?type=all" > /dev/null; sleep 1; done
   ```

**Após gerar tráfego, aguarde 15-30 segundos** para as métricas aparecerem no Prometheus/Grafana.

---

## 📈 Opção 1: Prometheus (Visualização de Métricas Brutas)

### Passo 1: Iniciar Port-Forward do Prometheus

Abra um terminal e execute:

```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

**Deixe este terminal aberto!** O comando ficará rodando.

### Passo 2: Acessar Interface Web

Abra seu navegador e acesse:
```
http://localhost:9090
```

### Passo 3: Verificar Targets (Serviços Monitorados)

1. No Prometheus, clique em **Status** → **Targets**
2. Procure pela seção **`serviceMonitor/pspd/...`**
3. Você deve ver **3 targets UP** (verde):
   - `serviceMonitor/pspd/service-a-monitor/0` → `10.x.x.x:9101`
   - `serviceMonitor/pspd/service-b-monitor/0` → `10.x.x.x:9102`
   - `serviceMonitor/pspd/gateway-p-monitor/0` → `10.x.x.x:8080`

#### ⚠️ Se NÃO aparecer nenhum target com `serviceMonitor/pspd`

**Causa**: ServiceMonitors não foram criados ou Prometheus não os descobriu ainda.

**Solução**:
```bash
# 1. Verificar se ServiceMonitors existem
kubectl get servicemonitor -n pspd

# Se retornar "No resources found":
# 2. Criar os ServiceMonitors
kubectl apply -f k8s/servicemonitors.yaml

# 3. Aguardar 15-30 segundos e recarregar página do Prometheus
# 4. Verificar se apareceram em Status → Targets
```

#### 🔴 Se targets aparecem mas estão DOWN (vermelho)

**Causa**: Pods não estão rodando ou não estão expondo métricas corretamente.

**Solução**:
```bash
# 1. Verificar se pods estão Running
kubectl get pods -n pspd

# Se algum pod NÃO está Running:
# 2. Ver logs do pod com problema
kubectl logs -n pspd -l app=a  # para Service A
kubectl logs -n pspd -l app=b  # para Service B
kubectl logs -n pspd -l app=p  # para Gateway P

# 3. Reconstruir imagens e reiniciar pods
eval $(minikube -p minikube docker-env)
docker build -t a-service:local ./services/a_py
docker build -t b-service:local ./services/b_py
docker build -t p-gateway:local ./gateway_p_node

kubectl delete pod --all -n pspd
kubectl wait --for=condition=ready pod --all -n pspd --timeout=60s

# 4. Aguardar 15-30 segundos e verificar targets novamente
```

#### ✅ Verificar se métricas estão sendo expostas

```bash
# Testar endpoint de métricas diretamente
kubectl exec -n pspd deploy/a-deploy -- python3 -c "import urllib.request; print(urllib.request.urlopen('http://localhost:9101/metrics').read().decode()[:500])"

# Se retornar erro, o servidor de métricas não está rodando
# Verifique os logs do pod para identificar o problema
```

### Passo 4: Explorar Métricas

**⚠️ LEMBRE-SE**: As queries abaixo só retornarão dados se houver tráfego na aplicação!  
**Execute um teste de carga primeiro** (veja seção "Gerar Métricas com Testes de Carga" abaixo).

No **Graph** (aba superior), teste estas queries:

#### Requisições HTTP por segundo (Gateway P)
```promql
rate(http_requests_total{app="p"}[1m])
```

#### Latência P95 do Gateway
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{app="p"}[1m]))
```

#### Requisições gRPC do Service A
```promql
rate(grpc_server_requests_total{app="a"}[1m])
```

#### Itens streamed pelo Service B
```promql
rate(grpc_server_stream_items_total{app="b"}[1m])
```

#### CPU dos Pods
```promql
rate(container_cpu_usage_seconds_total{namespace="pspd"}[1m])
```

#### Réplicas HPA
```promql
kube_horizontalpodautoscaler_status_current_replicas{namespace="pspd"}
```

**Dica**: Clique em **Execute** e depois em **Graph** para ver o gráfico!

---

## 🎨 Opção 2: Grafana (Dashboards Visuais)

### Passo 1: Iniciar Port-Forward do Grafana

Abra um **novo terminal** e execute:

```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

**Deixe este terminal aberto!**

### Passo 2: Recuperar Senha do Grafana

Em outro terminal, execute:

```bash
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d && echo
```

Copie a senha que aparecer (algo como: `RnoVJN3Y4KyzMfmgwExIzqiIXq90jEtgrqLNmBjb`)

### Passo 3: Fazer Login no Grafana

1. Abra seu navegador: http://localhost:3000
2. **Usuário**: `admin`
3. **Senha**: Cole a senha copiada no passo anterior
4. Clique em **Log in**

### Passo 4: Explorar Dashboards Pré-instalados

No menu lateral, clique em **☰** → **Dashboards**

Dashboards úteis para o projeto:

#### 1. **Kubernetes / Compute Resources / Namespace (Pods)**
- Mostra CPU e Memória de todos os pods do namespace `pspd`
- Para ver suas métricas: filtro superior → namespace: `pspd`

#### 2. **Kubernetes / Compute Resources / Pod**
- Métricas detalhadas de um pod específico
- Escolha pod: `a-deploy-xxx`, `b-deploy-xxx` ou `p-deploy-xxx`

#### 3. **Node Exporter / Nodes**
- Métricas dos nós do cluster
- CPU, memória, disco, rede

### Passo 5: Importar Dashboard Customizado da Aplicação

1. No Grafana, clique em **☰** → **Dashboards** → **Import**
2. Clique em **Upload JSON file**
3. Selecione: `/home/edilberto/pspd/atividade-final-pspd/k8s/monitoring/grafana-dashboard.json`
4. Em **Prometheus**, selecione: **Prometheus** (deve ser a única opção)
5. Clique em **Import**

**Dashboard inclui**:
- Taxa de requisições HTTP
- Latência (P50, P95, P99)
- Taxa de erros
- Número de réplicas (HPA)
- CPU/Memória por pod
- Throughput gRPC

### Passo 6: Criar Painel Customizado

1. Clique em **☰** → **Dashboards** → **New** → **New Dashboard**
2. Clique em **Add visualization**
3. Selecione **Prometheus** como data source
4. Cole uma query PromQL (exemplos acima)
5. Configure:
   - **Title**: Nome descritivo
   - **Legend**: `{{pod}}` ou `{{app}}`
   - **Unit**: Escolha apropriada (req/s, ms, bytes, etc.)
6. Clique em **Apply**
7. **Save dashboard** (ícone de disquete no topo)

---

## 🧪 Gerar Métricas com Testes de Carga

Para ver as métricas em ação, execute testes de carga:

### Terminal 1: Monitoramento em tempo real
```bash
./scripts/run_all_tests.sh monitor
```

### Terminal 2: Port-forward da aplicação
```bash
kubectl port-forward -n pspd svc/p-svc 8080:80
```

### Terminal 3: Executar teste
```bash
BASE_URL=http://localhost:8080 ./scripts/run_all_tests.sh spike
```

Agora volte para **Grafana** ou **Prometheus** e veja as métricas subindo em tempo real! 📈

---

## 🔍 Verificar se Métricas Estão Sendo Coletadas

### Método 1: Via Port-Forward Direto nos Pods

```bash
# Service A (porta 9101)
kubectl port-forward -n pspd svc/a-svc 9101:9101
curl http://localhost:9101/metrics | grep grpc_server

# Service B (porta 9102)
kubectl port-forward -n pspd svc/b-svc 9102:9102
curl http://localhost:9102/metrics | grep grpc_server

# Gateway P (porta 8080)
kubectl port-forward -n pspd svc/p-svc 8080:80
curl http://localhost:8080/metrics | grep http_requests
```

Deve aparecer algo como:
```
grpc_server_requests_total{method="GetContent",status="success"} 42.0
http_requests_total{method="GET",route="/api/content",status_code="200"} 156.0
```

### Método 2: Via Prometheus Targets

1. Acesse Prometheus: http://localhost:9090/targets
2. Procure por `serviceMonitor/pspd`
3. Verifique:
   - **State**: UP (verde) ✅
   - **Last Scrape**: Recente (<1min)
   - **Scrape Duration**: Baixo (<100ms)

### Método 3: Query no Prometheus

No Prometheus, execute:
```promql
up{namespace="pspd"}
```

Resultado esperado:
```
up{job="serviceMonitor/pspd/gateway-p-monitor/0", namespace="pspd"} = 1
up{job="serviceMonitor/pspd/service-a-monitor/0", namespace="pspd"} = 1
up{job="serviceMonitor/pspd/service-b-monitor/0", namespace="pspd"} = 1
```

**1 = UP ✅ | 0 = DOWN ❌**

---

## 📊 Queries PromQL Úteis

### Métricas da Aplicação

#### Taxa de Requisições HTTP
```promql
sum(rate(http_requests_total{namespace="pspd"}[1m])) by (app, route)
```

#### Latência P95 por Endpoint
```promql
histogram_quantile(0.95, 
  sum(rate(http_request_duration_seconds_bucket{namespace="pspd"}[5m])) 
  by (le, route)
)
```

#### Taxa de Erro (HTTP 5xx)
```promql
sum(rate(http_requests_total{namespace="pspd",status_code=~"5.."}[1m])) 
/ 
sum(rate(http_requests_total{namespace="pspd"}[1m])) * 100
```

#### gRPC Request Rate (Service A)
```promql
rate(grpc_server_requests_total{app="a",status="success"}[1m])
```

#### Streaming Items/s (Service B)
```promql
rate(grpc_server_stream_items_total{app="b"}[1m])
```

### Métricas de Infraestrutura

#### CPU por Pod
```promql
sum(rate(container_cpu_usage_seconds_total{namespace="pspd"}[1m])) by (pod)
```

#### Memória por Pod
```promql
sum(container_memory_working_set_bytes{namespace="pspd"}) by (pod) / 1024 / 1024
```

#### Réplicas Atual vs Desejado (HPA)
```promql
kube_horizontalpodautoscaler_status_current_replicas{namespace="pspd"}
kube_horizontalpodautoscaler_spec_max_replicas{namespace="pspd"}
```

#### Network In/Out
```promql
rate(container_network_receive_bytes_total{namespace="pspd"}[1m])
rate(container_network_transmit_bytes_total{namespace="pspd"}[1m])
```

---

## 🐛 Troubleshooting

### Problema: "No data points" no Grafana

**Causa**: Métricas ainda não foram geradas (aplicação não recebeu tráfego)

**Solução - Opção 1: Executar teste de carga** (recomendado):
```bash
# Teste rápido de 1 minuto
k6 run load/spike.js

# OU teste baseline de 5 minutos
k6 run load/baseline.js
```

**Solução - Opção 2: Gerar tráfego manual**:
```bash
# Terminal 1: Abrir acesso
kubectl port-forward -n pspd svc/p-svc 8080:80

# Terminal 2: Fazer várias requisições
for i in {1..50}; do
  curl -s "http://localhost:8080/api/content?type=all" > /dev/null
  curl -s "http://localhost:8080/api/metadata/m$i" > /dev/null
  curl -s "http://localhost:8080/api/browse?type=movies" > /dev/null
done

# Aguardar 15-30 segundos para Prometheus fazer scrape
```

### Problema: Targets DOWN no Prometheus

**Verificar pods**:
```bash
kubectl get pods -n pspd
```

**Se pods não estão Running**:
```bash
# Ver logs
kubectl logs -n pspd -l app=a

# Reiniciar
kubectl delete pod --all -n pspd
kubectl wait --for=condition=ready pod --all -n pspd --timeout=60s
```

**Verificar ServiceMonitors**:
```bash
kubectl get servicemonitor -n pspd
kubectl describe servicemonitor service-a-monitor -n pspd
```

### Problema: Senha do Grafana não funciona

**Resetar senha**:
```bash
# Deletar pod do Grafana para recriar
kubectl delete pod -n monitoring -l app.kubernetes.io/name=grafana

# Aguardar pod ficar pronto
kubectl wait --for=condition=ready pod -n monitoring -l app.kubernetes.io/name=grafana --timeout=60s

# Recuperar nova senha
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d
```

### Problema: Port-forward para ou cai

**Usar script estável** (mantém rodando):
```bash
./scripts/stable_port_forward.sh
```

Ou **manualmente** com loop:
```bash
while true; do
  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
  echo "Port-forward caiu, reconectando em 5s..."
  sleep 5
done
```

---

## 📚 Próximos Passos

1. ✅ Acesse Prometheus: http://localhost:9090
2. ✅ Verifique targets estão UP: Status → Targets
3. ✅ Acesse Grafana: http://localhost:3000 (admin + senha do secret)
4. ✅ Importe dashboard: `k8s/monitoring/grafana-dashboard.json`
5. ✅ Execute teste de carga: `./scripts/run_all_tests.sh spike`
6. ✅ Observe métricas em tempo real no Grafana
7. ✅ Explore queries PromQL no Prometheus

---

## 🎯 Checklist de Validação

- [ ] Prometheus acessível em http://localhost:9090
- [ ] 3 targets UP no Prometheus (a, b, p)
- [ ] Grafana acessível em http://localhost:3000
- [ ] Dashboard customizado importado
- [ ] Métricas aparecem após gerar tráfego
- [ ] HPA scaling visível nos dashboards
- [ ] Latência P95 < 200ms em baseline test

**Se todos os itens estiverem ✅, seu monitoramento está 100% funcional!** 🎉
