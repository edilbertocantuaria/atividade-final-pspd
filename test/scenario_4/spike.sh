#!/bin/bash
# Teste: Spike (Scenario 4)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$PROJECT_ROOT/test_results/scenario_4"

mkdir -p "$RESULTS_DIR/spike"

echo "📊 Executando: Spike Test (Scenario 4)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Métricas PRE
kubectl top pods -n pspd > "$RESULTS_DIR/spike/pod-metrics-pre.txt" 2>&1 || true
kubectl get hpa -n pspd > "$RESULTS_DIR/spike/hpa-status-pre.txt" 2>&1 || true
kubectl get pods -n pspd -o wide > "$RESULTS_DIR/spike/pods-status-pre.txt" 2>&1 || true

# Executar teste
k6 run --log-output=none \
  --summary-trend-stats="min,avg,med,max,p(90),p(95),p(99)" \
  --out json="$RESULTS_DIR/spike/metrics.json" \
  "$PROJECT_ROOT/load/spike.js" | tee "$RESULTS_DIR/spike/output.txt"

# Métricas POST
kubectl top pods -n pspd > "$RESULTS_DIR/spike/pod-metrics-post.txt" 2>&1 || true
kubectl get hpa -n pspd > "$RESULTS_DIR/spike/hpa-status-post.txt" 2>&1 || true
kubectl get pods -n pspd -o wide > "$RESULTS_DIR/spike/pods-status-post.txt" 2>&1 || true

echo ""
echo "✅ Resultados salvos em: $RESULTS_DIR/spike/"
