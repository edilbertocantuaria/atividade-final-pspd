#!/bin/bash
# Teste: Soak (Scenario 1)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$PROJECT_ROOT/test_results/scenario_1"

mkdir -p "$RESULTS_DIR/soak"

echo "📊 Executando: Soak Test (Scenario 1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Métricas PRE
kubectl top pods -n pspd > "$RESULTS_DIR/soak/pod-metrics-pre.txt" 2>&1 || true
kubectl get hpa -n pspd > "$RESULTS_DIR/soak/hpa-status-pre.txt" 2>&1 || true
kubectl get pods -n pspd -o wide > "$RESULTS_DIR/soak/pods-status-pre.txt" 2>&1 || true

# Executar teste
k6 run --log-output=none \
  --summary-trend-stats="min,avg,med,max,p(90),p(95),p(99)" \
  --out json="$RESULTS_DIR/soak/metrics.json" \
  "$PROJECT_ROOT/load/soak.js" | tee "$RESULTS_DIR/soak/output.txt"

# Métricas POST
kubectl top pods -n pspd > "$RESULTS_DIR/soak/pod-metrics-post.txt" 2>&1 || true
kubectl get hpa -n pspd > "$RESULTS_DIR/soak/hpa-status-post.txt" 2>&1 || true
kubectl get pods -n pspd -o wide > "$RESULTS_DIR/soak/pods-status-post.txt" 2>&1 || true

echo ""
echo "✅ Resultados salvos em: $RESULTS_DIR/soak/"
