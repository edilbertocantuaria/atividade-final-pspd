#!/bin/bash
# Executar todos os testes do Scenario 1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$PROJECT_ROOT/test_results/scenario_5"

echo "🚀 SCENARIO 5: No HPA (5 fixed replicas, no autoscaling)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Setup
bash "$SCRIPT_DIR/00_setup.sh" || { echo "❌ Setup falhou"; exit 1; }

# Testes
bash "$SCRIPT_DIR/baseline.sh"
bash "$SCRIPT_DIR/ramp.sh"
bash "$SCRIPT_DIR/spike.sh"
bash "$SCRIPT_DIR/soak.sh"
\necho ""
echo "📊 Gerando gráficos de análise..."
python3 "$PROJECT_ROOT/scripts/analyze_results.py" "$RESULTS_DIR"

echo ""
echo "✅ TODOS OS TESTES CONCLUÍDOS!"
echo "📁 Resultados em: $RESULTS_DIR"
ls -lh "$RESULTS_DIR"
