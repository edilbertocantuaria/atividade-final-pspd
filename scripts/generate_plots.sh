#!/bin/bash
# Script para gerar gráficos de análise dos testes executados

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ $# -eq 0 ]; then
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  Gerador de Gráficos - Análise de Testes                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Uso:"
    echo "  $0 <scenario_number>       # Gerar para um cenário específico"
    echo "  $0 all                     # Gerar para todos os cenários"
    echo ""
    echo "Exemplos:"
    echo "  $0 1                       # Gerar gráficos do scenario_1"
    echo "  $0 3                       # Gerar gráficos do scenario_3"
    echo "  $0 all                     # Gerar para todos os cenários"
    echo ""
    exit 1
fi

generate_for_scenario() {
    local scenario_num=$1
    local scenario_dir="$PROJECT_ROOT/test_results/scenario_$scenario_num"
    
    if [ ! -d "$scenario_dir" ]; then
        echo "❌ Diretório não encontrado: $scenario_dir"
        echo "   Execute os testes primeiro: ./test/scenario_$scenario_num/run_all.sh"
        return 1
    fi
    
    # Verificar se há resultados
    if [ -z "$(ls -A "$scenario_dir" 2>/dev/null)" ]; then
        echo "❌ Sem resultados em: $scenario_dir"
        return 1
    fi
    
    echo "📊 Gerando gráficos para Scenario $scenario_num..."
    python3 "$SCRIPT_DIR/analyze_results.py" "$scenario_dir"
    
    if [ $? -eq 0 ]; then
        echo "✅ Gráficos gerados em: $scenario_dir/plots/"
        echo ""
    else
        echo "❌ Erro ao gerar gráficos do Scenario $scenario_num"
        return 1
    fi
}

if [ "$1" = "all" ]; then
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  Gerando gráficos para TODOS os cenários                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    for scenario in {1..5}; do
        generate_for_scenario $scenario
    done
    
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ✅ Geração completa!                                        ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
else
    scenario_num=$1
    
    if ! [[ "$scenario_num" =~ ^[1-5]$ ]]; then
        echo "❌ Cenário inválido: $scenario_num"
        echo "   Use um número de 1 a 5, ou 'all'"
        exit 1
    fi
    
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  Gerando gráficos - Scenario $scenario_num                          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    generate_for_scenario $scenario_num
fi
