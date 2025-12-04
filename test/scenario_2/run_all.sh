#!/bin/bash
# Executar todos os testes do Scenario 1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$PROJECT_ROOT/test_results/scenario_2"

echo "🚀 SCENARIO 2: Warm Start (2 replicas + HPA 2-10)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Array com os testes a executar
TESTS=("baseline" "ramp" "spike" "soak")

# Executar cada teste com setup antes
for test in "${TESTS[@]}"; do
    echo ""
    echo "📋 Executando setup para teste: $test"
    bash "$SCRIPT_DIR/00_setup.sh" || { echo "❌ Setup falhou para $test"; exit 1; }
    
    echo ""
    echo "🧪 Executando teste: $test"
    bash "$SCRIPT_DIR/${test}.sh" || { echo "⚠️  Teste $test falhou"; }
done
\necho ""
echo "📊 Gerando gráficos de análise..."
python3 "$PROJECT_ROOT/scripts/analyze_results.py" "$RESULTS_DIR"

echo ""
echo "✅ TODOS OS TESTES CONCLUÍDOS!"
echo "📁 Resultados em: $RESULTS_DIR"
ls -lh "$RESULTS_DIR"
