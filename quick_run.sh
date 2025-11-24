#!/bin/bash

# Script de Execução Rápida
# Execute: ./quick_run.sh

set -e  # Sair em caso de erro

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Execução Completa - Projeto PSPD K8s Observabilidade       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funções auxiliares
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}✗ $1 não encontrado${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ $1 disponível${NC}"
}

# Passo 1: Verificar pré-requisitos
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 1. Verificando pré-requisitos..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_command minikube
check_command kubectl
check_command docker
check_command k6
check_command python3
echo ""

# Passo 2: Verificar cluster
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 2. Verificando cluster Kubernetes..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if ! minikube status &> /dev/null; then
    echo -e "${YELLOW}⚠ Minikube não está rodando. Iniciando...${NC}"
    minikube start --cpus=4 --memory=8192 --driver=docker
    minikube addons enable ingress
    minikube addons enable metrics-server
    echo -e "${GREEN}✓ Minikube iniciado${NC}"
else
    echo -e "${GREEN}✓ Minikube já está rodando${NC}"
fi
echo ""

# Passo 3: Verificar deployment
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 3. Verificando deployment..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if ! kubectl get namespace pspd &> /dev/null; then
    echo -e "${YELLOW}⚠ Namespace pspd não existe. Executando deploy...${NC}"
    ./scripts/build_images.sh
    ./scripts/deploy.sh
    echo "⏳ Aguardando pods ficarem prontos..."
    kubectl wait --for=condition=ready pod --all -n pspd --timeout=180s
    echo -e "${GREEN}✓ Deploy concluído${NC}"
else
    PODS_READY=$(kubectl get pods -n pspd --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    if [ "$PODS_READY" -eq 3 ]; then
        echo -e "${GREEN}✓ Todos os pods estão rodando ($PODS_READY/3)${NC}"
    else
        echo -e "${YELLOW}⚠ Pods não estão todos prontos. Recriando deployment...${NC}"
        kubectl delete namespace pspd --ignore-not-found=true
        sleep 5
        ./scripts/build_images.sh
        ./scripts/deploy.sh
        kubectl wait --for=condition=ready pod --all -n pspd --timeout=180s
        echo -e "${GREEN}✓ Deploy concluído${NC}"
    fi
fi
echo ""

# Passo 4: Verificar conectividade
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔗 4. Testando conectividade..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Matar port-forwards antigos
pkill -f "kubectl port-forward" 2>/dev/null || true
sleep 2

# Iniciar port-forward
echo "⏳ Iniciando port-forward..."
kubectl port-forward -n pspd svc/p-svc 8080:80 > /tmp/pf_quick.log 2>&1 &
PF_PID=$!
sleep 5

# Testar endpoint
echo "🧪 Testando endpoint HTTP..."
if curl -s -f http://localhost:8080/ > /dev/null; then
    echo -e "${GREEN}✓ Endpoint HTTP respondendo${NC}"
else
    echo -e "${RED}✗ Endpoint HTTP não respondeu${NC}"
    kill $PF_PID 2>/dev/null
    exit 1
fi

echo "🧪 Testando métricas Prometheus..."
METRIC_COUNT=$(curl -s http://localhost:8080/metrics | grep -c "^http_" || echo "0")
if [ "$METRIC_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Métricas Prometheus expostas ($METRIC_COUNT métricas HTTP)${NC}"
else
    echo -e "${RED}✗ Métricas não encontradas${NC}"
    kill $PF_PID 2>/dev/null
    exit 1
fi
echo ""

# Passo 5: Executar testes
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 5. Executando testes de carga..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Os testes levarão aproximadamente 20 minutos:"
echo "  • Baseline: 2 min"
echo "  • Ramp: 4 min"
echo "  • Spike: 2 min"
echo "  • Soak: 11 min"
echo ""
read -p "Deseja continuar com os testes? (s/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[SsYy]$ ]]; then
    echo "🚀 Iniciando suite de testes..."
    echo ""
    echo -e "${YELLOW}💡 Dica: Abra outro terminal e execute './scripts/monitor.sh' para acompanhar em tempo real${NC}"
    echo ""
    sleep 3
    
    BASE_URL=http://localhost:8080 ./scripts/run_all_tests.sh
    
    echo ""
    echo -e "${GREEN}✓ Testes concluídos${NC}"
else
    echo "⏭️  Pulando testes de carga"
fi
echo ""

# Passo 6: Gerar análise
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📈 6. Gerando análise e gráficos..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "results/baseline/output.txt" ]; then
    python3 scripts/analyze_results.py
    echo ""
    echo -e "${GREEN}✓ Análise gerada${NC}"
    echo ""
    echo "📂 Resultados disponíveis em:"
    echo "   • results/plots/*.png (6 gráficos)"
    echo "   • results/plots/SUMMARY_REPORT.txt"
else
    echo -e "${YELLOW}⚠ Nenhum resultado de teste encontrado. Pulando análise.${NC}"
fi
echo ""

# Passo 7: Resumo final
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ EXECUÇÃO CONCLUÍDA"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Status do Sistema:"
kubectl get pods -n pspd
echo ""
kubectl get hpa -n pspd
echo ""
echo "🔗 Port-forward ativo em: http://localhost:8080"
echo "   PID: $PF_PID"
echo ""
echo "🛑 Para parar o port-forward: kill $PF_PID"
echo "🛑 Para parar o cluster: minikube stop"
echo ""
echo "📖 Documentação disponível em:"
echo "   • README.md - Visão geral do projeto"
echo "   • EXECUCAO_COMPLETA.md - Guia passo a passo detalhado"
echo "   • GUIA_EXECUCAO_TESTES.md - Detalhes dos testes"
echo ""

if [ -f "results/plots/SUMMARY_REPORT.txt" ]; then
    echo "📈 Resumo dos Resultados:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    head -30 results/plots/SUMMARY_REPORT.txt
    echo ""
    echo "   (Ver relatório completo em: results/plots/SUMMARY_REPORT.txt)"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🎉 Tudo pronto! Aplicação rodando perfeitamente!           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
