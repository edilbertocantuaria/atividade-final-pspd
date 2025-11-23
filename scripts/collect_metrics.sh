#!/bin/bash
# Script para coletar métricas do Prometheus durante testes

set -e

PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
OUTPUT_DIR="${1:-./metrics}"
DURATION="${2:-60}"

echo "=== Collecting Prometheus Metrics ==="
echo "Prometheus: $PROMETHEUS_URL"
echo "Output: $OUTPUT_DIR"
echo "Duration: ${DURATION}s"

mkdir -p "$OUTPUT_DIR"

# Queries to collect
declare -A QUERIES=(
  ["http_requests_total"]='rate(http_requests_total[1m])'
  ["http_req_duration_p95"]='histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[1m]))'
  ["http_req_duration_p99"]='histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[1m]))'
  ["grpc_requests_total"]='rate(grpc_client_requests_total[1m])'
  ["grpc_req_duration_p95"]='histogram_quantile(0.95, rate(grpc_client_request_duration_seconds_bucket[1m]))'
  ["cpu_usage"]='rate(container_cpu_usage_seconds_total{namespace="pspd"}[1m])'
  ["memory_usage"]='container_memory_working_set_bytes{namespace="pspd"}'
  ["pod_restarts"]='kube_pod_container_status_restarts_total{namespace="pspd"}'
)

START_TIME=$(date +%s)
END_TIME=$((START_TIME + DURATION))

echo "Collecting metrics for ${DURATION}s..."
for name in "${!QUERIES[@]}"; do
  query="${QUERIES[$name]}"
  echo "  - $name"
  
  curl -s -G "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=$query" \
    --data-urlencode "time=$END_TIME" \
    > "$OUTPUT_DIR/${name}.json"
done

echo "=== Metrics collected ==="
ls -lh "$OUTPUT_DIR"
