#!/bin/bash
# Teste: Ramp (Scenario 4)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$PROJECT_ROOT/test_results/scenario_4"

mkdir -p "$RESULTS_DIR/ramp"

echo "📊 Executando: Ramp Test (Scenario 4)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Métricas PRE
kubectl top pods -n pspd > "$RESULTS_DIR/ramp/pod-metrics-pre.txt" 2>&1 || true
kubectl get hpa -n pspd > "$RESULTS_DIR/ramp/hpa-status-pre.txt" 2>&1 || true
kubectl get pods -n pspd -o wide > "$RESULTS_DIR/ramp/pods-status-pre.txt" 2>&1 || true

# Executar teste
k6 run --log-output=none \
  --summary-trend-stats="min,avg,med,max,p(90),p(95),p(99)" \
  --out json="$RESULTS_DIR/ramp/metrics.json" \
  "$PROJECT_ROOT/load/ramp.js" | tee "$RESULTS_DIR/ramp/output.txt"

# Métricas POST
kubectl top pods -n pspd > "$RESULTS_DIR/ramp/pod-metrics-post.txt" 2>&1 || true
kubectl get hpa -n pspd > "$RESULTS_DIR/ramp/hpa-status-post.txt" 2>&1 || true
kubectl get pods -n pspd -o wide > "$RESULTS_DIR/ramp/pods-status-post.txt" 2>&1 || true

echo ""
echo "✅ Resultados salvos em: $RESULTS_DIR/ramp/"
