#!/bin/bash
# Script para executar análise comparativa de todos os cenários

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
K8S_DIR="$PROJECT_DIR/k8s"
SCENARIOS_DIR="$K8S_DIR/scenarios"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Análise Comparativa de Cenários K8s                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Verificar se minikube está rodando
if ! minikube status &>/dev/null; then
    echo -e "${RED}❌ Minikube não está rodando${NC}"
    echo "Execute: minikube start --nodes 3 --cpus 4 --memory 8192"
    exit 1
fi

echo -e "${GREEN}✓ Minikube ativo${NC}"
echo ""

# Array de cenários
SCENARIOS=(
    "1:base:k8s"
    "2:replicas:scenarios/scenario2-replicas"
    "3:distribution:scenarios/scenario3-distribution"
    "4:resources:scenarios/scenario4-resources"
    "5:no-hpa:scenarios/scenario5-no-hpa"
)

# Função para limpar namespace
cleanup_namespace() {
    echo -e "${YELLOW}🧹 Limpando namespace pspd...${NC}"
    kubectl delete namespace pspd --ignore-not-found=true
    sleep 5
    kubectl create namespace pspd
    sleep 2
}

# Função para aplicar cenário
apply_scenario() {
    local scenario_num=$1
    local scenario_name=$2
    local scenario_path=$3
    
    echo -e "${BLUE}📋 Aplicando Cenário $scenario_num: $scenario_name${NC}"
    
    kubectl apply -f "$K8S_DIR/namespace.yaml"
    
    if [ "$scenario_path" == "k8s" ]; then
        # Cenário base (arquivos na raiz do k8s/)
        kubectl apply -f "$K8S_DIR/a.yaml"
        kubectl apply -f "$K8S_DIR/b.yaml"
        kubectl apply -f "$K8S_DIR/p.yaml"
    else
        # Outros cenários (em subpastas)
        kubectl apply -f "$K8S_DIR/$scenario_path/"
    fi
    
    echo "⏳ Aguardando pods ficarem prontos..."
    kubectl wait --for=condition=ready pod --all -n pspd --timeout=120s || {
        echo -e "${RED}❌ Pods não ficaram prontos a tempo${NC}"
        kubectl get pods -n pspd
        return 1
    }
    
    echo -e "${GREEN}✓ Pods prontos${NC}"
    kubectl get pods -n pspd -o wide
    
    # Verificar HPA (se existir)
    if kubectl get hpa -n pspd &>/dev/null; then
        echo ""
        echo "📊 HPA Status:"
        kubectl get hpa -n pspd
    else
        echo ""
        echo "⚠️  HPA não configurado (cenário sem autoscaling)"
    fi
    
    echo ""
}

# Função para executar testes
run_tests() {
    local scenario_num=$1
    
    echo -e "${BLUE}🧪 Executando testes do Cenário $scenario_num...${NC}"
    echo ""
    
    # Port-forward do gateway
    echo "🔌 Iniciando port-forward..."
    kubectl port-forward -n pspd svc/p-svc 8080:80 > /dev/null 2>&1 &
    PF_PID=$!
    sleep 3
    
    # Verificar se port-forward funcionou
    if ! curl -s -f http://localhost:8080 > /dev/null 2>&1; then
        echo -e "${RED}❌ Port-forward falhou${NC}"
        kill $PF_PID 2>/dev/null || true
        return 1
    fi
    
    echo -e "${GREEN}✓ Port-forward ativo (PID: $PF_PID)${NC}"
    echo ""
    
    # Executar testes
    BASE_URL="http://localhost:8080" "$PROJECT_DIR/scripts/run_all_tests.sh" all
    
    # Parar port-forward
    kill $PF_PID 2>/dev/null || true
    echo ""
    echo -e "${GREEN}✓ Testes concluídos${NC}"
}

# Função para salvar resultados
save_results() {
    local scenario_num=$1
    local scenario_name=$2
    
    local results_dir="$PROJECT_DIR/results-scenario-$scenario_num-$scenario_name"
    
    echo -e "${BLUE}💾 Salvando resultados...${NC}"
    
    if [ -d "$PROJECT_DIR/results" ]; then
        mv "$PROJECT_DIR/results" "$results_dir"
        echo -e "${GREEN}✓ Resultados salvos em: $results_dir${NC}"
    else
        echo -e "${YELLOW}⚠️  Pasta results não encontrada${NC}"
    fi
    
    # Salvar configuração do cenário
    kubectl get deploy,svc,hpa -n pspd -o yaml > "$results_dir/k8s-config.yaml" 2>/dev/null || true
    kubectl get pods -n pspd -o wide > "$results_dir/pods-layout.txt" 2>/dev/null || true
    
    echo ""
}

