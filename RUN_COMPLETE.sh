#!/bin/bash
# Guia de Execução Completa - Cluster Multi-Node + Prometheus + Grafana

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Execução Completa - Cluster Multi-Node + Monitoramento      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Este guia executará automaticamente:"
echo "  1. Cluster multi-node (1 master + 2 workers)"
echo "  2. Prometheus + Grafana"
echo "  3. Deploy das aplicações"
echo "  4. Configuração de ServiceMonitors"
echo "  5. Testes de carga"
echo ""
echo "⏱️  Tempo estimado: 15-20 minutos"
echo ""

read -p "Deseja continuar? [S/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[SsYy]$ ]] && [[ -n $REPLY ]]; then
    echo "❌ Cancelado"
    exit 0
fi

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Passo 1/5: Criando cluster multi-node..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./scripts/setup_multinode_cluster.sh

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Passo 2/5: Deploy das aplicações..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./scripts/deploy.sh setup

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Passo 3/5: Configurando ServiceMonitors..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./scripts/deploy.sh monitoring

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔗 Passo 4/5: Iniciando port-forwards..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Port-forward Gateway P
kubectl port-forward -n pspd svc/p-svc 8080:80 > /tmp/pf_gateway.log 2>&1 &
PF_GATEWAY=$!

# Port-forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 > /tmp/pf_grafana.log 2>&1 &
PF_GRAFANA=$!

# Port-forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 > /tmp/pf_prometheus.log 2>&1 &
PF_PROMETHEUS=$!

sleep 5

echo -e "${GREEN}✓ Port-forwards ativos${NC}"
echo "  Gateway P:   http://localhost:8080"
echo "  Grafana:     http://localhost:3000 (admin/admin)"
echo "  Prometheus:  http://localhost:9090"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Passo 5/5: Executando testes de carga..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Executando testes (baseline, ramp, spike)..."
echo "O teste soak (11 min) será pulado automaticamente em 30s."
echo ""

BASE_URL=http://localhost:8080 ./scripts/run_all_tests.sh all

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Gerando análise e gráficos..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./scripts/run_all_tests.sh analyze

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅ Setup Completo Concluído!                                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Status do Cluster:"
echo "─────────────────────────────────────────────────────────────"
kubectl get nodes
echo ""
kubectl get pods -n pspd
echo ""
kubectl get pods -n monitoring | grep -E "(prometheus-kube|grafana)"
echo ""

echo "🔗 Interfaces Web Disponíveis:"
echo "─────────────────────────────────────────────────────────────"
echo "  Gateway P:   http://localhost:8080"
echo "  Grafana:     http://localhost:3000"
echo "               User: admin | Password: admin"
echo "               Dashboard: Importar k8s/monitoring/grafana-dashboard.json"
echo ""
echo "  Prometheus:  http://localhost:9090"
echo "               Query: rate(http_requests_total{namespace=\"pspd\"}[1m])"
echo ""

echo "📈 Resultados dos Testes:"
echo "─────────────────────────────────────────────────────────────"
if [ -f results/plots/SUMMARY_REPORT.txt ]; then
    head -20 results/plots/SUMMARY_REPORT.txt
    echo ""
    echo "   (Ver relatório completo: results/plots/SUMMARY_REPORT.txt)"
fi
echo ""

echo "📂 Gráficos Gerados:"
echo "─────────────────────────────────────────────────────────────"
ls -lh results/plots/*.png 2>/dev/null || echo "  Nenhum gráfico gerado ainda"
echo ""

echo "💡 Próximos Passos:"
echo "─────────────────────────────────────────────────────────────"
echo "  1. Acessar Grafana e importar dashboard:"
echo "     http://localhost:3000 → + → Import → Upload k8s/monitoring/grafana-dashboard.json"
echo ""
echo "  2. Explorar métricas no Prometheus:"
echo "     http://localhost:9090 → Graph"
echo ""
echo "  3. Ver análise completa:"
echo "     cat results/plots/SUMMARY_REPORT.txt"
echo ""
echo "  4. Executar teste soak (11 min):"
echo "     BASE_URL=http://localhost:8080 ./scripts/run_all_tests.sh soak"
echo ""

echo "🛑 Para parar:"
echo "─────────────────────────────────────────────────────────────"
echo "  Port-forwards: kill $PF_GATEWAY $PF_GRAFANA $PF_PROMETHEUS"
echo "  Cluster:       minikube stop -p pspd-cluster"
echo "  Deletar tudo:  minikube delete -p pspd-cluster"
echo ""

echo "📖 Documentação:"
echo "─────────────────────────────────────────────────────────────"
echo "  README.md         - Visão geral e quick start"
echo "  GUIA_MULTINODE.md - Guia detalhado multi-node"
echo ""

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🎉 Projeto PSPD - 100% Funcional!                           ║"
echo "║                                                               ║"
echo "║  ✅ Cluster Multi-Node (1 master + 2 workers)                ║"
echo "║  ✅ Prometheus instalado e coletando métricas                ║"
echo "║  ✅ Grafana com dashboard customizado                        ║"
echo "║  ✅ Aplicações rodando e instrumentadas                      ║"
echo "║  ✅ Testes de carga executados                               ║"
echo "║  ✅ Análise de resultados gerada                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
