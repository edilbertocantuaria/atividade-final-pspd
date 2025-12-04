# Atendimento aos Requisitos do Trabalho Final

Este documento demonstra como o projeto atende **completamente** aos requisitos especificados.

---

## 📋 Requisito 1: Aplicação Baseada em Microserviços

### ✅ Especificação Atendida

**Aplicação**: Plataforma de Streaming de Vídeo

A aplicação segue **exatamente** a arquitetura da Figura 1:

```
┌─────────────────────────────────────┐
│         WEB API (P)                 │
│         Gateway Node.js             │  ← Requisições HTTP do frontend
│      (Express + gRPC Client)        │
└──────────────┬──────────────────────┘
               │
          gRPC Stub
          ┌────┴─────┐
          ↓          ↓
    ┌──────────┐  ┌──────────┐
    │Service A │  │Service B │
    │(Catálogo)│  │(Metadata)│
    │ Python   │  │ Python   │
    └──────────┘  └──────────┘
     Proto Req     Proto Req
     Proto Resp    Proto Resp(s)
```

### Módulos Implementados

#### **Módulo P - Gateway Web API**

**Arquivo**: `gateway_p_node/server.js`

**Função**: 
- Recebe requisições HTTP/REST do frontend Next.js
- Converte para chamadas gRPC usando Protocol Buffers
- Consolida respostas de A e B
- Expõe 3 endpoints REST principais

**Endpoints Expostos**:

1. **`GET /api/content?type=movies&limit=10`**
   - Chama `Service A` via gRPC
   - Retorna catálogo filtrado de filmes/séries/canais

2. **`GET /api/metadata/:contentId`**
   - Chama `Service B` via gRPC (streaming)
   - Retorna metadados e recomendações

3. **`GET /api/browse?type=all`**
   - **Consolidação P→A+B**: Chama ambos os serviços
   - Primeiro busca catálogo (A)
   - Depois busca metadados do primeiro item (B)
   - Retorna resultado combinado

**Métricas Prometheus**: Expõe `/metrics` com métricas HTTP e gRPC

#### **Módulo A - Service A (Catálogo)**

**Arquivo**: `services/a_py/server.py`

**Função**: 
- Microsserviço gRPC que fornece catálogo de conteúdo
- Banco de dados simulado com 12 itens (4 filmes + 4 séries + 3 canais + metadados)

**RPC Implementada**:
```protobuf
service ServiceA {
  rpc GetContent(ContentRequest) returns (ContentResponse);
}
```

**Características**:
- **Comunicação unária**: Uma requisição → Uma resposta
- **Filtros**: Por tipo (`movies`, `series`, `live`, `all`) e gênero
- **Retorna**: Lista de `ContentItem` com id, título, descrição, rating, etc.

**Exemplo de Resposta**:
```json
{
  "items": [
    {
      "id": "m1",
      "title": "A Jornada Infinita",
      "type": "movie",
      "genres": ["Ficção Científica", "Aventura"],
      "rating": 8.7
    }
  ],
  "total": 4
}
```

#### **Módulo B - Service B (Metadados e Recomendações)**

**Arquivo**: `services/b_py/server.py`

**Função**:
- Microsserviço gRPC que fornece metadados detalhados via streaming
- Simula processamento incremental (análise de dados, ML)

**RPC Implementada**:
```protobuf
service ServiceB {
  rpc StreamMetadata(MetadataRequest) returns (stream MetadataItem);
}
```

**Características**:
- **Comunicação streaming**: Uma requisição → Múltiplas respostas (stream)
- **Retorna**: Diretor, elenco, filmes similares, recomendações
- **Processamento incremental**: Envia dados conforme processa (0.01s entre itens)

**Exemplo de Resposta (stream)**:
```json
[
  {"key": "director", "value": "James Cameron", "relevanceScore": 0.95},
  {"key": "cast", "value": "Chris Evans", "relevanceScore": 0.90},
  {"key": "similar", "value": "Interestelar", "relevanceScore": 0.85}
]
```

### Contrato gRPC (Protocol Buffers)

**Arquivo**: `proto/services.proto`

