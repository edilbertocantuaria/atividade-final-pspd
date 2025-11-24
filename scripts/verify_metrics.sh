#!/bin/bash
# Script para verificar se métricas Prometheus estão sendo coletadas

set -e

NAMESPACE="${K8S_NAMESPACE:-pspd}"

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Verificação de Métricas Prometheus                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Verificar se pods estão rodando
echo "🔍 Verificando pods no namespace $NAMESPACE..."
if ! kubectl get pods -n "$NAMESPACE" &>/dev/null; then
    echo -e "${RED}❌ Namespace $NAMESPACE não existe ou sem pods${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Namespace encontrado${NC}"
echo ""

# Função para testar endpoint de métricas
test_metrics() {
    local service=$1
    local port=$2
    local pod_label=$3
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Testando: $service"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Pegar primeiro pod
    POD=$(kubectl get pods -n "$NAMESPACE" -l "app=$pod_label" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$POD" ]; then
        echo -e "${RED}❌ Nenhum pod encontrado para app=$pod_label${NC}"
        return 1
    fi
    
    echo "Pod: $POD"
    echo "Porta: $port"
    echo ""
    
    # Fazer port-forward temporário em background
    kubectl port-forward -n "$NAMESPACE" "$POD" "$port:$port" &>/dev/null &
    PF_PID=$!
    sleep 2
    
    # Testar endpoint
    echo "🔗 Acessando http://localhost:$port/metrics..."
    
    if curl -s -f "http://localhost:$port/metrics" > /tmp/metrics_${service}.txt 2>&1; then
        echo -e "${GREEN}✓ Endpoint acessível${NC}"
        echo ""
        echo "📈 Métricas encontradas:"
        
        # Mostrar métricas customizadas
        if [ "$service" == "service-a" ]; then
            grep -E "^(grpc_server_requests_total|grpc_server_request_duration)" /tmp/metrics_${service}.txt | head -5
        elif [ "$service" == "service-b" ]; then
            grep -E "^(grpc_server_requests_total|grpc_server_stream_items)" /tmp/metrics_${service}.txt | head -5
        elif [ "$service" == "gateway-p" ]; then
            grep -E "^(http_requests_total|grpc_client_requests_total)" /tmp/metrics_${service}.txt | head -5
        fi
        
        echo ""
        echo -e "${GREEN}✓ Métricas customizadas OK${NC}"
    else
        echo -e "${RED}❌ Falha ao acessar endpoint${NC}"
        cat /tmp/metrics_${service}.txt 2>/dev/null || true
    fi
    
    # Matar port-forward
    kill $PF_PID 2>/dev/null || true
    wait $PF_PID 2>/dev/null || true
    
    echo ""
}

# Testar cada serviço
test_metrics "service-a" "9101" "a"
test_metrics "service-b" "9102" "b"
test_metrics "gateway-p" "8080" "p"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Verificando ServiceMonitors                                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Verificar ServiceMonitors
if kubectl get servicemonitor -n "$NAMESPACE" &>/dev/null; then
    echo "ServiceMonitors configurados:"
    kubectl get servicemonitor -n "$NAMESPACE" -o wide
    echo ""
    echo -e "${GREEN}✓ ServiceMonitors encontrados${NC}"
else
    echo -e "${YELLOW}⚠️  Nenhum ServiceMonitor encontrado${NC}"
    echo "   Execute: kubectl apply -f k8s/monitoring/"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Queries Prometheus Sugeridas                                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Acesse Prometheus e execute:"
echo ""
echo "# Taxa de requisições no serviço A"
echo "rate(grpc_server_requests_total{app=\"a\"}[1m])"
echo ""
echo "# Latência P95 do serviço A"
echo "histogram_quantile(0.95, rate(grpc_server_request_duration_seconds_bucket{app=\"a\"}[1m]))"
echo ""
echo "# Taxa de requisições HTTP no gateway P"
echo "rate(http_requests_total{app=\"p\"}[1m])"
echo ""
echo "# Latência P95 das chamadas gRPC do gateway P"
echo "histogram_quantile(0.95, rate(grpc_client_request_duration_seconds_bucket{app=\"p\"}[1m]))"
echo ""
echo "# Items streamed pelo serviço B"
echo "rate(grpc_server_stream_items_total{app=\"b\"}[1m])"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "Arquivos de métricas salvos em /tmp/metrics_*.txt"
echo "═══════════════════════════════════════════════════════════════"
