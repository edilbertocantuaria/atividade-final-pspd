# 🎯 Cenários de Teste - Análise Comparativa

## Visão Geral

Esta estrutura implementa 5 cenários distintos para análise comparativa de performance, escalabilidade e custos em Kubernetes, conforme requisito **3.c** da atividade.

## 📋 Sumário dos Cenários

| # | Nome | Característica Principal | Objetivo |
|---|------|--------------------------|----------|
| 1 | **Base** | HPA ativo, 1 réplica inicial | Baseline de referência |
| 2 | **Réplicas** | Início com 2 réplicas | Avaliar warm start vs cold start |
| 3 | **Distribuição** | Anti-affinity, 1 pod/node | Testar HA e latência inter-node |
| 4 | **Recursos** | Limites reduzidos (50% CPU/Mem) | Stress test com recursos escassos |
| 5 | **Sem HPA** | Réplicas fixas (3-5) | Baseline sem elasticidade |

---

## 🔬 Cenário 1: Base (Referência)

**Arquivo**: `scenario1-base/`

### Configuração
- Réplicas iniciais: 1 (a, b, p)
- HPA: ✅ Ativo (1-5 para a/b, 1-10 para p)
- CPU target: 70%
- Recursos: 100m/500m CPU, 128Mi/256Mi Mem

### Hipótese
Estabelecer baseline de performance com autoscaling padrão.

### Métricas Chave
- Latência P95 baseline
- Tempo de scale-up
- Utilização de recursos
- Custo médio (pod*min)

---

## 🚀 Cenário 2: Réplicas Aumentadas

**Arquivo**: `scenario2-replicas/`

### Configuração
- Réplicas iniciais: **2** (a, b, p) ⬆️
- HPA: ✅ Ativo (2-5 para a/b, 2-10 para p)
- CPU target: 70%
- Recursos: Mesmos do base

### Hipótese
Iniciar com mais réplicas reduz latência inicial (elimina cold start) mas aumenta custo.

### Comparação com Cenário 1
| Métrica | Cenário 1 | Cenário 2 | Esperado |
|---------|-----------|-----------|----------|
| Latência baseline | Referência | Menor | ⬇️ -20% |
| Throughput inicial | Referência | Maior | ⬆️ +100% |
| Cold start | Sim | Não | ✅ |
| Custo baseline | Referência | 2x | ⬆️ +100% |

---

## 🌐 Cenário 3: Distribuição Forçada

**Arquivo**: `scenario3-distribution/`

### Configuração
- Réplicas iniciais: **3** (a, b, p) ⬆️
- **Pod Anti-Affinity**: 1 pod por node (distribuído)
- HPA: ✅ Ativo (3-6 para a/b, 3-12 para p)
- CPU target: 70%
- Recursos: Mesmos do base

### Hipótese
Distribuir pods garante alta disponibilidade mas pode aumentar latência de rede entre nodes.

### Benefícios
✅ Alta disponibilidade (falha de 1 node não derruba serviço)  
✅ Balanceamento de carga uniforme entre nodes  
✅ Isolamento de falhas  

### Trade-offs
❌ Latência inter-node (comunicação cross-node)  
❌ Overhead de rede  
❌ Custo inicial 3x maior  

### Validação
```bash
# Verificar distribuição (cada serviço em 3 nodes diferentes)
kubectl get pods -n pspd -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
```

---

## 💰 Cenário 4: Recursos Limitados

**Arquivo**: `scenario4-resources/`

### Configuração
- Réplicas iniciais: 1
- HPA: ✅ Ativo e **mais agressivo**
  - CPU target: **60%** (vs 70% base) ⬇️
  - Max réplicas: **8-15** (vs 5-10 base) ⬆️
- **Recursos reduzidos**:
  - CPU: **50m**/200m (vs 100m/500m) ⬇️ -50%/-60%
  - Memory: **64Mi**/128Mi (vs 128Mi/256Mi) ⬇️ -50%

### Hipótese
Recursos limitados forçam scaling horizontal agressivo. HPA compensa criando mais pods pequenos.

### Trade-offs
| Aspecto | Base | Recursos Limitados | Impacto |
|---------|------|-------------------|---------|
| CPU/pod | 500m | 200m | ⬇️ -60% |
| Pods spike | ~10 | ~18 (estimado) | ⬆️ +80% |
| Throttling | Baixo | Alto | ⚠️ |
| Custo/pod | Alto | Baixo | ⬇️ |
| Custo total | Médio | Similar | ≈ |

### Quando usar
- ✅ Ambientes dev/staging com recursos limitados
- ✅ Testes de stress e resiliência
- ❌ Produção sem validação prévia

