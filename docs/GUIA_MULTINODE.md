# Guia de Migração: Cluster Multi-Node com Prometheus e Grafana

## 📋 Pré-requisitos

- Docker instalado
- kubectl instalado
- minikube instalado
- helm instalado
- Mínimo 8GB RAM e 4 CPUs disponíveis

## 🚀 Setup Completo em 3 Passos

### Passo 1: Criar Cluster Multi-Node (1 master + 2 workers)

```bash
./scripts/setup_multinode_cluster.sh
```

Este script automaticamente:
- ✅ Cria cluster com 3 nós (1 master + 2 workers)
- ✅ Habilita metrics-server e ingress
- ✅ Instala kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
- ✅ Configura acesso via NodePort

**Tempo estimado**: 5-10 minutos

### Passo 2: Deploy das Aplicações

```bash
# Build e deploy completo
./scripts/deploy.sh setup

# Configurar ServiceMonitors para Prometheus
./scripts/deploy.sh monitoring
```

### Passo 3: Acessar Interfaces de Monitoramento

#### Opção A: Via NodePort (mais estável)

```bash
# Obter IP do cluster
MINIKUBE_IP=$(minikube ip -p pspd-cluster)

# Grafana
GRAFANA_PORT=$(kubectl get svc -n monitoring prometheus-grafana -o jsonpath='{.spec.ports[0].nodePort}')
echo "Grafana: http://$MINIKUBE_IP:$GRAFANA_PORT"

# Prometheus
PROMETHEUS_PORT=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.spec.ports[0].nodePort}')
echo "Prometheus: http://$MINIKUBE_IP:$PROMETHEUS_PORT"

# Gateway P
kubectl get svc -n pspd p-svc
```

#### Opção B: Via Port-Forward

```bash
# Terminal 1: Grafana
./scripts/deploy.sh grafana
# Acesse: http://localhost:3000
# User: admin | Password: admin

# Terminal 2: Prometheus
./scripts/deploy.sh prometheus
# Acesse: http://localhost:9090

# Terminal 3: Gateway P
./scripts/deploy.sh port-forward
# Acesse: http://localhost:8080
```

## 📊 Configurar Dashboard no Grafana

