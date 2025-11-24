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

echo "🚀 OPÇÃO 1: Testes Rápidos (baseline, ramp, spike)"
echo ""
echo "   # Terminal 1:"
echo "   kubectl port-forward -n pspd svc/p-svc 8080:80"
echo ""
echo "   # Terminal 2:"
echo "   BASE_URL=http://localhost:8080 k6 run load/baseline.js"
echo "   BASE_URL=http://localhost:8080 k6 run load/ramp.js"
echo "   BASE_URL=http://localhost:8080 k6 run load/spike.js"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "⏱️  OPÇÃO 2: Teste Longo (soak - 11 minutos)"
echo ""
echo "   PROBLEMA: Port-forward pode cair durante teste longo"
echo "   SOLUÇÃO: Use o script com auto-recuperação"
echo ""
echo "   # Terminal 1:"
echo "   ./scripts/stable_port_forward.sh"
echo ""
echo "   # Terminal 2:"
echo "   BASE_URL=http://localhost:8080 k6 run load/soak.js"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📊 OPÇÃO 3: Suite Completa com Análise"
echo ""
echo "   # Terminal 1:"
echo "   ./scripts/stable_port_forward.sh"
echo ""
echo "   # Terminal 2:"
echo "   ./scripts/monitor.sh"
echo ""
echo "   # Terminal 3:"
echo "   BASE_URL=http://localhost:8080 ./scripts/run_all_tests.sh"
echo "   python3 scripts/analyze_results.py"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "🔧 TROUBLESHOOTING"
echo ""
echo "   Port-forward morreu?"
echo "   → pkill -f 'port-forward' && kubectl port-forward -n pspd svc/p-svc 8080:80 &"
echo ""
echo "   Teste falhou com connection reset?"
echo "   → Use ./scripts/stable_port_forward.sh (auto-reinicia)"
echo ""
echo "   Pods não estão prontos?"
echo "   → kubectl get pods -n pspd"
echo "   → kubectl logs -n pspd <pod-name>"
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
echo "   Sugestão: Execute o baseline primeiro para validar"
echo "   BASE_URL=http://localhost:8080 k6 run load/baseline.js"
echo ""
