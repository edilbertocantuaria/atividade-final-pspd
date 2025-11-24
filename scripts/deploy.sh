#!/bin/bash
# Script unificado para setup e deploy completo do projeto

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
K8S_DIR="$PROJECT_DIR/k8s"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_usage() {
    echo "Uso: $0 [COMANDO]"
    echo ""
    echo "Comandos:"
    echo "  build        - Apenas construir imagens Docker"
    echo "  deploy       - Apenas fazer deploy no K8s (requer imagens prontas)"
    echo "  setup        - Build + Deploy completo (padrão)"
    echo "  monitoring   - Deploy ServiceMonitors para Prometheus"
    echo "  clean        - Limpar recursos do K8s"
    echo "  restart      - Reiniciar deployments"
    echo "  port-forward - Iniciar port-forward com auto-restart"
    echo "  grafana      - Port-forward para Grafana"
    echo "  prometheus   - Port-forward para Prometheus"
    echo ""
    echo "Exemplos:"
    echo "  $0              # Setup completo"
    echo "  $0 build        # Apenas build"
    echo "  $0 deploy       # Apenas deploy"
    echo "  $0 monitoring   # Deploy ServiceMonitors"
    echo "  $0 grafana      # Acessar Grafana"
    echo "  $0 clean        # Limpar tudo"
}

build_images() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔨 Construindo imagens Docker..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Detectar perfil do minikube
    MINIKUBE_PROFILE=$(kubectl config current-context 2>/dev/null || echo "minikube")
    
    echo "Construindo imagens dentro do ambiente Docker do minikube..."
    
    # Configurar ambiente Docker do minikube
    eval $(minikube -p $MINIKUBE_PROFILE docker-env)
    
    # Construir imagens diretamente no Docker do minikube
    docker build -t a-service:local "$PROJECT_DIR/services/a_py"
    echo -e "${GREEN}✓ Service A construído${NC}"
    
    docker build -t b-service:local "$PROJECT_DIR/services/b_py"
    echo -e "${GREEN}✓ Service B construído${NC}"
    
    docker build -t p-gateway:local "$PROJECT_DIR/gateway_p_node"
    echo -e "${GREEN}✓ Gateway P construído${NC}"
    
    # Resetar ambiente Docker
    eval $(minikube -p $MINIKUBE_PROFILE docker-env -u)
    
    echo ""
    echo -e "${GREEN}✓ Imagens construídas no Docker do minikube${NC}"
    echo -e "${YELLOW}⚠️  Imagens disponíveis em todos os nós do cluster${NC}"
    echo ""
}

deploy_k8s() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "☸️  Fazendo deploy no Kubernetes..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    kubectl apply -f "$K8S_DIR/namespace.yaml"
    kubectl apply -f "$K8S_DIR/a.yaml"
    kubectl apply -f "$K8S_DIR/b.yaml"
    kubectl apply -f "$K8S_DIR/p.yaml"
    kubectl apply -f "$K8S_DIR/ingress.yaml"
    kubectl apply -f "$K8S_DIR/monitoring/hpa.yaml"
    
    echo ""
    echo "⏳ Aguardando pods ficarem prontos..."
    kubectl wait --for=condition=available --timeout=180s \
        deployment/a-deploy deployment/b-deploy deployment/p-deploy -n pspd
    
    echo -e "${GREEN}✓ Deploy concluído${NC}"
    echo ""
    kubectl get pods -n pspd
    echo ""
    kubectl get hpa -n pspd
}

clean_k8s() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🧹 Limpando recursos do Kubernetes..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    kubectl delete namespace pspd --ignore-not-found=true
    
    echo -e "${GREEN}✓ Recursos removidos${NC}"
}

restart_deployments() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔄 Reiniciando deployments..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    kubectl rollout restart deployment -n pspd p-deploy a-deploy b-deploy
    kubectl rollout status deployment -n pspd p-deploy
    kubectl rollout status deployment -n pspd a-deploy
    kubectl rollout status deployment -n pspd b-deploy
    
    echo -e "${GREEN}✓ Deployments reiniciados${NC}"
}