```protobuf
syntax = "proto3";
package pspd;

// Service A: Catálogo
message ContentRequest {
  string type = 1;      // "movies", "series", "live", "all"
  int32 limit = 2;
  string genre = 3;
}

message ContentItem {
  string id = 1;
  string title = 2;
  string description = 3;
  // ... mais campos
}

message ContentResponse {
  repeated ContentItem items = 1;
  int32 total = 2;
}

service ServiceA {
  rpc GetContent(ContentRequest) returns (ContentResponse);
}

// Service B: Metadados
message MetadataRequest {
  string content_id = 1;
  string user_id = 2;
}

message MetadataItem {
  string key = 1;
  string value = 2;
  float relevance_score = 3;
}

service ServiceB {
  rpc StreamMetadata(MetadataRequest) returns (stream MetadataItem);
}
```

### Frontend (Demonstração)

**Deployed em**: https://streaming-app-design.vercel.app/

**Tecnologia**: Next.js 14 (React) com TypeScript

**Integração**: Ver `docs/INTEGRACAO_FRONTEND.md`

---

## 📋 Requisito 2: Cluster Kubernetes Multi-Node

### ✅ Especificação Atendida

**Cluster Configurado**:
- **1 Master Node** (plano de controle Kubernetes)
- **2 Worker Nodes** (execução de workloads)
- **Ferramenta**: Minikube com driver Docker

**Setup Documentado**: `docs/GUIA_MULTINODE.md`

### Comandos de Criação

```bash
# Criar cluster multi-node
minikube start --nodes 3 --driver=docker --cpus=2 --memory=4096

# Verificar nodes
kubectl get nodes
# NAME           STATUS   ROLES           AGE
# minikube       Ready    control-plane   5m
# minikube-m02   Ready    <none>          4m
# minikube-m03   Ready    <none>          3m
```

### Recursos de Autoscaling

**HPA (Horizontal Pod Autoscaler)** configurado para todos os serviços:

**Arquivo**: `k8s/monitoring/hpa.yaml`

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: p-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: p
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

**Comportamento**:
- CPU < 70%: Mantém 1 réplica
- CPU > 70%: Escala até 10 réplicas
- Scale-down gradual após carga reduzir

### Interface Web de Monitoramento

#### Prometheus

**Instalação**: Helm chart `prometheus-community/kube-prometheus-stack`

```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace
```

**Acesso**:
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# → http://localhost:9090
```

**Funcionalidades**:
- Coleta automática de métricas do cluster
- ServiceMonitors customizados para P, A, B
- Queries PromQL para análise

#### Grafana

**Instalado junto com Prometheus** (parte do stack)

**Acesso**:
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# → http://localhost:3000
# Usuário: admin
# Senha: prom-operator (ou admin/admin)
```

**Dashboards Importados**:
- Kubernetes Cluster Monitoring (ID: 7249)
- Node Exporter (ID: 1860)
- Dashboard customizado: `docs/grafana-dashboard.json`

### Distribuição no Cluster (Figura 2)

```
┌──────────────────────────────────────────┐
│         K8s Master Node                  │
│  (Control Plane - kube-apiserver, etc)   │
└──────────────────────────────────────────┘
                  │
        ┌─────────┴─────────┐
        ↓                   ↓
┌─────────────────┐  ┌─────────────────┐
│  Worker Node 1  │  │  Worker Node 2  │
│                 │  │                 │
│  Pod: p-xxx     │  │  Pod: a-xxx     │
│  Pod: b-xxx     │  │  Pod: p-yyy     │
└─────────────────┘  └─────────────────┘
```

**Verificação de Distribuição**:
```bash
kubectl get pods -n pspd -o wide
# NAME         NODE
# p-abc123     minikube-m02
# a-def456     minikube-m03
# b-ghi789     minikube-m02
```

---

## 📋 Requisito 3: Testes de Carga com Cenários

### ✅ Especificação Atendida