# Menu interativo
show_menu() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  Selecione a operação:                                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "  1) Executar TODOS os cenários (automático)"
    echo "  2) Executar cenário específico"
    echo "  3) Apenas gerar análise comparativa"
    echo "  4) Sair"
    echo ""
    read -p "Opção: " option
    echo ""
    
    case $option in
        1)
            run_all_scenarios
            ;;
        2)
            run_specific_scenario
            ;;
        3)
            generate_comparison
            ;;
        4)
            echo "👋 Até logo!"
            exit 0
            ;;
        *)
            echo -e "${RED}Opção inválida${NC}"
            show_menu
            ;;
    esac
}

# Função para executar todos os cenários
run_all_scenarios() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  Executando TODOS os 5 cenários                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "⏱️  Tempo estimado: ~2-3 horas (30-35min por cenário)"
    echo ""
    read -p "Continuar? (s/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
        echo "Operação cancelada"
        return
    fi
    
    for scenario in "${SCENARIOS[@]}"; do
        IFS=':' read -r num name path <<< "$scenario"
        
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo "  CENÁRIO $num: ${name^^}"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        
        cleanup_namespace
        apply_scenario "$num" "$name" "$path"
        run_tests "$num"
        save_results "$num" "$name"
        
        echo ""
        echo -e "${GREEN}✅ Cenário $num concluído!${NC}"
        echo ""
        
        # Pausa entre cenários (exceto no último)
        if [ "$num" != "5" ]; then
            echo "⏸️  Aguardando 30s antes do próximo cenário..."
            sleep 30
        fi
    done
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ✅ Todos os cenários concluídos!                           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    generate_comparison
}

# Função para executar cenário específico
run_specific_scenario() {
    echo "Cenários disponíveis:"
    echo ""
    for scenario in "${SCENARIOS[@]}"; do
        IFS=':' read -r num name path <<< "$scenario"
        echo "  $num) Cenário $num: ${name}"
    done
    echo ""
    read -p "Selecione o cenário (1-5): " scenario_num
    
    # Encontrar cenário
    for scenario in "${SCENARIOS[@]}"; do
        IFS=':' read -r num name path <<< "$scenario"
        if [ "$num" == "$scenario_num" ]; then
            echo ""
            cleanup_namespace
            apply_scenario "$num" "$name" "$path"
            run_tests "$num"
            save_results "$num" "$name"
            echo ""
            echo -e "${GREEN}✅ Cenário $num concluído!${NC}"
            return
        fi
    done
    
    echo -e "${RED}Cenário inválido${NC}"
}

# Função para gerar análise comparativa
generate_comparison() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  📊 Gerando Análise Comparativa                             ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Verificar se existem resultados
    RESULT_DIRS=($(ls -d "$PROJECT_DIR"/results-scenario-* 2>/dev/null || true))
    
    if [ ${#RESULT_DIRS[@]} -eq 0 ]; then
        echo -e "${RED}❌ Nenhum resultado encontrado${NC}"
        echo "Execute os cenários primeiro"
        return 1
    fi
    
    echo "Resultados encontrados:"
    for dir in "${RESULT_DIRS[@]}"; do
        echo "  - $(basename "$dir")"
    done
    echo ""
    
    # Criar análise comparativa
    COMPARISON_DIR="$PROJECT_DIR/scenario-comparison"
    mkdir -p "$COMPARISON_DIR"
    
    echo "📝 Gerando relatório comparativo..."
    
    # Extrair métricas de cada cenário
    cat > "$COMPARISON_DIR/comparison-summary.md" << 'EOF'
# Análise Comparativa de Cenários

## Sumário Executivo

Este relatório compara os 5 cenários de teste executados.

## Resultados por Cenário

EOF
    
    for dir in "${RESULT_DIRS[@]}"; do
        scenario_name=$(basename "$dir")
        echo "### $scenario_name" >> "$COMPARISON_DIR/comparison-summary.md"
        echo "" >> "$COMPARISON_DIR/comparison-summary.md"
        
        # Extrair métricas do SUMMARY_REPORT.txt se existir
        if [ -f "$dir/plots/SUMMARY_REPORT.txt" ]; then
            echo "\`\`\`" >> "$COMPARISON_DIR/comparison-summary.md"
            head -50 "$dir/plots/SUMMARY_REPORT.txt" >> "$COMPARISON_DIR/comparison-summary.md"
            echo "\`\`\`" >> "$COMPARISON_DIR/comparison-summary.md"
        fi
        
        echo "" >> "$COMPARISON_DIR/comparison-summary.md"
    done
    
    echo -e "${GREEN}✓ Relatório gerado: $COMPARISON_DIR/comparison-summary.md${NC}"
    echo ""
    echo "📊 Análise disponível em: $COMPARISON_DIR/"
}

# Main
if [ "$1" == "--all" ]; then
    run_all_scenarios
elif [ "$1" == "--compare" ]; then
    generate_comparison
else
    show_menu
fi
