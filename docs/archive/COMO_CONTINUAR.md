# 🔄 Sistema de Checkpoints - Como Usar

> **⚠️ DOCUMENTO ARQUIVADO** - Algumas referências a scripts (`./scripts/setup_multinode_cluster.sh`, `./scripts/deploy.sh`) podem estar desatualizadas.  
> Para instruções atualizadas, consulte: `QUICKSTART.md` na raiz do projeto.

## 📍 O Problema Resolvido

Antes: Se algo dava erro no meio da execução, você tinha que **recomeçar tudo do zero** (15-20 min).

Agora: O sistema **salva o progresso** automaticamente. Se der erro, você continua de onde parou!

## ⚙️ Como Funciona

O script `RUN_COMPLETE.sh` divide a execução em **5 etapas**:

1. **Cluster Multi-Node** (5-6 min)
2. **Deploy Aplicações** (2-3 min)  
3. **ServiceMonitors** (30s)
4. **Port-Forwards** (5s)
5. **Testes de Carga** (8-10 min)

Após cada etapa concluída com sucesso, um **checkpoint** é salvo automaticamente.

## 🎯 Cenários de Uso

### Cenário 1: Primeira execução (tudo ok)

```bash
./RUN_COMPLETE.sh
# Escolhe "S" para continuar
# Executa tudo sem problemas
# ✅ Checkpoint limpo automaticamente no final
```

### Cenário 2: Erro no meio da execução

```bash
./RUN_COMPLETE.sh
# Passo 1: ✅ Cluster criado (checkpoint salvo)
# Passo 2: ✅ Apps deployadas (checkpoint salvo)
# Passo 3: ❌ ERRO! ServiceMonitor falhou

# Execute novamente:
./RUN_COMPLETE.sh

# O script detecta o checkpoint:
# 📍 Checkpoint encontrado! Última etapa concluída: 2/5
# 
# Opções:
#   1. ✅ Continuar de onde parou (Etapa 3)  ← ESCOLHA ESTA
#   2. 🔄 Recomeçar do zero
#   3. ❌ Cancelar

# Escolha "1" e ele pula as etapas 1 e 2, começando direto na 3!
```

### Cenário 3: Quer recomeçar do zero mesmo com checkpoint

```bash
./RUN_COMPLETE.sh

# Checkpoint encontrado!
# Escolha "2" para recomeçar do zero
# O checkpoint será limpo e tudo reinicia
```

### Cenário 4: Executar etapa específica manualmente

```bash
# Se você sabe exatamente o que precisa:

# Apenas criar cluster:
./scripts/setup_multinode_cluster.sh

# Apenas deploy:
./scripts/deploy.sh setup

# Apenas testes:
./scripts/run_all_tests.sh all

# Apenas análise:
python3 scripts/analyze_results.py
```

## 🔍 Visualizando o Checkpoint

```bash
# Ver qual etapa foi concluída:
cat /tmp/pspd_checkpoint.txt

# Limpar checkpoint manualmente:
rm /tmp/pspd_checkpoint.txt
```

## 💡 Dicas

### Quando usar "Continuar" (opção 1):
- Erro temporário (rede, timeout)
- Ajustou configuração e quer tentar novamente
- Interrompeu manualmente (Ctrl+C)

### Quando usar "Recomeçar" (opção 2):
- Mudou configuração do cluster
- Quer executar tudo novamente do zero
- Cluster foi deletado manualmente

### Quando usar "Cancelar" (opção 3):
- Quer executar apenas uma etapa específica
- Vai debugar manualmente

## 🚀 Exemplo Real de Recuperação

```bash
# Primeira tentativa (falhou no deploy):
edilberto@pc:~/pspd/atividade-final-pspd$ ./RUN_COMPLETE.sh
📋 Passo 1/5: Criando cluster... ✅
📦 Passo 2/5: Deploy... ❌ ImagePullBackOff!

# Você corrigiu o problema das imagens
# Agora execute novamente:

edilberto@pc:~/pspd/atividade-final-pspd$ ./RUN_COMPLETE.sh

📍 Checkpoint encontrado! Última etapa concluída: 1/5

Opções:
  1. ✅ Continuar de onde parou (Etapa 2)
  2. 🔄 Recomeçar do zero
  3. ❌ Cancelar

Escolha [1/2/3]: 1

✓ Continuando da etapa 2
⏭️  Pulando Passo 1/5 (já concluído)
📦 Passo 2/5: Deploy... ✅ Sucesso!
📊 Passo 3/5: ServiceMonitors... ✅
🔗 Passo 4/5: Port-forwards... ✅
🧪 Passo 5/5: Testes... ✅

✅ EXECUÇÃO COMPLETA FINALIZADA COM SUCESSO!
```

**Economia de tempo: ~5 minutos** (não precisou recriar o cluster!)

## 🐛 Debugging

Se algo não funcionar:

```bash
# 1. Verificar checkpoint atual
cat /tmp/pspd_checkpoint.txt

# 2. Verificar estado do cluster
kubectl get nodes
kubectl get pods -n pspd
kubectl get pods -n monitoring

# 3. Limpar tudo e recomeçar
rm /tmp/pspd_checkpoint.txt
minikube delete -p pspd-cluster
./RUN_COMPLETE.sh
```

## 📊 Tabela de Etapas

| Etapa | Descrição | Tempo | Pode Pular? |
|-------|-----------|-------|-------------|
| 1 | Cluster multi-node | 5-6 min | ❌ Necessário |
| 2 | Deploy apps | 2-3 min | ⚠️ Se cluster ok |
| 3 | ServiceMonitors | 30s | ⚠️ Se apps ok |
| 4 | Port-forwards | 5s | ✅ Pode refazer |
| 5 | Testes | 8-10 min | ✅ Pode refazer |

## ✅ Benefícios

- ⏰ **Economia de tempo**: Não refaz trabalho já concluído
- 🎯 **Precisão**: Começa exatamente onde parou
- 🧠 **Inteligente**: Detecta automaticamente o progresso
- 🔄 **Flexível**: Permite recomeçar se necessário
- 🛡️ **Seguro**: Valida estado antes de continuar