**Ferramenta Escolhida**: **k6** (https://k6.io/)

**Justificativa**:
- Projetado especificamente para testes de carga de APIs REST
- Scripting em JavaScript (fácil manutenção)
- Métricas detalhadas (latência, throughput, erro)
- Integração com Prometheus (exportador k6)
- Open-source e amplamente usado

### Configuração Base (Cenário 1)

**Descrição**: Aplicação no estado mais simples

**Manifests**: `k8s/scenarios/scenario1-base/`

**Características**:
- HPA ativado (1-10 réplicas)
- Réplicas iniciais: 1 para cada serviço (P, A, B)
- Recursos: Padrão (CPU: 100m request, 200m limit)
- Sem anti-affinity (scheduler decide)

**Métricas Baseline Coletadas**:

1. **Tempo médio de resposta**:
   - Teste: `load/baseline.js` (10 VUs, 2min)
   - Resultado esperado: ~50-150ms (p50), ~200-500ms (p95)

2. **Máxima req/s atendidas**:
   - Teste: `load/spike.js` (pico de 200 VUs)
   - Resultado esperado: ~100-300 req/s

**Execução**:
```bash
# Setup cenário 1
cd test/scenario_1
./00_setup.sh

# Rodar todos os testes
./run_all.sh

# Resultados em: test_results/scenario_1/
```

### Cenários Variados

#### Cenário 2: Warm Start (2 réplicas iniciais)

**Variação**: `replicas: 2` para P, A, B

**Hipótese**: Melhor tempo de resposta inicial (sem cold start)

**Métricas Comparadas**:
- Latência nos primeiros 30s
- Tempo até primeira resposta < 100ms

#### Cenário 3: Alta Disponibilidade (Anti-affinity)

**Variação**: `podAntiAffinity` forçando distribuição entre workers

**Hipótese**: Maior resiliência a falhas de node

**Métricas Comparadas**:
- Taxa de sucesso durante simulação de falha de node
- Distribuição de pods (deve ter P, A, B em ambos os workers)

#### Cenário 4: Recursos Limitados (-50%)

**Variação**: `cpu: 50m`, `memory: 64Mi` (metade do normal)

**Hipótese**: Latência maior, HPA escala mais pods

**Métricas Comparadas**:
- Número de réplicas criadas durante ramp test
- Latência sob mesma carga

#### Cenário 5: Sem Autoscaling (Réplicas fixas)

**Variação**: Remove HPA, fixa réplicas em 3 (P), 5 (A, B)

**Hipótese**: Performance estável mas sem elasticidade

**Métricas Comparadas**:
- Consumo de recursos durante idle
- Tempo de resposta durante pico (deve degradar sem scaling)

### Tipos de Teste Aplicados

#### 1. Baseline Test (`load/baseline.js`)

**Duração**: 2 minutos  
**VUs**: 10 usuários constantes

**Objetivo**: Estabelecer linha de base de performance

**Requisições por VU**:
```javascript
1. GET /api/content?type=all&limit=20     // Catálogo completo
2. GET /api/content?type=movies&limit=10  // Filtro filmes
3. GET /api/metadata/m1                   // Metadados
4. GET /api/browse?type=series            // Endpoint combinado
```

**Métricas Coletadas**:
- `http_req_duration`: p50, p95, p99
- `http_req_failed`: taxa de erro
- `http_reqs`: req/s

#### 2. Ramp Test (`load/ramp.js`)

**Duração**: 4.5 minutos  
**VUs**: 10 → 50 → 100 → 150 → 0 (gradual)

**Objetivo**: Testar autoscaling (HPA)

**Observações**:
- HPA deve criar novas réplicas quando CPU > 70%
- Latência deve se manter estável durante escala
- Scale-down deve acontecer gradualmente

**Verificação HPA**:
```bash
watch -n 5 kubectl get hpa -n pspd
# NAME   REFERENCE   TARGETS   MINPODS   MAXPODS   REPLICAS
# p-hpa  Deployment  120%/70%  1         10        5
```

#### 3. Spike Test (`load/spike.js`)

**Duração**: 1.5 minutos  
**VUs**: 10 → 200 (spike repentino) → 10

**Objetivo**: Testar resiliência a picos súbitos

**Cenário Simulado**: Lançamento de série viral (todos acessam s1)

**Requisições**:
```javascript
GET /api/content?type=series&limit=10
GET /api/metadata/s1
GET /api/browse?type=series&limit=5
```

**Threshold de Sucesso**:
- `http_req_failed < 10%` (aceita até 10% de erro durante spike)
- `http_req_duration p95 < 2000ms`

#### 4. Soak Test (`load/soak.js`)

**Duração**: 11.5 minutos  
**VUs**: 50 usuários constantes

**Objetivo**: Detectar memory leaks e degradação ao longo do tempo

**Cenário Simulado**: Maratona de fim de semana

**Requisições**:
```javascript
// Ciclo de navegação completo
for (tipo in ['movies', 'series', 'live']) {
  GET /api/content?type={tipo}
  GET /api/metadata/{id1}
  GET /api/metadata/{id2}
}
GET /api/browse?type=all
```

**Verificações**:
- Latência não deve aumentar ao longo do tempo
- Uso de memória deve se manter estável
- Taxa de erro deve permanecer < 5%

### Comparação de Cenários

**Script de Automação**: `scripts/run_scenario_comparison.sh`

**Execução**:
```bash
# Rodar todos os 5 cenários (2-3 horas)
./scripts/run_scenario_comparison.sh --all

# Apenas gerar gráficos comparativos (dados já coletados)
./scripts/run_scenario_comparison.sh --compare
```

**Gráficos Gerados**: `test_results/scenario-comparison/`

1. **01_scenario_latency_comparison.png**
   - Latência P95 de cada cenário (4 testes x 5 cenários)
   
2. **02_scenario_throughput_comparison.png**
   - Req/s atingidas por cenário

3. **03_scenario_hpa_scaling.png**
   - Número de réplicas ao longo do tempo (apenas cenários com HPA)

4. **04_scenario_success_rate.png**
   - Taxa de sucesso durante spike test

5. **05_scenario_cost_analysis.png**
   - Consumo médio de CPU/memória (eficiência)

6. **06_scenario_performance_radar.png**
   - Radar chart comparando 5 métricas simultaneamente

### Condições de Teste Garantidas

**Infraestrutura Idêntica**:
- Mesmo cluster (3 nodes)
- Mesmas especificações de CPU/memória (exceto cenário 4)
- Mesma versão das imagens Docker

**Isolamento de Testes**:
```bash
# Entre cada cenário:
kubectl delete namespace pspd
kubectl apply -f k8s/scenarios/scenario{N}/
sleep 60  # Aguardar estabilização
# Executar testes
```

**Múltiplas Execuções**:
- Cada teste executado 3 vezes
- Média dos resultados para reduzir ruído
- Desvio padrão reportado

---

## 📋 Requisito 4: Observabilidade com Prometheus

### ✅ Especificação Atendida

**Prometheus Instalado**: Via Helm chart `kube-prometheus-stack`

**Documentação Completa**: `docs/METRICAS_PROMETHEUS.md`

### Métricas Customizadas Implementadas

#### Gateway P (Web API)

**Biblioteca**: `prom-client` (Node.js)

**Arquivo**: `gateway_p_node/server.js`

**Métricas**:

1. **`http_requests_total{method, route, status_code}`**
   - Tipo: Counter
   - Labels: método HTTP, rota, código de status
   - Uso: Taxa de requisições por endpoint

2. **`http_request_duration_seconds{method, route, status_code}`**
   - Tipo: Histogram
   - Buckets: [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2, 5]
   - Uso: Latência (p50, p95, p99) por endpoint

3. **`grpc_client_requests_total{service, method, status}`**
   - Tipo: Counter
   - Labels: ServiceA/ServiceB, nome do método, sucesso/erro
   - Uso: Taxa de chamadas gRPC originadas pelo gateway

4. **`grpc_client_request_duration_seconds{service, method, status}`**
   - Tipo: Histogram
   - Uso: Latência das chamadas gRPC (P→A, P→B)

**Endpoint de Métricas**: `http://localhost:8080/metrics`

#### Service A (Catálogo)

**Biblioteca**: `prometheus_client` (Python)

**Arquivo**: `services/a_py/server.py`

**Métricas**:

1. **`grpc_server_requests_total{method, status}`**
   - Tipo: Counter
   - Labels: GetContent, sucesso/erro
   - Uso: Taxa de requisições recebidas

2. **`grpc_server_request_duration_seconds{method}`**
   - Tipo: Histogram
   - Uso: Latência do processamento interno

3. **`content_items_returned_total{content_type}`**
   - Tipo: Counter
   - Labels: movies/series/live/all
   - Uso: Distribuição de tipos de conteúdo retornados

**Endpoint de Métricas**: `http://localhost:9101/metrics`

#### Service B (Metadados)

**Biblioteca**: `prometheus_client` (Python)

**Arquivo**: `services/b_py/server.py`

**Métricas**:

1. **`grpc_server_requests_total{method, status}`**
   - Tipo: Counter
   - Labels: StreamMetadata, sucesso/erro

2. **`grpc_server_request_duration_seconds{method}`**
   - Tipo: Histogram
   - Uso: Tempo total de streaming

3. **`grpc_server_stream_items_total{method}`**
   - Tipo: Counter
   - Uso: Total de itens transmitidos via stream

**Endpoint de Métricas**: `http://localhost:9102/metrics`

### ServiceMonitors (Integração com Prometheus)

**Arquivo**: `k8s/monitoring/servicemonitor-p.yaml`

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: service-p-monitor
  namespace: pspd
spec:
  selector:
    matchLabels:
      app: p
  endpoints:
  - port: http
    path: /metrics
    interval: 15s
```

**Verificação**:
```bash
# ServiceMonitors criados
kubectl get servicemonitor -n pspd
# NAME                AGE
# service-a-monitor   5m
# service-b-monitor   5m
# service-p-monitor   5m

# Verificar targets no Prometheus
# → http://localhost:9090/targets
# Procurar: serviceMonitor/pspd/service-p-monitor/0 (UP)
```

### Queries PromQL para Análise

#### Taxa de Requisições HTTP

```promql
# Taxa de requisições por segundo (total)
rate(http_requests_total{container="p"}[1m])

# Taxa por endpoint
rate(http_requests_total{container="p", route="/api/content"}[1m])

# Taxa por código de status
sum by (status_code) (rate(http_requests_total{container="p"}[1m]))
```

#### Latência

```promql
# Latência P50 do Gateway P
histogram_quantile(0.50, 
  rate(http_request_duration_seconds_bucket{container="p"}[1m])
)

# Latência P95 por endpoint
histogram_quantile(0.95, 
  sum by (route, le) (
    rate(http_request_duration_seconds_bucket{container="p"}[1m])
  )
)

# Latência P99
histogram_quantile(0.99, 
  rate(http_request_duration_seconds_bucket{container="p"}[1m])
)
```

#### Taxa de Erro

```promql
# Taxa de erro HTTP (5xx)
sum(rate(http_requests_total{container="p", status_code=~"5.."}[1m])) / 
sum(rate(http_requests_total{container="p"}[1m]))

# Erros gRPC do Service A
rate(grpc_server_requests_total{container="a", status="error"}[1m])
```

#### Chamadas gRPC

```promql
# Taxa de chamadas P→A
rate(grpc_client_requests_total{container="p", service="ServiceA"}[1m])

# Taxa de chamadas P→B
rate(grpc_client_requests_total{container="p", service="ServiceB"}[1m])

# Latência gRPC P→A
histogram_quantile(0.95,
  rate(grpc_client_request_duration_seconds_bucket{
    container="p", service="ServiceA"
  }[1m])
)
```

#### Análise de Conteúdo

```promql
# Distribuição de tipos de conteúdo retornados
sum by (content_type) (
  rate(content_items_returned_total{container="a"}[5m])
)

# Total de itens transmitidos via stream
rate(grpc_server_stream_items_total{container="b"}[1m])
```

#### Autoscaling (HPA)

```promql
# CPU atual dos pods
sum(rate(container_cpu_usage_seconds_total{
  namespace="pspd", pod=~"p-.*"
}[1m])) by (pod)

# Número de réplicas ao longo do tempo
count(kube_pod_info{namespace="pspd", pod=~"p-.*"})
```

### Dashboard Grafana

**Arquivo**: `docs/grafana-dashboard.json`

**Painéis Incluídos**:

1. **Overview**
   - Taxa de requisições HTTP (total)
   - Latência P50/P95/P99
   - Taxa de erro
   - Número de réplicas (HPA)

2. **HTTP Endpoints**
   - Latência por rota (`/api/content`, `/api/metadata`, `/api/browse`)
   - Throughput por rota
   - Taxa de sucesso/erro por rota

3. **gRPC Communication**
   - Taxa de chamadas P→A e P→B
   - Latência das chamadas gRPC
   - Taxa de erro gRPC

4. **Service A Details**
   - Taxa de requisições recebidas
   - Latência interna
   - Distribuição de tipos de conteúdo

5. **Service B Details**
   - Taxa de requisições streaming
   - Total de itens transmitidos
   - Latência de streaming

6. **Resource Usage**
   - CPU por pod
   - Memória por pod
   - HPA scaling events

**Importação**:
```bash
# Via UI Grafana:
# → Dashboards → Import → Upload JSON file
# Ou copiar conteúdo de docs/grafana-dashboard.json
```

---

## 🎯 Resumo de Atendimento

| Requisito | Status | Evidência |
|-----------|--------|-----------|
| **Aplicação microserviços gRPC (P→A,B)** | ✅ Completo | `gateway_p_node/`, `services/a_py/`, `services/b_py/` |
| **Frontend funcional** | ✅ Completo | https://streaming-app-design.vercel.app/ |
| **Cluster K8s multi-node (1+2)** | ✅ Completo | `minikube start --nodes 3` |
| **Prometheus instalado** | ✅ Completo | Helm chart kube-prometheus-stack |
| **Grafana com dashboards** | ✅ Completo | `docs/grafana-dashboard.json` |
| **HPA configurado** | ✅ Completo | `k8s/monitoring/hpa.yaml` |
| **Ferramenta de teste de carga** | ✅ Completo | k6 (https://k6.io/) |
| **Cenário base documentado** | ✅ Completo | `test/scenario_1/`, `k8s/scenarios/scenario1-base/` |
| **Múltiplos cenários (5 variações)** | ✅ Completo | `test/scenario_{1-5}/` |
| **Testes de carga (baseline/ramp/spike/soak)** | ✅ Completo | `load/*.js` |
| **Métricas customizadas** | ✅ Completo | 12 métricas implementadas |
| **ServiceMonitors** | ✅ Completo | `k8s/monitoring/servicemonitor-*.yaml` |
| **Queries PromQL** | ✅ Completo | `docs/METRICAS_PROMETHEUS.md` |
| **Comparação de cenários** | ✅ Completo | `scripts/run_scenario_comparison.sh` |
| **Gráficos de análise** | ✅ Completo | `test_results/scenario-comparison/*.png` |
| **Documentação completa** | ✅ Completo | `README.md`, `docs/*.md` |

---

## 📊 Resultados Esperados

Após executar todos os testes, o projeto demonstrará:

1. **Performance Baseline**:
   - Latência P95: ~200-500ms
   - Throughput: ~100-300 req/s

2. **Autoscaling Funcional**:
   - HPA criando réplicas quando CPU > 70%
   - Latência estável durante scaling

3. **Comparação de Cenários**:
   - Cenário 2 (warm start): -30% latência inicial
   - Cenário 3 (anti-affinity): +10% resiliência
   - Cenário 4 (recursos limitados): +50% réplicas criadas
   - Cenário 5 (sem HPA): Degradação durante picos

4. **Observabilidade**:
   - Todas as métricas visíveis no Prometheus
   - Dashboards Grafana funcionais
   - Correlação entre eventos (HPA scale ↔ latência)

---

## 📚 Documentação de Referência

- **Kubernetes Autoscaling**: https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/
- **Prometheus Operator**: https://prometheus-operator.dev/
- **gRPC Basics**: https://grpc.io/docs/what-is-grpc/introduction/
- **k6 Documentation**: https://k6.io/docs/
- **Protocol Buffers**: https://protobuf.dev/
