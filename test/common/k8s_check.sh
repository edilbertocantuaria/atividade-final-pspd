#!/bin/bash
# Script auxiliar: Funções compartilhadas para verificação de cluster

check_kubernetes_cluster() {
    echo "🔍 Verificando cluster Kubernetes..."
    
    # Verificar se kubectl está instalado
    if ! command -v kubectl &> /dev/null; then
        echo "❌ kubectl não encontrado!"
        echo "   Instale o kubectl: https://kubernetes.io/docs/tasks/tools/"
        return 1
    fi
    
    # Verificar se minikube está instalado
    if ! command -v minikube &> /dev/null; then
        echo "❌ minikube não encontrado!"
        echo "   Instale o minikube: https://minikube.sigs.k8s.io/docs/start/"
        return 1
    fi
    
    # Verificar status do minikube
    local minikube_status=$(minikube status --format='{{.Host}}' 2>/dev/null)
    
    if [ "$minikube_status" != "Running" ]; then
        echo "⚠️  Minikube não está rodando"
        echo "🚀 Iniciando Minikube..."
        
        if minikube start; then
            echo "✅ Minikube iniciado com sucesso"
        else
            echo "❌ Falha ao iniciar Minikube"
            return 1
        fi
    fi
    
    # Verificar se o API server está respondendo
    if ! kubectl cluster-info &>/dev/null; then
        echo "⚠️  Cluster não está respondendo, atualizando contexto..."
        
        if minikube update-context; then
            echo "✅ Contexto atualizado"
        else
            echo "❌ Falha ao atualizar contexto"
            return 1
        fi
        
        # Tentar novamente após atualizar contexto
        if ! kubectl cluster-info &>/dev/null; then
            echo "❌ Cluster ainda não está acessível"
            echo "   Tentando reiniciar..."
            
            if minikube start; then
                echo "✅ Cluster reiniciado com sucesso"
            else
                echo "❌ Falha ao acessar cluster Kubernetes"
                return 1
            fi
        fi
    fi
    
    # Verificar addons necessários
    echo "🔌 Verificando addons do Minikube..."
    
    # Verificar ingress
    if ! minikube addons list | grep -q "ingress.*enabled"; then
        echo "⚠️  Addon ingress não está habilitado"
        echo "🔧 Habilitando ingress..."
        minikube addons enable ingress
    fi
    
    # Verificar metrics-server (opcional, mas útil)
    if ! minikube addons list | grep -q "metrics-server.*enabled"; then
        echo "💡 Dica: Habilite metrics-server para métricas de recursos"
        echo "   Execute: minikube addons enable metrics-server"
    fi
    
    echo "✅ Cluster Kubernetes está pronto!"
    kubectl cluster-info | grep "Kubernetes control plane"
    
    return 0
}

# Verificar se está sendo executado diretamente ou sendo sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Executado diretamente - rodar verificação
    check_kubernetes_cluster
else
    # Sendo sourced - apenas definir a função
    :
fi
