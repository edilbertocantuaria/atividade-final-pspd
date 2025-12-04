#!/bin/bash

# Script helper para expor backend e configurar integração com frontend
# Uso: ./scripts/expose_backend.sh [ngrok|local]

set -e

MODE="${1:-ngrok}"

echo "🚀 Configurando integração Frontend + Backend + Métricas"
echo ""

# Verificar se cluster está rodando
echo "📋 Verificando cluster..."
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cluster Kubernetes não está acessível"
    echo "   Execute: minikube start"
    exit 1
fi

# Verificar se namespace pspd existe
if ! kubectl get namespace pspd &> /dev/null; then
    echo "❌ Namespace 'pspd' não existe"
    echo "   Execute: kubectl apply -f k8s/"
    exit 1
fi

# Verificar se pods estão rodando
echo "📋 Verificando pods..."
PODS_READY=$(kubectl get pods -n pspd --no-headers | grep -c "Running" || true)
if [ "$PODS_READY" -lt 3 ]; then
    echo "⚠️  Nem todos os pods estão Running"
    kubectl get pods -n pspd
    echo ""
    read -p "Continuar mesmo assim? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Verificar se Prometheus está rodando
echo "📋 Verificando Prometheus..."
if ! kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus &> /dev/null; then
    echo "⚠️  Prometheus não encontrado no namespace 'monitoring'"
    echo "   Para instalar: helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace"
fi

echo ""
echo "✅ Verificações concluídas!"
echo ""

# Função para matar processos na saída
cleanup() {
    echo ""
    echo "🛑 Encerrando processos..."
    jobs -p | xargs -r kill 2>/dev/null || true
    exit 0
}

trap cleanup SIGINT SIGTERM

if [ "$MODE" == "ngrok" ]; then
    echo "🌐 Modo: Ngrok (Frontend Vercel + Backend Kubernetes)"
    echo ""
    
    # Verificar se ngrok está instalado
    if ! command -v ngrok &> /dev/null; then
        echo "❌ Ngrok não está instalado"
        echo ""
        echo "Instalação:"
        echo "  1. Baixe: https://ngrok.com/download"
        echo "  2. OU: snap install ngrok"
        echo "  3. Configure auth token: ngrok config add-authtoken <token>"
        echo ""
        exit 1
    fi
    
    echo "📡 Iniciando port-forward do Gateway P (porta 8080)..."
    kubectl port-forward -n pspd svc/p-svc 8080:80 > /dev/null 2>&1 &
    PF_PID=$!
    
    # Aguardar port-forward estar pronto
    sleep 3
    
    echo "🌍 Expondo backend com Ngrok..."
    ngrok http 8080 > /dev/null 2>&1 &
    NGROK_PID=$!
    
    # Aguardar Ngrok iniciar
    sleep 3
    
    # Pegar URL pública do Ngrok
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"https://[^"]*' | cut -d'"' -f4 | head -1)
    
    if [ -z "$NGROK_URL" ]; then
        echo "❌ Falha ao obter URL do Ngrok"
        echo "   Verifique se Ngrok está rodando: curl http://localhost:4040/api/tunnels"
        exit 1
    fi
    
    echo ""
    echo "✅ Backend exposto publicamente!"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Configuração do Frontend (Vercel):"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1. Acesse: https://vercel.com/seu-usuario/streaming-app-design/settings/environment-variables"
    echo ""
    echo "2. Adicione variável de ambiente:"
    echo "   Key:   NEXT_PUBLIC_API_URL"
    echo "   Value: $NGROK_URL"
    echo "   Environment: Production"
    echo ""
    echo "3. Redeploy o projeto na Vercel"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🧪 Testar Backend:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "curl \"$NGROK_URL/api/content?type=all\""
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Acessar Monitoramento:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Em NOVOS terminais, execute:"
    echo ""
    echo "# Prometheus:"
    echo "kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
    echo "→ http://localhost:9090"
    echo ""
    echo "# Grafana:"
    echo "kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
    echo "→ http://localhost:3000"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "⏳ Processos rodando... (Ctrl+C para encerrar)"
    echo ""
    
    # Manter script rodando
    wait

elif [ "$MODE" == "local" ]; then
    echo "💻 Modo: Frontend Local + Backend Local"
    echo ""
    
    # Verificar se frontend existe
    if [ ! -d "../streaming-app-design" ]; then
        echo "❌ Pasta do frontend não encontrada: ../streaming-app-design"
        echo ""
        echo "Clone o repositório:"
        echo "  git clone <repo-url> ../streaming-app-design"
        exit 1
    fi
    
    # Verificar se node_modules existe
    if [ ! -d "../streaming-app-design/node_modules" ]; then
        echo "📦 Instalando dependências do frontend..."
        cd ../streaming-app-design
        if command -v pnpm &> /dev/null; then
            pnpm install
        else
            npm install
        fi
        cd - > /dev/null
    fi
    
    # Criar .env.local
    echo "📝 Configurando .env.local..."
    cat > ../streaming-app-design/.env.local << 'EOF'
NEXT_PUBLIC_API_URL=http://localhost:8080
EOF
    
    echo "📡 Iniciando port-forward do Gateway P (porta 8080)..."
    kubectl port-forward -n pspd svc/p-svc 8080:80 > /dev/null 2>&1 &
    PF_PID=$!
    
    # Aguardar port-forward estar pronto
    sleep 3
    
    echo "🚀 Iniciando frontend Next.js..."
    cd ../streaming-app-design
    
    if command -v pnpm &> /dev/null; then
        pnpm dev > /dev/null 2>&1 &
    else
        npm run dev > /dev/null 2>&1 &
    fi
    NEXT_PID=$!
    cd - > /dev/null
    
    # Aguardar Next.js iniciar
    echo "⏳ Aguardando Next.js iniciar..."
    sleep 5
    
    echo ""
    echo "✅ Frontend e Backend rodando!"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌐 Acessos:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Frontend:  http://localhost:3000"
    echo "Backend:   http://localhost:8080"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Acessar Monitoramento:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Em NOVOS terminais, execute:"
    echo ""
    echo "# Prometheus:"
    echo "kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
    echo "→ http://localhost:9090"
    echo ""
    echo "# Grafana:"
    echo "kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
    echo "→ http://localhost:3000"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "⏳ Processos rodando... (Ctrl+C para encerrar)"
    echo ""
    
    # Manter script rodando
    wait

else
    echo "❌ Modo inválido: $MODE"
    echo ""
    echo "Uso:"
    echo "  ./scripts/expose_backend.sh ngrok   # Expor com Ngrok (para Vercel)"
    echo "  ./scripts/expose_backend.sh local   # Rodar frontend localmente"
    exit 1
fi
