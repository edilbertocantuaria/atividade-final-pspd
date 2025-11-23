#!/bin/bash
# Script para deploy completo no Kubernetes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
K8S_DIR="$PROJECT_DIR/k8s"

echo "=== Deploying to Kubernetes ==="

# Create namespace
echo "Creating namespace..."
kubectl apply -f "$K8S_DIR/namespace.yaml"

# Deploy services
echo "Deploying services..."
kubectl apply -f "$K8S_DIR/a.yaml"
kubectl apply -f "$K8S_DIR/b.yaml"
kubectl apply -f "$K8S_DIR/p.yaml"

# Deploy ingress
echo "Deploying ingress..."
kubectl apply -f "$K8S_DIR/ingress.yaml"

# Wait for deployments
echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=120s \
  deployment/a-deploy deployment/b-deploy deployment/p-deploy -n pspd

echo "=== Deployment complete ==="
kubectl get pods -n pspd
