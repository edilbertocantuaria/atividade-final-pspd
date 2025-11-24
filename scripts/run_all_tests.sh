#!/bin/bash
# Script unificado para executar testes e monitoramento

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$PROJECT_DIR/results"
LOAD_DIR="$PROJECT_DIR/load"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_usage() {
    echo "Uso: $0 [COMANDO]"
    echo ""
    echo "Comandos:"
    echo "  all         - Executar todos os testes (padrão)"
    echo "  baseline    - Apenas teste baseline"
    echo "  ramp        - Apenas teste ramp"
    echo "  spike       - Apenas teste spike (sem erros)"
    echo "  soak        - Apenas teste soak"
    echo "  stress      - Teste de stress (PODE gerar erros)"
    echo "  monitor     - Monitor em tempo real"
    echo "  analyze     - Gerar gráficos e análise"
    echo ""
    echo "Variáveis de ambiente:"
    echo "  BASE_URL    - URL do gateway (padrão: http://localhost:8080)"
    echo "  NAMESPACE   - Namespace K8s (padrão: pspd)"
    echo ""
    echo "Exemplos:"
    echo "  $0              # Todos os testes"
    echo "  $0 baseline     # Apenas baseline"
    echo "  $0 stress       # Teste extremo (encontra limite)"
    echo "  $0 monitor      # Apenas monitor"
    echo "  BASE_URL=http://192.168.49.2:30080 $0 all"
}

BASE_URL="${BASE_URL:-http://localhost:8080}"
K8S_NAMESPACE="${K8S_NAMESPACE:-pspd}"

capture_k8s_metrics() {
    local test_name=$1
    local suffix=${2:-}
    local result_dir="$RESULTS_DIR/$test_name"
    
    mkdir -p "$result_dir"
    kubectl top pods -n "$K8S_NAMESPACE" > "$result_dir/pod-metrics${suffix}.txt" 2>/dev/null || true
    kubectl get hpa -n "$K8S_NAMESPACE" > "$result_dir/hpa-status${suffix}.txt" 2>/dev/null || true
    kubectl get pods -n "$K8S_NAMESPACE" -o wide > "$result_dir/pods-status${suffix}.txt" 2>/dev/null || true
}

check_service() {
    echo "🔍 Verificando serviço..."
    if ! curl -s -f "$BASE_URL" > /dev/null 2>&1; then
        echo -e "${RED}❌ Serviço não acessível em $BASE_URL${NC}"
        echo "   Execute: kubectl port-forward -n $K8S_NAMESPACE svc/p-svc 8080:80"
        exit 1
    fi
    echo -e "${GREEN}✓ Serviço acessível${NC}"
}

run_test() {
    local test_name=$1
    local test_file="$LOAD_DIR/${test_name}.js"
    local result_dir="$RESULTS_DIR/$test_name"
    
    if [ ! -f "$test_file" ]; then
        echo -e "${RED}❌ Teste não encontrado: $test_file${NC}"
        return 1
    fi
    
    echo "═══════════════════════════════════════════════════════════════"
    echo ">>> Teste: ${test_name^^}"
    echo "═══════════════════════════════════════════════════════════════"
    
    mkdir -p "$result_dir"
    capture_k8s_metrics "$test_name" "-pre"
    
    k6 run --out json="$result_dir/metrics.json" \
        -e BASE_URL="$BASE_URL" \
        "$test_file" | tee "$result_dir/output.txt"
    
    capture_k8s_metrics "$test_name" "-post"
    
    if [ "$test_name" == "spike" ]; then
        kubectl get events -n "$K8S_NAMESPACE" --sort-by='.lastTimestamp' | tail -30 \
            > "$result_dir/events.txt" 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ Teste $test_name concluído${NC}"
}