---

## 🔒 Cenário 5: Sem HPA

**Arquivo**: `scenario5-no-hpa/`

### Configuração
- Réplicas: **FIXAS** (3 a/b, 5 p) - NÃO ESCALARÁ
- HPA: ❌ **DESABILITADO**
- Recursos: Mesmos do base

### Hipótese
Sem HPA = over-provisioning constante. Paga pelo pior caso sempre.

### Análise de Custo

**Cenário 1 (HPA)**:
```
Baseline: 3 pods × 5min = 15 pod-min
Ramp:     6 pods × 5min = 30 pod-min
Spike:   11 pods × 2min = 22 pod-min
Soak:     7 pods × 15min = 105 pod-min
─────────────────────────────────────
TOTAL: ~172 pod-min (2.9 pod-horas)
```

**Cenário 5 (Sem HPA)**:
```
Todos os testes: 11 pods × 27min = 297 pod-min (4.9 pod-horas)
─────────────────────────────────────
DESPERDÍCIO: +73% de custo
```

### Quando usar
- ✅ Carga extremamente previsível e constante
- ✅ Debugging (sem variáveis de scaling)
- ❌ Produção (anti-pattern moderno)

---

## 🔄 Como Executar Cada Cenário

### Passo 1: Limpar Ambiente

```bash
kubectl delete namespace pspd
kubectl create namespace pspd
```

### Passo 2: Aplicar Cenário

```bash
# Cenário 1 (Base)
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/a.yaml
kubectl apply -f k8s/b.yaml
kubectl apply -f k8s/p.yaml

# Cenário 2 (Réplicas)
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/scenarios/scenario2-replicas/

# Cenário 3 (Distribuição)
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/scenarios/scenario3-distribution/

# Cenário 4 (Recursos)
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/scenarios/scenario4-resources/

# Cenário 5 (Sem HPA)
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/scenarios/scenario5-no-hpa/
```

### Passo 3: Aguardar Pods

```bash
kubectl wait --for=condition=ready pod --all -n pspd --timeout=120s
```

### Passo 4: Executar Testes

```bash
./scripts/run_all_tests.sh all
```

### Passo 5: Salvar Resultados

```bash
# Renomear pasta de resultados
mv results/ results-scenario-X/
```

---

## 📊 Script Automatizado

Use o script `run_scenario_comparison.sh` para executar todos os cenários automaticamente:

```bash
./scripts/run_scenario_comparison.sh
```

Este script:
1. Executa cada cenário sequencialmente
2. Salva resultados em `results-scenario-{1-5}/`
3. Gera análise comparativa ao final
4. Cria gráficos side-by-side

---

## 📈 Métricas de Comparação

Para cada cenário, colete:

### Performance
- ✅ Latência P95 (baseline, ramp, spike, soak)
- ✅ Throughput médio
- ✅ Taxa de sucesso/erro
- ✅ Tempo de resposta P50/P90/P95/P99

### Escalabilidade
- ✅ Tempo de scale-up (0→carga máxima)
- ✅ Tempo de scale-down (carga máxima→0)
- ✅ Número de réplicas (min/avg/max)
- ✅ Estabilidade do HPA

### Recursos
- ✅ CPU utilization média/pico
- ✅ Memory utilization média/pico
- ✅ Pods criados total
- ✅ Custo (pod*min)

### Resiliência
- ✅ Comportamento durante spike
- ✅ Recuperação pós-spike
- ✅ Estabilidade durante soak

---

## 🎯 Matriz de Análise Esperada

| Cenário | Latência | Throughput | Custo | HA | Complexidade |
|---------|----------|------------|-------|-----|--------------|
| 1. Base | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| 2. Réplicas | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| 3. Distribuição | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| 4. Recursos | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 5. Sem HPA | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐ | ⭐⭐ | ⭐⭐ |

**Legenda**: ⭐ = Ruim, ⭐⭐⭐⭐⭐ = Excelente

---

## 📝 Documentação Detalhada

Cada cenário tem um `README.md` próprio com:
- ✅ Configuração detalhada
- ✅ Hipóteses e objetivos
- ✅ Como executar
- ✅ Métricas esperadas
- ✅ Análise de trade-offs

Consulte os arquivos individuais em `scenarios/scenario{1-5}/README.md`.

---

## 🚀 Próximos Passos

1. **Executar baseline** (Cenário 1)
2. **Executar variações** (Cenários 2-5)
3. **Comparar resultados** (análise side-by-side)
4. **Documentar insights** (conclusões e recomendações)
5. **Gerar relatório final** (com gráficos comparativos)
