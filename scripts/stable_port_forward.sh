#!/bin/bash

# Script para manter port-forward ativo durante testes longos
# Uso: ./scripts/stable_port_forward.sh [porta_local] [porta_remote]

NAMESPACE="pspd"
SERVICE="p-svc"
LOCAL_PORT=${1:-8080}
REMOTE_PORT=${2:-80}
LOG_FILE="/tmp/pf_stable.log"

echo "🔗 Iniciando port-forward estável"
echo "   Namespace: $NAMESPACE"
echo "   Service: $SERVICE"
echo "   Port: $LOCAL_PORT:$REMOTE_PORT"
echo "   Log: $LOG_FILE"
echo ""

# Função para iniciar port-forward
start_pf() {
    echo "[$(date '+%H:%M:%S')] Iniciando port-forward..." | tee -a $LOG_FILE
    kubectl port-forward -n $NAMESPACE svc/$SERVICE $LOCAL_PORT:$REMOTE_PORT >> $LOG_FILE 2>&1 &
    PF_PID=$!
    echo $PF_PID > /tmp/pf_stable.pid
    echo "[$(date '+%H:%M:%S')] PID: $PF_PID" | tee -a $LOG_FILE
}

# Função para verificar se port-forward está ativo
check_pf() {
    if [ -f /tmp/pf_stable.pid ]; then
        PID=$(cat /tmp/pf_stable.pid)
        if ps -p $PID > /dev/null 2>&1; then
            return 0  # Está rodando
        fi
    fi
    return 1  # Não está rodando
}

# Limpar processos antigos
pkill -f "kubectl port-forward.*$SERVICE" 2>/dev/null || true
sleep 1

# Iniciar port-forward
start_pf
sleep 3

# Loop de monitoramento
echo "[$(date '+%H:%M:%S')] Monitorando port-forward (Ctrl+C para parar)..."
echo "   Para parar: kill \$(cat /tmp/pf_stable.pid)"
echo ""
echo "💡 Durante testes de spike é normal que o port-forward caia"
echo "   O script reiniciará automaticamente"
echo ""

RESTART_COUNT=0
RESTART_DELAY=2

while true; do
    if ! check_pf; then
        RESTART_COUNT=$((RESTART_COUNT + 1))
        
        # Aumentar delay progressivo após muitos restarts
        if [ $RESTART_COUNT -gt 10 ]; then
            RESTART_DELAY=5
        elif [ $RESTART_COUNT -gt 5 ]; then
            RESTART_DELAY=3
        fi
        
        echo "[$(date '+%H:%M:%S')] ⚠️  Port-forward caiu! Reiniciando em ${RESTART_DELAY}s (#$RESTART_COUNT)..." | tee -a $LOG_FILE
        sleep $RESTART_DELAY
        
        # Limpar processos órfãos
        pkill -f "kubectl port-forward.*$SERVICE" 2>/dev/null || true
        sleep 1
        
        start_pf
        sleep 3
    fi
    sleep 5
done