run_all_tests() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  Executando Testes de Observabilidade K8s                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Target: $BASE_URL"
    echo "Namespace: $K8S_NAMESPACE"
    echo ""
    
    check_service
    
    # Baseline
    run_test "baseline"
    echo "⏳ Aguardando estabilização (30s)..."
    sleep 30
    
    # Ramp
    echo ""
    echo "💡 Dica: Execute 'watch -n 2 kubectl get hpa -n $K8S_NAMESPACE' em outro terminal"
    sleep 3
    run_test "ramp"
    echo "⏳ Aguardando scale-down (60s)..."
    sleep 60
    
    # Spike (ajustado para não gerar erros)
    echo ""
    echo "💥 Teste de Spike: Pico súbito de 10→80 VUs"
    echo "   (Ajustado para evitar erros - testa resiliência com carga moderada)"
    echo ""
    sleep 3
    run_test "spike"
    echo "⏳ Aguardando estabilização (30s)..."
    sleep 30
    
    # Stress (opcional - pode gerar erros)
    echo ""
    read -t 15 -p "Executar teste de STRESS (10→200 VUs, PODE gerar erros)? [y/N] (auto-skip em 15s) " -n 1 -r
    RESULT=$?
    echo
    if [ $RESULT -eq 0 ] && [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "⚠️  TESTE DE STRESS - Encontra o limite máximo do sistema"
        echo "   • Pode causar taxa de erro até 50%"
        echo "   • Objetivo: identificar capacidade máxima"
        echo ""
        run_test "stress"
        echo "⏳ Aguardando recuperação (60s)..."
        sleep 60
    else
        if [ $RESULT -gt 128 ]; then
            echo "⏱️  Timeout - pulando teste de stress"
        else
            echo "⏭️  Pulando teste de stress"
        fi
    fi
    
    # Soak (opcional)
    echo ""
    read -t 15 -p "Executar teste soak (11+ minutos)? [y/N] (auto-skip em 15s) " -n 1 -r
    RESULT=$?
    echo
    if [ $RESULT -eq 0 ] && [[ $REPLY =~ ^[Yy]$ ]]; then
        run_test "soak"
    else
        if [ $RESULT -gt 128 ]; then
            echo "⏱️  Timeout - pulando teste soak"
        else
            echo "⏭️  Pulando teste soak"
        fi
    fi
    
    # Capturar estado final
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo ">>> Coletando métricas finais"
    echo "═══════════════════════════════════════════════════════════════"
    
    kubectl get hpa -n "$K8S_NAMESPACE" -o yaml > "$RESULTS_DIR/hpa-final.yaml" 2>/dev/null || true
    kubectl top pods -n "$K8S_NAMESPACE" > "$RESULTS_DIR/pods-final.txt" 2>/dev/null || true
    kubectl describe hpa -n "$K8S_NAMESPACE" > "$RESULTS_DIR/hpa-describe.txt" 2>/dev/null || true
    kubectl get events -n "$K8S_NAMESPACE" --sort-by='.lastTimestamp' > "$RESULTS_DIR/events-history.txt" 2>/dev/null || true
    curl -s "$BASE_URL/metrics" > "$RESULTS_DIR/prometheus-metrics.txt" 2>/dev/null || true
    
    kubectl logs -n "$K8S_NAMESPACE" -l app=p --tail=1000 > "$RESULTS_DIR/gateway-logs.txt" 2>/dev/null || true
    kubectl logs -n "$K8S_NAMESPACE" -l app=a --tail=500 > "$RESULTS_DIR/service-a-logs.txt" 2>/dev/null || true
    kubectl logs -n "$K8S_NAMESPACE" -l app=b --tail=500 > "$RESULTS_DIR/service-b-logs.txt" 2>/dev/null || true
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ✅ Testes concluídos com sucesso!                          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Resultados em: $RESULTS_DIR"
    echo ""
    echo "🔍 Comparação rápida:"
    echo "─────────────────────────────────────────────────────────────"
    grep "http_req_duration.*avg" "$RESULTS_DIR"/*/output.txt 2>/dev/null || true
    echo "─────────────────────────────────────────────────────────────"
    echo ""
    echo "💡 Próximos passos:"
    echo "  - Gerar análise: $0 analyze"
    echo "  - Ver logs: cat $RESULTS_DIR/gateway-logs.txt"
}

run_monitor() {
    NAMESPACE="$K8S_NAMESPACE"
    INTERVAL="${1:-2}"
    
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  Monitor K8s em Tempo Real                                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Namespace: $NAMESPACE"
    echo "Intervalo: ${INTERVAL}s"
    echo "Pressione Ctrl+C para parar"
    echo ""
    
    while true; do
        clear
        echo "════════════════════════════════════════════════════════════════"
        echo "  $(date '+%Y-%m-%d %H:%M:%S')"
        echo "════════════════════════════════════════════════════════════════"
        echo ""
        
        echo "📊 HORIZONTAL POD AUTOSCALERS"
        echo "────────────────────────────────────────────────────────────────"
        kubectl get hpa -n "$NAMESPACE" 2>/dev/null || echo "  Sem HPAs"
        echo ""
        
        echo "🚀 PODS"
        echo "────────────────────────────────────────────────────────────────"
        kubectl get pods -n "$NAMESPACE" -o wide 2>/dev/null || echo "  Sem pods"
        echo ""
        
        echo "💻 RECURSOS (CPU/Memory)"
        echo "────────────────────────────────────────────────────────────────"
        kubectl top pods -n "$NAMESPACE" 2>/dev/null || echo "  Métricas indisponíveis"
        echo ""
        
        echo "📈 EVENTOS RECENTES"
        echo "────────────────────────────────────────────────────────────────"
        kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' 2>/dev/null | tail -5 || echo "  Sem eventos"
        echo ""
        echo "════════════════════════════════════════════════════════════════"
        
        sleep "$INTERVAL"
    done
}

run_analyze() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  Gerando Análise e Gráficos                                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    if [ ! -f "$PROJECT_DIR/scripts/analyze_results.py" ]; then
        echo -e "${RED}❌ Script de análise não encontrado${NC}"
        exit 1
    fi
    
    python3 "$PROJECT_DIR/scripts/analyze_results.py"
    
    echo ""
    echo -e "${GREEN}✓ Análise concluída${NC}"
    echo ""
    echo "Resultados em: $RESULTS_DIR/plots/"
    ls -lh "$RESULTS_DIR/plots/" 2>/dev/null || true
}

# Main
COMMAND="${1:-all}"

case "$COMMAND" in
    all)
        run_all_tests
        ;;
    baseline|ramp|spike|soak|stress)
        check_service
        run_test "$COMMAND"
        ;;
    monitor|mon)
        run_monitor "${2:-2}"
        ;;
    analyze|analysis)
        run_analyze
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
