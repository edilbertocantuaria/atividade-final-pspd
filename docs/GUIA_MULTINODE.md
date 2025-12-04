# Guia de Migração: Cluster Multi-Node com Prometheus e Grafana

## 📋 Pré-requisitos

- Docker instalado
- kubectl instalado
- minikube instalado
- helm instalado
- Mínimo 8GB RAM e 4 CPUs disponíveis

## 🚀 Setup Completo em 3 Passos

### Passo 1: Criar Cluster Multi-Node (1 control-plane + 2 workers)

```bash
# Criar cluster com 3 nodes
minikube start --nodes 3 --cpus 4 --memory 8192

# Habilitar addons necessários
minikube addons enable metrics-server
minikube addons enable ingress

# Verificar nodes
kubectl get nodes
```

Este processo automaticamente:
- ✅ Cria cluster com 3 nós (1 control-plane + 2 workers)
- ✅ Habilita metrics-server e ingress
- ✅ Configura rede entre os nós

**Tempo estimado**: 3-5 minutos

### Passo 1.5: Instalar Prometheus Stack (Opcional)

```bash
# Adicionar repositório Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Instalar stack completo
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

Instala:
- ✅ Prometheus Operator
- ✅ Grafana com dashboards pré-configurados
- ✅ Alertmanager
- ✅ ServiceMonitors automáticos

**Tempo estimado**: 3-5 minutos

### Passo 2: Deploy das Aplicações

```bash
# Build das imagens no contexto Docker do Minikube
eval $(minikube docker-env)
docker build -t a-py:latest ./services/a_py
docker build -t b-py:latest ./services/b_py
docker build -t p-node:latest ./gateway_p_node

# Deploy dos recursos Kubernetes
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/a.yaml
kubectl apply -f k8s/b.yaml
kubectl apply -f k8s/p.yaml

# Configurar ServiceMonitors para Prometheus (se instalou Prometheus)
kubectl apply -f k8s/servicemonitors.yaml
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
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Acesse: http://localhost:3000
# User: admin | Password: (recuperar do secret)

# Recuperar senha do Grafana:
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d

# Terminal 2: Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Acesse: http://localhost:9090

# Terminal 3: Gateway P
kubectl port-forward -n pspd svc/p-svc 8080:80
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
kubectl port-forward -n pspd svc/p-svc 8080:80

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
minikube delete
minikube start --nodes 3 --cpus 4 --memory 8192
```

### Prometheus não coleta métricas
```bash
# Verificar ServiceMonitors
kubectl get servicemonitor -n pspd

# Recriar ServiceMonitors
kubectl apply -f k8s/servicemonitors.yaml

# Verificar logs do Prometheus
kubectl logs -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -c prometheus
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
minikube stop

# Deletar cluster completamente
minikube delete

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
- **Verificação**: Acesse http://localhost:3000 após port-forward: `kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80`

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
