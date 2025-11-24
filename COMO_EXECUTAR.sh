#!/bin/bash

# Guia Rápido: Como Executar os Testes com Sucesso

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Guia Rápido - Executar Testes com Perfeição                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

echo "📋 Pré-requisito: Cluster deve estar rodando"
echo ""
echo "   kubectl get pods -n pspd"
echo "   (deve mostrar 3 pods em estado Running)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "🚀 OPÇÃO 1: Teste Individual"
echo ""
echo "   # Terminal 1: Port-forward com auto-restart"
echo "   ./scripts/deploy.sh port-forward"
echo ""
echo "   # Terminal 2: Executar teste específico"
echo "   BASE_URL=http://localhost:8080 ./scripts/run_all_tests.sh baseline"
echo "   BASE_URL=http://localhost:8080 ./scripts/run_all_tests.sh ramp"
echo "   BASE_URL=http://localhost:8080 ./scripts/run_all_tests.sh spike"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📊 OPÇÃO 2: Suite Completa (recomendado)"
echo ""
echo "   # Terminal 1: Port-forward estável"
echo "   ./scripts/deploy.sh port-forward"
echo ""
echo "   # Terminal 2: Monitor em tempo real"
echo "   ./scripts/run_all_tests.sh monitor"
echo ""
echo "   # Terminal 3: Executar todos os testes + análise"
echo "   BASE_URL=http://localhost:8080 ./scripts/run_all_tests.sh all"
echo "   ./scripts/run_all_tests.sh analyze"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "🔧 TROUBLESHOOTING"
echo ""
echo "   Port-forward morreu?"
echo "   → Use: ./scripts/deploy.sh port-forward (reinicia automaticamente)"
echo ""
echo "   Pods não estão prontos?"
echo "   → ./scripts/deploy.sh restart"
echo "   → kubectl get pods -n pspd"
echo ""
echo "   Rebuild completo?"
echo "   → ./scripts/deploy.sh clean"
echo "   → ./scripts/deploy.sh setup"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "✅ VERIFICAÇÃO RÁPIDA"
echo ""
echo "   Testando conectividade agora..."
echo ""

# Verificar se port-forward está ativo
if ! ss -tuln 2>/dev/null | grep -q ":8080 " && ! lsof -i :8080 &>/dev/null; then
    echo "   ⚠️  Port-forward não está ativo"
    echo ""
    echo "   Execute:"
    echo "   kubectl port-forward -n pspd svc/p-svc 8080:80 &"
    echo ""
    exit 1
fi

# Testar endpoint
if curl -s -f -m 5 http://localhost:8080/ > /dev/null 2>&1; then
    echo "   ✅ Gateway respondendo em http://localhost:8080/"
    echo ""
    
    # Contar métricas
    METRIC_COUNT=$(curl -s http://localhost:8080/metrics 2>/dev/null | grep -c "^http_" || echo "0")
    echo "   ✅ Métricas Prometheus: $METRIC_COUNT métricas HTTP expostas"
    echo ""
else
    echo "   ❌ Gateway não respondeu"
    echo ""
    echo "   Verifique:"
    echo "   1. Port-forward está ativo? ps aux | grep port-forward"
    echo "   2. Pods estão rodando? kubectl get pods -n pspd"
    echo ""
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🎯 Pronto para executar testes!"
echo ""
echo "   Sugestão rápida:"
echo "   ./scripts/deploy.sh port-forward &"
echo "   sleep 3"
echo "   BASE_URL=http://localhost:8080 ./scripts/run_all_tests.sh baseline"
echo ""
