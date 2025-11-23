#!/bin/bash
# Script para executar todos os cenários de teste de observabilidade

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$PROJECT_DIR/results"
LOAD_DIR="$PROJECT_DIR/load"

# Get service URL
BASE_URL="${BASE_URL:-http://localhost:8080}"
K8S_NAMESPACE="${K8S_NAMESPACE:-pspd}"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Running Observability Test Scenarios                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Target: $BASE_URL"
echo "Namespace: $K8S_NAMESPACE"
echo "Results: $RESULTS_DIR"
echo ""

# Create results directories
mkdir -p "$RESULTS_DIR"/{baseline,ramp,spike,soak}

# Function to capture K8s metrics
capture_k8s_metrics() {
  local test_name=$1
  local suffix=${2:-}
  local result_dir="$RESULTS_DIR/$test_name"
  
  echo "  📊 Capturing K8s metrics..."
  kubectl top pods -n "$K8S_NAMESPACE" > "$result_dir/pod-metrics${suffix}.txt" 2>/dev/null || true
  kubectl get hpa -n "$K8S_NAMESPACE" > "$result_dir/hpa-status${suffix}.txt" 2>/dev/null || true
  kubectl get pods -n "$K8S_NAMESPACE" -o wide > "$result_dir/pods-status${suffix}.txt" 2>/dev/null || true
}

# Check if service is accessible
echo "🔍 Checking service availability..."
if ! curl -s -f "$BASE_URL/healthz" > /dev/null; then
  echo "❌ Error: Service not accessible at $BASE_URL"
  echo "   Make sure port-forward is running:"
  echo "   kubectl port-forward -n $K8S_NAMESPACE svc/p-svc 8080:80"
  exit 1
fi
echo "✅ Service is accessible"
echo ""

# Test 1: Baseline
echo "═══════════════════════════════════════════════════════════════"
echo ">>> Test 1: BASELINE (10 VUs, 2min)"
echo "═══════════════════════════════════════════════════════════════"
capture_k8s_metrics "baseline" "-pre"

k6 run --out json="$RESULTS_DIR/baseline/metrics.json" \
  -e BASE_URL="$BASE_URL" \
  "$LOAD_DIR/baseline.js" | tee "$RESULTS_DIR/baseline/output.txt"

capture_k8s_metrics "baseline" "-post"
echo "✅ Baseline test completed"
echo "⏳ Waiting 30s for cluster to stabilize..."
sleep 30
echo ""

# Test 2: Ramp
echo "═══════════════════════════════════════════════════════════════"
echo ">>> Test 2: RAMP (10→150 VUs gradual increase)"
echo "═══════════════════════════════════════════════════════════════"
echo "💡 TIP: Open another terminal and run:"
echo "   watch -n 2 'kubectl get hpa -n $K8S_NAMESPACE'"
echo "   to observe autoscaling in real-time"
echo ""
sleep 3

capture_k8s_metrics "ramp" "-pre"

k6 run --out json="$RESULTS_DIR/ramp/metrics.json" \
  -e BASE_URL="$BASE_URL" \
  "$LOAD_DIR/ramp.js" | tee "$RESULTS_DIR/ramp/output.txt"

capture_k8s_metrics "ramp" "-post"
echo "✅ Ramp test completed"
echo "⏳ Waiting 60s for scale-down..."
sleep 60
echo ""

# Test 3: Spike
echo "═══════════════════════════════════════════════════════════════"
echo ">>> Test 3: SPIKE (10→200 VUs sudden burst)"
echo "═══════════════════════════════════════════════════════════════"
capture_k8s_metrics "spike" "-pre"

k6 run --out json="$RESULTS_DIR/spike/metrics.json" \
  -e BASE_URL="$BASE_URL" \
  "$LOAD_DIR/spike.js" | tee "$RESULTS_DIR/spike/output.txt"

capture_k8s_metrics "spike" "-post"
kubectl get events -n "$K8S_NAMESPACE" --sort-by='.lastTimestamp' | tail -30 \
  > "$RESULTS_DIR/spike/events.txt"
echo "✅ Spike test completed"
echo "⏳ Waiting 30s..."
sleep 30
echo ""

# Test 4: Soak (optional - takes 11+ minutes)
read -p "Run soak test (11+ minutes)? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "═══════════════════════════════════════════════════════════════"
  echo ">>> Test 4: SOAK (50 VUs, 10min sustained load)"
  echo "═══════════════════════════════════════════════════════════════"
  capture_k8s_metrics "soak" "-pre"
  
  k6 run --out json="$RESULTS_DIR/soak/metrics.json" \
    -e BASE_URL="$BASE_URL" \
    "$LOAD_DIR/soak.js" | tee "$RESULTS_DIR/soak/output.txt"
  
  capture_k8s_metrics "soak" "-post"
  echo "✅ Soak test completed"
else
  echo "⏭️  Skipping soak test"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ">>> Collecting Final Metrics"
echo "═══════════════════════════════════════════════════════════════"

# Capture final state
kubectl get hpa -n "$K8S_NAMESPACE" -o yaml > "$RESULTS_DIR/hpa-final.yaml" 2>/dev/null || true
kubectl top pods -n "$K8S_NAMESPACE" > "$RESULTS_DIR/pods-final.txt" 2>/dev/null || true
kubectl describe hpa -n "$K8S_NAMESPACE" > "$RESULTS_DIR/hpa-describe.txt" 2>/dev/null || true
kubectl get events -n "$K8S_NAMESPACE" --sort-by='.lastTimestamp' > "$RESULTS_DIR/events-history.txt" 2>/dev/null || true

# Capture application metrics
curl -s "$BASE_URL/metrics" > "$RESULTS_DIR/prometheus-metrics.txt" 2>/dev/null || true

# Capture logs
echo "📝 Capturing logs..."
kubectl logs -n "$K8S_NAMESPACE" -l app=p --tail=1000 > "$RESULTS_DIR/gateway-logs.txt" 2>/dev/null || true
kubectl logs -n "$K8S_NAMESPACE" -l app=a --tail=500 > "$RESULTS_DIR/service-a-logs.txt" 2>/dev/null || true
kubectl logs -n "$K8S_NAMESPACE" -l app=b --tail=500 > "$RESULTS_DIR/service-b-logs.txt" 2>/dev/null || true

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  All tests completed successfully! ✅                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Results saved to: $RESULTS_DIR"
echo ""
echo "📊 Summary:"
ls -lh "$RESULTS_DIR"/ | grep -E "^d|\.txt$|\.json$" | tail -20
echo ""
echo "🔍 Quick comparison:"
echo "─────────────────────────────────────────────────────────────"
grep "http_req_duration.*avg" "$RESULTS_DIR"/*/output.txt 2>/dev/null || true
echo "─────────────────────────────────────────────────────────────"
grep "http_reqs\.*:" "$RESULTS_DIR"/*/output.txt 2>/dev/null || true
echo "─────────────────────────────────────────────────────────────"
echo ""
echo "💡 Next steps:"
echo "  - Review results in: $RESULTS_DIR"
echo "  - Check HPA behavior: cat $RESULTS_DIR/hpa-describe.txt"
echo "  - Analyze events: cat $RESULTS_DIR/events-history.txt"
echo "  - See full guide: cat GUIA_EXECUCAO_TESTES.md"
echo ""