1. Acesse Grafana (http://localhost:3000 ou NodePort)
2. Login: `admin` / `admin`
3. Vá em: **+** → **Import** → **Upload JSON file**
4. Selecione: `k8s/monitoring/grafana-dashboard.json`
5. Clique em **Import**

O dashboard inclui:
- 📈 HTTP Request Rate
- ⏱️ Request Duration (p95, p99)
- 🔢 Pod Replicas (HPA)
- 💻 CPU Usage por pod
- 💾 Memory Usage por pod
- ❌ Error Rate

## 🧪 Executar Testes de Carga

```bash
# Terminal 1: Monitoramento em tempo real
./scripts/run_all_tests.sh monitor

# Terminal 2: Port-forward para aplicação
./scripts/deploy.sh port-forward

# Terminal 3: Executar testes
BASE_URL=http://localhost:8080 ./scripts/run_all_tests.sh all

# Gerar gráficos
./scripts/run_all_tests.sh analyze
```

## 🔍 Verificar Cluster Multi-Node

```bash
# Ver todos os nós
kubectl get nodes -o wide

# Deve mostrar:
# NAME               STATUS   ROLES           AGE   VERSION
# pspd-cluster       Ready    control-plane   10m   v1.28.x
# pspd-cluster-m02   Ready    worker          9m    v1.28.x
# pspd-cluster-m03   Ready    worker          8m    v1.28.x

# Ver distribuição de pods nos nós
kubectl get pods -n pspd -o wide

# Ver métricas dos nós
kubectl top nodes
```

## 📊 Verificar Prometheus

```bash
# Ver ServiceMonitors configurados
kubectl get servicemonitor -n pspd

# Ver targets no Prometheus
# Acesse: http://localhost:9090/targets
# Deve mostrar:
# - pspd/service-a-monitor
# - pspd/service-b-monitor
# - pspd/gateway-p-monitor

# Queries úteis:
# rate(http_requests_total{namespace="pspd"}[1m])
# histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[1m]))
```

## 🎯 Validação Completa

### ✅ Cluster Multi-Node
```bash
kubectl get nodes
# Deve mostrar 3 nós (1 master + 2 workers)
```

### ✅ Prometheus Instalado
```bash
kubectl get pods -n monitoring | grep prometheus
# Deve mostrar: prometheus-kube-prometheus-prometheus-0 Running
```

### ✅ Grafana Instalado
```bash
kubectl get pods -n monitoring | grep grafana
# Deve mostrar: prometheus-grafana-xxx Running
```

### ✅ ServiceMonitors Configurados
```bash
kubectl get servicemonitor -n pspd
# Deve mostrar 3 ServiceMonitors
```

### ✅ Métricas Sendo Coletadas
```bash
# Via Prometheus UI (http://localhost:9090)
# Query: up{namespace="pspd"}
# Deve retornar 3 targets UP
```

## 🛠️ Troubleshooting

### Cluster não inicia
```bash
# Aumentar recursos
minikube delete -p pspd-cluster
minikube start -p pspd-cluster --nodes 3 --cpus 4 --memory 8192
```

### Prometheus não coleta métricas
```bash
# Verificar ServiceMonitors
kubectl get servicemonitor -n pspd

# Recriar ServiceMonitors
./scripts/deploy.sh monitoring

# Verificar logs do Prometheus
kubectl logs -n monitoring prometheus-kube-prometheus-prometheus-0
```

### Grafana não abre
```bash
# Verificar pod
kubectl get pods -n monitoring | grep grafana

# Ver logs
kubectl logs -n monitoring deployment/prometheus-grafana

# Restart
kubectl rollout restart deployment -n monitoring prometheus-grafana
```

### Pods não distribuem nos workers
```bash
# Remover taint do master (se necessário para testes)
kubectl taint nodes pspd-cluster node-role.kubernetes.io/control-plane:NoSchedule-

# Adicionar nodeSelector nos deployments (opcional)
# Editar k8s/a.yaml, k8s/b.yaml, k8s/p.yaml:
# spec:
#   template:
#     spec:
#       nodeSelector:
#         node-role.kubernetes.io/worker: "true"
```

## 📚 Recursos Adicionais

### Comandos Úteis

```bash
# Listar todos os recursos
kubectl get all -n pspd
kubectl get all -n monitoring

# Ver logs agregados
kubectl logs -n pspd -l app=p --tail=100 -f

# Escalar manualmente
kubectl scale deployment -n pspd p-deploy --replicas=5

# Ver eventos do cluster
kubectl get events -n pspd --sort-by='.lastTimestamp'

# Ver uso de recursos
kubectl top pods -n pspd
kubectl top nodes
```

### Limpeza

```bash
# Parar cluster (preserva dados)
minikube stop -p pspd-cluster

# Deletar cluster completamente
minikube delete -p pspd-cluster

# Limpar apenas namespace pspd
kubectl delete namespace pspd
```

## 🎓 Atendimento aos Requisitos Acadêmicos

### ✅ Requisito 1: Cluster Multi-Node
- **Requisito**: "Cluster composto por um nó mestre e pelo menos dois nós escravos"
- **Implementado**: 1 master (pspd-cluster) + 2 workers (pspd-cluster-m02, m03)
- **Verificação**: `kubectl get nodes`

### ✅ Requisito 2: Prometheus no K8s
- **Requisito**: "Estudar e instalar, no K8S, o Prometheus"
- **Implementado**: kube-prometheus-stack via Helm
- **Verificação**: `kubectl get pods -n monitoring | grep prometheus`

### ✅ Requisito 3: Interface Web de Monitoramento
- **Requisito**: "Interface web de monitoramento do cluster"
- **Implementado**: Grafana com dashboard customizado
- **Verificação**: Acesse http://localhost:3000 após `./scripts/deploy.sh grafana`

### ✅ Requisito 4: ServiceMonitors
- **Implementado**: 3 ServiceMonitors (gateway-p, service-a, service-b)
- **Verificação**: `kubectl get servicemonitor -n pspd`

### ✅ Requisito 5: Métricas Expostas
- **Implementado**: Métricas HTTP e gRPC em todos os serviços
- **Verificação**: `curl http://localhost:8080/metrics`

## 📝 Notas de Implementação

### Escolha do minikube multi-node

Optamos por **minikube multi-node** em vez de kind ou k3s por:
- ✅ Suporte nativo a drivers (Docker, VirtualBox, KVM)
- ✅ Fácil integração com imagens locais (`minikube image load`)
- ✅ Comandos consistentes com single-node (migração suave)
- ✅ Suporte a NodePort direto (`minikube ip`)

### Stack de Monitoramento

Optamos por **kube-prometheus-stack** (Helm) por:
- ✅ Prometheus Operator incluso
- ✅ Grafana pré-configurado
- ✅ Alertmanager incluso
- ✅ ServiceMonitor CRD nativo
- ✅ Dashboards padrão para K8s

### Configurações Customizadas

- ServiceMonitors coletam métricas a cada 15s
- Grafana com senha `admin` (trocar em produção!)
- NodePort habilitado para acesso externo fácil
- HPA configurado para auto-scaling baseado em CPU
