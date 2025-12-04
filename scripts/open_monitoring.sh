#!/bin/bash
# Script para abrir Grafana e Prometheus em segundo plano

set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Abrindo Grafana e Prometheus                                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Verificar se o namespace existe
if ! kubectl get namespace monitoring > /dev/null 2>&1; then
    echo "❌ Namespace 'monitoring' não encontrado"
    echo "   Execute primeiro: helm install prometheus ..."
    exit 1
fi

# Verificar se os pods estão rodando
echo "🔍 Verificando pods..."
GRAFANA_POD=$(kubectl get pods -n monitoring -l "app.kubernetes.io/name=grafana" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
PROMETHEUS_POD=$(kubectl get pods -n monitoring -l "app.kubernetes.io/name=prometheus" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$GRAFANA_POD" ]; then
    echo "❌ Pod do Grafana não encontrado"
    echo "   Verifique: kubectl get pods -n monitoring"
    exit 1
fi

if [ -z "$PROMETHEUS_POD" ]; then
    echo "❌ Pod do Prometheus não encontrado"
    echo "   Verifique: kubectl get pods -n monitoring"
    exit 1
fi

echo "✅ Pods encontrados:"
echo "   Grafana: $GRAFANA_POD"
echo "   Prometheus: $PROMETHEUS_POD"
echo ""

# Matar port-forwards antigos
echo "🧹 Limpando port-forwards antigos..."
pkill -f "port-forward.*monitoring.*3000" 2>/dev/null || true
pkill -f "port-forward.*monitoring.*9090" 2>/dev/null || true
sleep 1

# Iniciar port-forwards em background
echo "🚀 Iniciando port-forwards..."
echo ""

kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 > /dev/null 2>&1 &
GRAFANA_PID=$!
sleep 2

kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 > /dev/null 2>&1 &
PROMETHEUS_PID=$!
sleep 2

# Verificar se estão rodando
if ps -p $GRAFANA_PID > /dev/null && ps -p $PROMETHEUS_PID > /dev/null; then
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ✅ Port-forwards iniciados com sucesso!                     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "🌐 Acesse:"
    echo ""
    echo "   📊 Grafana:    http://localhost:3000"
    echo "      Login: admin"
    echo "      Senha: admin (será pedido para trocar no primeiro login)"
    echo ""
    echo "   📈 Prometheus: http://localhost:9090"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "💡 Dicas:"
    echo "   • Port-forwards estão rodando em background (PIDs: $GRAFANA_PID, $PROMETHEUS_PID)"
    echo "   • Para parar: pkill -f 'port-forward.*monitoring'"
    echo "   • Ou feche este terminal"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "   • Se não carregar, aguarde 10-20 segundos"
    echo "   • Verifique: kubectl get pods -n monitoring"
    echo "   • Logs: kubectl logs -n monitoring $GRAFANA_POD"
    echo ""
    
    # Manter script rodando
    echo "⏳ Mantendo port-forwards ativos... (Ctrl+C para parar)"
    wait $GRAFANA_PID $PROMETHEUS_PID
else
    echo "❌ Falha ao iniciar port-forwards"
    echo "   Verifique: kubectl get svc -n monitoring"
    exit 1
fi
