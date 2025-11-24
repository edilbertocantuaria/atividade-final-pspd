#!/bin/bash

# Utilitário para obter URL estável do Gateway P
# Tenta NodePort primeiro, fallback para port-forward

NAMESPACE="pspd"
NODEPORT_SVC="p-svc-nodeport"
REGULAR_SVC="p-svc"

# Verificar se NodePort existe
if kubectl get svc -n $NAMESPACE $NODEPORT_SVC &>/dev/null; then
    # Obter IP do minikube e porta do NodePort
    MINIKUBE_IP=$(minikube ip)
    NODEPORT=$(kubectl get svc -n $NAMESPACE $NODEPORT_SVC -o jsonpath='{.spec.ports[0].nodePort}')
    
    if [ -n "$MINIKUBE_IP" ] && [ -n "$NODEPORT" ]; then
        echo "ℹ️  Usando NodePort (mais estável para testes longos)" >&2
        echo "http://${MINIKUBE_IP}:${NODEPORT}"
        exit 0
    fi
fi

# Fallback: usar port-forward
echo "ℹ️  NodePort não disponível, usando port-forward (localhost:8080)" >&2
echo "⚠️  Para testes longos, recomenda-se NodePort: kubectl apply -f k8s/p-nodeport.yaml" >&2

# Verificar se port-forward já está ativo na porta 8080
if ss -tuln 2>/dev/null | grep -q ":8080 " || lsof -i :8080 &>/dev/null; then
    echo "http://localhost:8080"
    exit 0
fi

# Iniciar port-forward
echo "🔗 Iniciando port-forward..." >&2
kubectl port-forward -n $NAMESPACE svc/$REGULAR_SVC 8080:80 > /tmp/pf_auto.log 2>&1 &
PF_PID=$!
echo $PF_PID > /tmp/pf_auto.pid

sleep 3

echo "http://localhost:8080"
