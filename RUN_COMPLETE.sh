#!/bin/bash
# Execução completa com sistema de checkpoints
# Permite continuar de onde parou em caso de erro

CHECKPOINT_FILE="/tmp/pspd_checkpoint.txt"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Funções de checkpoint
save_checkpoint() {
    echo "$1" > "$CHECKPOINT_FILE"
    echo -e "${GREEN}✓ Checkpoint salvo: Etapa $1 concluída${NC}"
}

load_checkpoint() {
    if [ -f "$CHECKPOINT_FILE" ]; then
        cat "$CHECKPOINT_FILE"
    else
        echo "0"
    fi
}

clear_checkpoint() {
    rm -f "$CHECKPOINT_FILE"
}

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Execução Completa - Cluster Multi-Node + Monitoramento      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Verificar checkpoint existente
CURRENT_STEP=$(load_checkpoint)

if [ "$CURRENT_STEP" != "0" ]; then
    echo -e "${YELLOW}📍 Checkpoint encontrado! Última etapa concluída: $CURRENT_STEP/6${NC}"
    echo ""
    echo "Opções:"
    echo "  1. ✅ Continuar de onde parou (Etapa $((CURRENT_STEP + 1)))"
    echo "  2. 🔄 Recomeçar do zero"
    echo "  3. ❌ Cancelar"
    echo ""
    read -p "Escolha [1/2/3]: " -n 1 -r
    echo
    case $REPLY in
        1)
            START_STEP=$((CURRENT_STEP + 1))
            echo -e "${GREEN}✓ Continuando da etapa $START_STEP${NC}"
            ;;
        2)
            clear_checkpoint
            START_STEP=1
            echo -e "${YELLOW}⚠️  Reiniciando do zero...${NC}"
            ;;
        *)
            echo "❌ Cancelado"
            exit 0
            ;;
    esac
else
    echo "Este guia executará automaticamente:"
    echo "  1. 🏗️  Cluster multi-node (1 master + 2 workers)"
    echo "  2. 📦 Deploy das aplicações"
    echo "  3. 📊 Configuração de ServiceMonitors"
    echo "  4. 🔗 Port-forwards (Gateway, Grafana, Prometheus)"
    echo "  5. 🧪 Testes de carga"
    echo ""
    echo "⏱️  Tempo estimado: 15-20 minutos"
    echo "💡 Em caso de erro, você pode continuar de onde parou!"
    echo ""
    read -p "Deseja continuar? [S/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[SsYy]$ ]] && [[ -n $REPLY ]]; then
        echo "❌ Cancelado"
        exit 0
    fi
    START_STEP=1
fi

set -e

# Passo 1: Criar cluster
if [ $START_STEP -le 1 ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Passo 1/6: Criando cluster multi-node..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ./scripts/setup_multinode_cluster.sh
    save_checkpoint "1"
else
    echo -e "${BLUE}⏭️  Pulando Passo 1/6 (já concluído)${NC}"
fi

# Passo 2: Deploy aplicações
if [ $START_STEP -le 2 ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 Passo 2/6: Deploy das aplicações..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ./scripts/deploy.sh setup
    save_checkpoint "2"
else
    echo -e "${BLUE}⏭️  Pulando Passo 2/6 (já concluído)${NC}"
fi

# Passo 3: Configurar ServiceMonitors
if [ $START_STEP -le 3 ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Passo 3/6: Configurando ServiceMonitors..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ./scripts/deploy.sh monitoring
    save_checkpoint "3"
else
    echo -e "${BLUE}⏭️  Pulando Passo 3/6 (já concluído)${NC}"
fi

# Passo 4: Iniciar port-forwards
if [ $START_STEP -le 4 ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 Passo 4/6: Iniciando port-forwards..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Limpar port-forwards antigos
    pkill -f "kubectl port-forward" 2>/dev/null || true
    sleep 2
    
    # Port-forward Gateway P
    kubectl port-forward -n pspd svc/p-svc 8080:80 > /tmp/pf_gateway.log 2>&1 &
    PF_GATEWAY=$!
    
    # Port-forward Grafana
    kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 > /tmp/pf_grafana.log 2>&1 &
    PF_GRAFANA=$!
    
    # Port-forward Prometheus
    kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 > /tmp/pf_prometheus.log 2>&1 &
    PF_PROMETHEUS=$!
    
    sleep 5
    
    echo ""
    echo -e "${GREEN}✓ Port-forwards ativos:${NC}"
    echo "  Gateway P:   http://localhost:8080"
    echo "  Grafana:     http://localhost:3000 (admin/admin)"
    echo "  Prometheus:  http://localhost:9090"
    
    save_checkpoint "4"
else
    echo -e "${BLUE}⏭️  Pulando Passo 4/6 (já concluído)${NC}"
    echo ""
    echo "💡 Interfaces disponíveis:"
    echo "  Gateway P:   http://localhost:8080"
    echo "  Grafana:     http://localhost:3000"
    echo "  Prometheus:  http://localhost:9090"
fi

# Passo 5: Executar testes
if [ $START_STEP -le 5 ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🧪 Passo 5/6: Executando testes de carga..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "⏳ Aguardando 10s para estabilização..."
    sleep 10
    
    ./scripts/run_all_tests.sh all
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📈 Passo 6/6: Gerando análises..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    python3 scripts/analyze_results.py
    
    save_checkpoint "5"
else
    echo -e "${BLUE}⏭️  Pulando Passo 5/6 (já concluído)${NC}"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅ EXECUÇÃO COMPLETA FINALIZADA COM SUCESSO!                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Recursos disponíveis:"
echo "  • Cluster:     minikube -p pspd-cluster"
echo "  • Pods:        kubectl get pods -n pspd"
echo "  • Monitoring:  kubectl get pods -n monitoring"
echo "  • Gateway:     http://localhost:8080"
echo "  • Grafana:     http://localhost:3000 (admin/admin)"
echo "  • Prometheus:  http://localhost:9090"
echo "  • Resultados:  ./results/"
echo ""
echo "🎯 Próximos passos:"
echo "  1. Importar dashboard do Grafana: k8s/monitoring/grafana-dashboard.json"
echo "  2. Verificar métricas no Prometheus"
echo "  3. Analisar gráficos em: results/"
echo ""
echo "🛑 Para parar:"
echo "  • Port-forwards: pkill -f 'kubectl port-forward'"
echo "  • Cluster:       minikube stop -p pspd-cluster"
echo "  • Limpar tudo:   minikube delete -p pspd-cluster"
echo ""

clear_checkpoint
