#!/bin/bash
# Script para construir as imagens Docker dos microserviços

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Building Docker images ==="

# Build Service A
echo "Building Service A..."
docker build -t a-service:local "$PROJECT_DIR/services/a_py"

# Build Service B
echo "Building Service B..."
docker build -t b-service:local "$PROJECT_DIR/services/b_py"

# Build Gateway P
echo "Building Gateway P..."
docker build -t p-gateway:local "$PROJECT_DIR/gateway_p_node"

echo "=== Images built successfully ==="
docker images | grep -E "(a-service|b-service|p-gateway)"