start_port_forward() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 Iniciando port-forward com auto-restart..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    NAMESPACE="pspd"
    SERVICE="p-svc"
    LOCAL_PORT=8080
    REMOTE_PORT=80
    LOG_FILE="/tmp/pf_stable.log"
    
    # Limpar port-forwards antigos
    pkill -f "kubectl port-forward.*$SERVICE" 2>/dev/null || true
    sleep 1
    
    # Função para iniciar port-forward
    start_pf() {
        echo "[$(date '+%H:%M:%S')] Iniciando port-forward..." | tee -a $LOG_FILE
        kubectl port-forward -n $NAMESPACE svc/$SERVICE $LOCAL_PORT:$REMOTE_PORT >> $LOG_FILE 2>&1 &
        PF_PID=$!
        echo $PF_PID > /tmp/pf_stable.pid
        echo "[$(date '+%H:%M:%S')] PID: $PF_PID" | tee -a $LOG_FILE
    }
    
    # Iniciar
    start_pf
    sleep 3
    
    echo ""
    echo -e "${GREEN}✓ Port-forward ativo em http://localhost:8080${NC}"
    echo "  Log: $LOG_FILE"
    echo "  PID: $(cat /tmp/pf_stable.pid)"
    echo ""
    echo "Para parar: kill \$(cat /tmp/pf_stable.pid)"
    echo ""
    
    # Loop de monitoramento
    echo "Monitorando (Ctrl+C para parar)..."
    RESTART_COUNT=0
    
    while true; do
        if [ -f /tmp/pf_stable.pid ]; then
            PID=$(cat /tmp/pf_stable.pid)
            if ! ps -p $PID > /dev/null 2>&1; then
                RESTART_COUNT=$((RESTART_COUNT + 1))
                echo "[$(date '+%H:%M:%S')] ⚠️  Port-forward caiu! Reiniciando (#$RESTART_COUNT)..." | tee -a $LOG_FILE
                sleep 2
                start_pf
                sleep 3
            fi
        fi
        sleep 5
    done
}

deploy_monitoring() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Configurando monitoramento Prometheus..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Verificar se Prometheus está instalado
    if ! kubectl get namespace monitoring &> /dev/null; then
        echo -e "${YELLOW}⚠️  Namespace monitoring não encontrado${NC}"
        echo "Execute primeiro: ./scripts/setup_multinode_cluster.sh"
        exit 1
    fi
    
    # Deploy ServiceMonitors
    echo "Aplicando ServiceMonitors..."
    kubectl apply -f "$K8S_DIR/monitoring/servicemonitor-a.yaml"
    kubectl apply -f "$K8S_DIR/monitoring/servicemonitor-b.yaml"
    kubectl apply -f "$K8S_DIR/monitoring/servicemonitor-gateway.yaml"
    
    echo ""
    echo -e "${GREEN}✓ ServiceMonitors configurados${NC}"
    echo ""
    echo "📊 ServiceMonitors ativos:"
    kubectl get servicemonitor -n pspd
    echo ""
    echo "💡 Próximos passos:"
    echo "  1. Acessar Grafana: ./scripts/deploy.sh grafana"
    echo "  2. Importar dashboard de k8s/monitoring/grafana-dashboard.json"
    echo "  3. Acessar Prometheus: ./scripts/deploy.sh prometheus"
}

start_grafana_pf() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Iniciando port-forward para Grafana..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    pkill -f "kubectl port-forward.*grafana" 2>/dev/null || true
    sleep 1
    
    kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 > /tmp/pf_grafana.log 2>&1 &
    PF_PID=$!
    echo $PF_PID > /tmp/pf_grafana.pid
    
    sleep 3
    
    echo ""
    echo -e "${GREEN}✓ Grafana acessível em http://localhost:3000${NC}"
    echo "  User: admin"
    echo "  Password: admin"
    echo ""
    echo "  PID: $PF_PID"
    echo "  Log: /tmp/pf_grafana.log"
    echo ""
    echo "Para parar: kill \$(cat /tmp/pf_grafana.pid)"
    echo ""
    echo "📊 Dashboard disponível em:"
    echo "  k8s/monitoring/grafana-dashboard.json"
    echo "  (Importar via UI: + → Import → Upload JSON)"
}

start_prometheus_pf() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Iniciando port-forward para Prometheus..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    pkill -f "kubectl port-forward.*prometheus.*9090" 2>/dev/null || true
    sleep 1
    
    kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 > /tmp/pf_prometheus.log 2>&1 &
    PF_PID=$!
    echo $PF_PID > /tmp/pf_prometheus.pid
    
    sleep 3
    
    echo ""
    echo -e "${GREEN}✓ Prometheus acessível em http://localhost:9090${NC}"
    echo ""
    echo "  PID: $PF_PID"
    echo "  Log: /tmp/pf_prometheus.log"
    echo ""
    echo "Para parar: kill \$(cat /tmp/pf_prometheus.pid)"
    echo ""
    echo "💡 Queries úteis:"
    echo "  rate(http_requests_total{namespace=\"pspd\"}[1m])"
    echo "  histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[1m]))"
}

# Main
COMMAND="${1:-setup}"

case "$COMMAND" in
    build)
        build_images
        ;;
    deploy)
        deploy_k8s
        ;;
    setup)
        build_images
        deploy_k8s
        ;;
    monitoring|mon)
        deploy_monitoring
        ;;
    grafana)
        start_grafana_pf
        ;;
    prometheus|prom)
        start_prometheus_pf
        ;;
    clean)
        clean_k8s
        ;;
    restart)
        restart_deployments
        ;;
    port-forward|pf)
        start_port_forward
        ;;
    -h|--help|help)
        show_usage
        ;;
    *)
        echo -e "${RED}Comando inválido: $COMMAND${NC}"
        echo ""
        show_usage
        exit 1
        ;;
esac
