#!/bin/bash
# Teste: Baseline (Scenario 5)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$PROJECT_ROOT/test_results/scenario_5"

mkdir -p "$RESULTS_DIR/baseline"

echo "📊 Executando: Baseline Test (Scenario 5)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Métricas PRE
kubectl top pods -n pspd > "$RESULTS_DIR/baseline/pod-metrics-pre.txt" 2>&1 || true
kubectl get hpa -n pspd > "$RESULTS_DIR/baseline/hpa-status-pre.txt" 2>&1 || true
kubectl get pods -n pspd -o wide > "$RESULTS_DIR/baseline/pods-status-pre.txt" 2>&1 || true

# Executar teste
k6 run --log-output=none \
  --summary-trend-stats="min,avg,med,max,p(90),p(95),p(99)" \
  --out json="$RESULTS_DIR/baseline/metrics.json" \
  "$PROJECT_ROOT/load/baseline.js" | tee "$RESULTS_DIR/baseline/output.txt"

# Métricas POST
kubectl top pods -n pspd > "$RESULTS_DIR/baseline/pod-metrics-post.txt" 2>&1 || true
kubectl get hpa -n pspd > "$RESULTS_DIR/baseline/hpa-status-post.txt" 2>&1 || true
kubectl get pods -n pspd -o wide > "$RESULTS_DIR/baseline/pods-status-post.txt" 2>&1 || true

echo ""
echo "✅ Resultados salvos em: $RESULTS_DIR/baseline/"
