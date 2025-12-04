#!/bin/bash
# Script auxiliar: Setup do Scenario 2 (Warm Start)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$PROJECT_ROOT/test_results/scenario_2"

echo "🔧 Setup Scenario 2: Warm Start"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Verificar cluster Kubernetes
source "$SCRIPT_DIR/../common/k8s_check.sh"
if ! check_kubernetes_cluster; then
    echo "❌ Falha na verificação do cluster Kubernetes"
    exit 1
fi
echo ""

# Limpar
kubectl delete namespace pspd 2>/dev/null || true
sleep 5

# Deploy
kubectl apply -f "$PROJECT_ROOT/k8s/namespace.yaml"
kubectl apply -f "$PROJECT_ROOT/k8s/scenarios/scenario2-replicas/"
sleep 10

# Aguardar
kubectl wait --for=condition=ready pod -l app=a -n pspd --timeout=60s
kubectl wait --for=condition=ready pod -l app=b -n pspd --timeout=60s
kubectl wait --for=condition=ready pod -l app=p -n pspd --timeout=60s

echo "✅ Pods prontos:"
kubectl get pods -n pspd

# Port-forward
pkill -f "port-forward.*pspd.*p-svc" 2>/dev/null || true
sleep 1
kubectl port-forward -n pspd svc/p-svc 8080:80 > /dev/null 2>&1 &
sleep 5

# Testar com retry (até 10 tentativas)
echo "🧪 Testando conectividade..."
for i in {1..10}; do
    if curl -s --max-time 2 http://localhost:8080/api/content?type=all > /dev/null 2>&1; then
        echo "✅ Gateway OK (http://localhost:8080)"
        exit 0
    fi
    echo "   Tentativa $i/10 falhou, aguardando..."
    sleep 2
done

echo "❌ Falha após 10 tentativas"
echo "   Verifique se os pods estão rodando: kubectl get pods -n pspd"
echo "   Verifique logs: kubectl logs -n pspd -l app=p"
exit 1
