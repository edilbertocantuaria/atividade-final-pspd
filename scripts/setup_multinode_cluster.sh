#!/bin/bash
# Script para criar cluster Kubernetes multi-node
# Requisito: 1 master + 2 workers

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CLUSTER_NAME="${CLUSTER_NAME:-pspd-cluster}"
NODES="${NODES:-2}" # Número de workers (além do master)

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Setup Cluster Kubernetes Multi-Node                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Cluster: $CLUSTER_NAME"
echo "Configuração: 1 master + $NODES workers"
echo ""

# Verificar dependências
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}✗ $1 não encontrado${NC}"
        echo "  Instale com: $2"
        exit 1
    fi
    echo -e "${GREEN}✓ $1 disponível${NC}"
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 1. Verificando dependências..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_command docker "curl -fsSL https://get.docker.com | sh"
check_command kubectl "https://kubernetes.io/docs/tasks/tools/"
check_command minikube "https://minikube.sigs.k8s.io/docs/start/"
check_command helm "https://helm.sh/docs/intro/install/"
echo ""

# Limpar cluster anterior se existir
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧹 2. Limpando cluster anterior (se existir)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if minikube status -p $CLUSTER_NAME &> /dev/null; then
    echo "Deletando cluster anterior: $CLUSTER_NAME"
    minikube delete -p $CLUSTER_NAME
fi
echo ""

# Criar cluster multi-node
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 3. Criando cluster multi-node..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Isso pode levar alguns minutos..."
echo ""

minikube start -p $CLUSTER_NAME \
    --nodes $((NODES + 1)) \
    --cpus 2 \
    --memory 4096 \
    --driver docker \
    --kubernetes-version stable

echo ""
echo -e "${GREEN}✓ Cluster criado com sucesso${NC}"
echo ""

# Habilitar addons essenciais
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 4. Habilitando addons..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
minikube addons enable metrics-server -p $CLUSTER_NAME
minikube addons enable ingress -p $CLUSTER_NAME
echo ""

# Verificar nós
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 5. Verificando nós do cluster..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get nodes -o wide
echo ""

# Rotular workers
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏷️  6. Rotulando nós..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Obter lista de nós
MASTER_NODE=$(kubectl get nodes -o name | grep -m1 "node/$CLUSTER_NAME$" | cut -d'/' -f2)
WORKER_NODES=$(kubectl get nodes -o name | grep "node/$CLUSTER_NAME-m" | cut -d'/' -f2)

echo "Master: $MASTER_NODE"
kubectl label node $MASTER_NODE node-role.kubernetes.io/control-plane=true --overwrite
kubectl taint nodes $MASTER_NODE node-role.kubernetes.io/control-plane=true:NoSchedule --overwrite

WORKER_COUNT=1
for node in $WORKER_NODES; do
    echo "Worker $WORKER_COUNT: $node"
    kubectl label node $node node-role.kubernetes.io/worker=true --overwrite
    WORKER_COUNT=$((WORKER_COUNT + 1))
done
echo ""

# Aguardar nós ficarem prontos
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⏳ 7. Aguardando nós ficarem prontos..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl wait --for=condition=Ready nodes --all --timeout=300s
echo ""

# Instalar Prometheus Stack
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 8. Instalando Prometheus + Grafana Stack..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Adicionar repositório Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Criar namespace de monitoramento
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Instalar kube-prometheus-stack
echo "Instalando kube-prometheus-stack (Prometheus + Grafana + Alertmanager)..."
helm install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
    --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
    --set grafana.adminPassword=admin \
    --set grafana.service.type=NodePort \
    --set prometheus.service.type=NodePort \
    --wait \
    --timeout 10m

echo ""
echo -e "${GREEN}✓ Prometheus Stack instalado${NC}"
echo ""

# Aguardar pods do monitoring
echo "Aguardando pods de monitoramento ficarem prontos..."
kubectl wait --for=condition=Ready pods --all -n monitoring --timeout=300s
echo ""

# Resumo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅ Cluster Multi-Node Configurado com Sucesso!              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Resumo do Cluster:"
echo "─────────────────────────────────────────────────────────────"
kubectl get nodes
echo ""
echo "📈 Componentes de Monitoramento:"
echo "─────────────────────────────────────────────────────────────"
kubectl get pods -n monitoring
echo ""
echo "🔗 Acessando Interfaces Web:"
echo "─────────────────────────────────────────────────────────────"

GRAFANA_PORT=$(kubectl get svc -n monitoring prometheus-grafana -o jsonpath='{.spec.ports[0].nodePort}')
PROMETHEUS_PORT=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.spec.ports[0].nodePort}')
MINIKUBE_IP=$(minikube ip -p $CLUSTER_NAME)

echo "Grafana:"
echo "  URL: http://$MINIKUBE_IP:$GRAFANA_PORT"
echo "  User: admin"
echo "  Password: admin"
echo ""
echo "Prometheus:"
echo "  URL: http://$MINIKUBE_IP:$PROMETHEUS_PORT"
echo ""
echo "Ou use port-forward:"
echo "  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "  kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo ""
echo "💡 Próximos passos:"
echo "  1. Deploy das aplicações: ./scripts/deploy.sh setup"
echo "  2. Configurar ServiceMonitors: ./scripts/deploy.sh monitoring"
echo "  3. Importar dashboards no Grafana"
echo "  4. Executar testes: ./scripts/run_all_tests.sh all"
echo ""
echo "🛑 Para parar o cluster: minikube stop -p $CLUSTER_NAME"
echo "🛑 Para deletar o cluster: minikube delete -p $CLUSTER_NAME"
echo ""
