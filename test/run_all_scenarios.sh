#!/bin/bash
# Executar todos os testes de todos os cenários

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$PROJECT_ROOT/test"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  EXECUÇÃO COMPLETA DE TODOS OS CENÁRIOS                        ║"
echo "║  5 Cenários × 4 Testes = 20 Execuções                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Array com os cenários
SCENARIOS=(1 2 3 4 5)
START_TIME=$(date +%s)

# Contador de sucessos e falhas
TOTAL_SCENARIOS=${#SCENARIOS[@]}
SUCCESS_COUNT=0
FAILED_SCENARIOS=()

# Executar cada cenário
for scenario in "${SCENARIOS[@]}"; do
    SCENARIO_DIR="$TEST_DIR/scenario_${scenario}"
    
    echo ""
    echo "╭────────────────────────────────────────────────────────────────╮"
    echo "│  CENÁRIO $scenario de $TOTAL_SCENARIOS"
    echo "╰────────────────────────────────────────────────────────────────╯"
    echo ""
    
    if [ -f "$SCENARIO_DIR/00_setup.sh" ] && [ -f "$SCENARIO_DIR/run_all.sh" ]; then
        SCENARIO_START=$(date +%s)
        
        # Executar setup do cenário uma vez
        echo "📋 Executando setup do cenário $scenario..."
        bash "$SCENARIO_DIR/00_setup.sh"
        SETUP_EXIT=$?
        
        if [ $SETUP_EXIT -ne 0 ]; then
            echo "❌ Setup do cenário $scenario falhou"
            FAILED_SCENARIOS+=($scenario)
        else
            # Executar run_all.sh do cenário (sem setup interno)
            bash "$SCENARIO_DIR/run_all.sh"
            EXIT_CODE=$?
            
            SCENARIO_END=$(date +%s)
            SCENARIO_DURATION=$((SCENARIO_END - SCENARIO_START))
            
            if [ $EXIT_CODE -eq 0 ]; then
                echo ""
                echo "✅ Cenário $scenario concluído com sucesso em ${SCENARIO_DURATION}s"
                ((SUCCESS_COUNT++))
            else
                echo ""
                echo "❌ Cenário $scenario falhou (exit code: $EXIT_CODE)"
                FAILED_SCENARIOS+=($scenario)
            fi
        fi
    else
        echo "⚠️  Arquivos necessários não encontrados em $SCENARIO_DIR"
        FAILED_SCENARIOS+=($scenario)
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
done

# Calcular tempo total
END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))
MINUTES=$((TOTAL_DURATION / 60))
SECONDS=$((TOTAL_DURATION % 60))

# Relatório final
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  RELATÓRIO FINAL                                               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Estatísticas:"
echo "   • Cenários executados: $TOTAL_SCENARIOS"
echo "   • Sucessos: $SUCCESS_COUNT"
echo "   • Falhas: $((TOTAL_SCENARIOS - SUCCESS_COUNT))"
echo "   • Tempo total: ${MINUTES}m ${SECONDS}s"
echo ""

if [ ${#FAILED_SCENARIOS[@]} -eq 0 ]; then
    echo "✅ TODOS OS CENÁRIOS CONCLUÍDOS COM SUCESSO!"
else
    echo "❌ Cenários que falharam: ${FAILED_SCENARIOS[*]}"
    echo ""
    echo "Para reexecutar um cenário específico:"
    for failed in "${FAILED_SCENARIOS[@]}"; do
        echo "   bash test/scenario_${failed}/run_all.sh"
    done
fi

echo ""
echo "📁 Resultados salvos em:"
for scenario in "${SCENARIOS[@]}"; do
    echo "   • test_results/scenario_${scenario}/"
done

echo ""
echo "📊 Para gerar gráficos de um cenário específico:"
echo "   ./scripts/generate_plots.sh <NÚMERO_DO_CENÁRIO>"
echo ""

# Exit com código apropriado
if [ ${#FAILED_SCENARIOS[@]} -eq 0 ]; then
    exit 0
else
    exit 1
fi
