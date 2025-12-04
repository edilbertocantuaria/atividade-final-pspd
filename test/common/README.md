# Common Test Utilities

Esta pasta contém scripts auxiliares compartilhados entre os cenários de teste.

## 📄 Arquivos

### `k8s_check.sh`

Script de verificação automática do cluster Kubernetes antes de executar testes.

#### 🔍 O que verifica:

1. **kubectl instalado** - Ferramenta de linha de comando do Kubernetes
2. **minikube instalado** - Cluster Kubernetes local
3. **Cluster rodando** - Verifica se o minikube está ativo
4. **API Server acessível** - Testa conexão com o cluster
5. **Contexto atualizado** - Corrige problemas de porta desatualizada
6. **Addons necessários** - Verifica ingress (obrigatório) e metrics-server (opcional)

#### ✅ Correções automáticas:

- **Cluster parado**: Executa `minikube start` automaticamente
- **Contexto desatualizado**: Executa `minikube update-context`
- **Ingress desabilitado**: Habilita o addon ingress
- **Metrics-server**: Sugere habilitação (opcional)

#### 💻 Uso:

```bash
# Executar diretamente (teste manual)
./test/common/k8s_check.sh

# Incluir em outros scripts (uso nos scripts de setup)
source ./test/common/k8s_check.sh
if ! check_kubernetes_cluster; then
    echo "❌ Falha na verificação do cluster"
    exit 1
fi
```

#### 📊 Saída esperada:

```
🔍 Verificando cluster Kubernetes...
✅ Minikube já está rodando
🔌 Verificando addons do Minikube...
✅ Cluster Kubernetes está pronto!
Kubernetes control plane is running at https://127.0.0.1:61288
```

#### 🔧 Casos de erro:

**Caso 1: Minikube parado**
```
⚠️  Minikube não está rodando
🚀 Iniciando Minikube...
✅ Minikube iniciado com sucesso
```

**Caso 2: Contexto desatualizado**
```
⚠️  Cluster não está respondendo, atualizando contexto...
✅ Contexto atualizado
```

**Caso 3: kubectl não instalado**
```
❌ kubectl não encontrado!
   Instale o kubectl: https://kubernetes.io/docs/tasks/tools/
```

## 🎯 Integração

Este script é **automaticamente chamado** por todos os scripts `00_setup.sh` dos 5 cenários:

- ✅ `test/scenario_1/00_setup.sh`
- ✅ `test/scenario_2/00_setup.sh`
- ✅ `test/scenario_3/00_setup.sh`
- ✅ `test/scenario_4/00_setup.sh`
- ✅ `test/scenario_5/00_setup.sh`

Isso garante que o cluster esteja sempre pronto antes de executar qualquer teste.

## 🚀 Benefícios

1. **Zero configuração manual** - Cluster é iniciado automaticamente
2. **Evita erros comuns** - Detecta e corrige problemas de contexto
3. **Mensagens claras** - Feedback visual do que está acontecendo
4. **Retry automático** - Tenta corrigir problemas antes de falhar
5. **Economia de tempo** - Não precisa iniciar cluster manualmente

## 📝 Notas

- O script é idempotente (pode ser executado múltiplas vezes com segurança)
- Não afeta clusters já em execução
- Compatível com Bash 4.0+
- Suporta Ubuntu, macOS e WSL2
