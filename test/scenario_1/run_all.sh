#!/bin/bash
# Executar todos os testes do Scenario 1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$PROJECT_ROOT/test_results/scenario_1"

echo "🚀 SCENARIO 1: Baseline (1 replica + HPA 1-10)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Executar setup uma única vez antes dos testes
echo ""
echo "📋 Executando setup do cenário..."
bash "$SCRIPT_DIR/00_setup.sh" || { echo "❌ Setup falhou"; exit 1; }

# Array com os testes a executar
TESTS=("baseline" "ramp" "spike" "soak")

# Executar cada teste
for test in "${TESTS[@]}"; do
    echo ""
    echo "🧪 Executando teste: $test"
    bash "$SCRIPT_DIR/${test}.sh" || { echo "⚠️  Teste $test falhou"; }
done

echo ""
echo "📊 Gerando gráficos de análise..."
python3 "$PROJECT_ROOT/scripts/analyze_results.py" "$RESULTS_DIR"

echo ""
echo "✅ TODOS OS TESTES CONCLUÍDOS!"
echo "📁 Resultados em: $RESULTS_DIR"
ls -lh "$RESULTS_DIR"
