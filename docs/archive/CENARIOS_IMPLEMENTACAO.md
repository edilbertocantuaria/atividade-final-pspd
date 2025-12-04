# ✅ Análise Comparativa de Cenários - Implementação Completa

> **⚠️ DOCUMENTO ARQUIVADO** - Algumas referências a scripts podem estar desatualizadas.  
> Para análise atualizada, consulte: `docs/ANALISE_CENARIOS.md`

## 📋 Requisito Atendido

**Item 3.c da Atividade**: "Desenho de cenários variando características da aplicação e do cluster K8S"

## 🎯 Estrutura Implementada

### Diretórios Criados

```
k8s/scenarios/
├── README.md                          # Documentação geral
├── scenario1-base/
│   └── README.md                      # HPA ativo, 1 réplica inicial
├── scenario2-replicas/
│   ├── README.md                      # 2 réplicas iniciais
│   ├── a.yaml
│   ├── b.yaml
│   └── p.yaml
├── scenario3-distribution/
│   ├── README.md                      # Anti-affinity, distribuído
│   ├── a.yaml
│   ├── b.yaml
│   └── p.yaml
├── scenario4-resources/
│   ├── README.md                      # Recursos reduzidos 50%
│   ├── a.yaml
│   ├── b.yaml
│   └── p.yaml
└── scenario5-no-hpa/
    ├── README.md                      # Réplicas fixas, sem HPA
    ├── a.yaml
    ├── b.yaml
    └── p.yaml
```

## 🔬 Cenários Implementados

### ✅ Cenário 1: Base (Referência)
- **Local**: Arquivos em `k8s/` (a.yaml, b.yaml, p.yaml)
- **Característica**: HPA ativo, configuração padrão
- **Réplicas**: 1 inicial → 1-5 (a/b), 1-10 (p)
- **Recursos**: 100m/500m CPU, 128Mi/256Mi Mem
- **Objetivo**: Baseline de referência

### ✅ Cenário 2: Réplicas Aumentadas
- **Variação**: Número de réplicas iniciais
- **Réplicas**: 2 inicial → 2-5 (a/b), 2-10 (p)
- **Diferencial**: Warm start (elimina cold start)
- **Hipótese**: Menor latência inicial, maior custo

### ✅ Cenário 3: Distribuição Forçada
- **Variação**: Distribuição nos workers
- **Réplicas**: 3 inicial → 3-6 (a/b), 3-12 (p)
- **Diferencial**: Pod Anti-Affinity (1 pod/node)
- **Hipótese**: Alta disponibilidade, possível aumento de latência inter-node

### ✅ Cenário 4: Recursos Limitados
- **Variação**: CPU/Memory limits e requests
- **Recursos**: 50m/200m CPU, 64Mi/128Mi Mem (-50% vs base)
- **HPA**: Mais agressivo (target 60%, max 8-15 réplicas)
- **Hipótese**: Scaling horizontal compensa recursos limitados

### ✅ Cenário 5: Sem HPA
- **Variação**: Com vs sem autoscaling
- **Réplicas**: FIXAS (3 a/b, 5 p)
- **HPA**: Desabilitado
- **Hipótese**: Over-provisioning constante, ~73% mais caro

## 📊 Matriz de Variações

| Aspecto | C1 | C2 | C3 | C4 | C5 |
|---------|----|----|----|----|-----|
| **Réplicas iniciais** | 1 | 2 | 3 | 1 | 3/5 |
| **HPA** | ✅ | ✅ | ✅ | ✅ | ❌ |
| **CPU request** | 100m | 100m | 100m | 50m | 100m |
| **CPU limit** | 500m | 500m | 500m | 200m | 500m |
| **Distribuição** | Padrão | Padrão | Anti-affinity | Padrão | Padrão |
| **Max réplicas** | 5-10 | 5-10 | 6-12 | 8-15 | N/A |

## 🚀 Como Executar

### Execução Manual (Cenário Individual)

```bash
# Exemplo: Cenário 2
kubectl delete namespace pspd
kubectl create namespace pspd
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/scenarios/scenario2-replicas/
kubectl wait --for=condition=ready pod --all -n pspd --timeout=120s
./scripts/run_all_tests.sh all
mv results/ results-scenario-2-replicas/
```

### Execução Automatizada (Todos os Cenários)

```bash
# Script interativo
./scripts/run_scenario_comparison.sh

# Modo não-interativo (todos os cenários)
./scripts/run_scenario_comparison.sh --all

# Apenas gerar comparação
./scripts/run_scenario_comparison.sh --compare
```

## 📈 Métricas Coletadas

Para cada cenário, o sistema coleta:

### Performance
- ✅ Latência P50/P90/P95/P99
- ✅ Throughput (req/s)
- ✅ Taxa de sucesso/erro
- ✅ Tempo de resposta médio

### Escalabilidade
- ✅ Número de réplicas (min/avg/max)
- ✅ Tempo de scale-up/scale-down
- ✅ Estabilidade do HPA
- ✅ Eventos de scaling

### Recursos
- ✅ CPU utilization (média/pico)
- ✅ Memory utilization (média/pico)
- ✅ Custo estimado (pod*min)
- ✅ Eficiência de recursos

### Disponibilidade
- ✅ Distribuição de pods por node
- ✅ Comportamento durante spike
- ✅ Recuperação pós-carga

## 🎯 Análise Esperada

### Cenário 1 (Base)
- Baseline de referência
- Bom equilíbrio custo/performance

### Cenário 2 (Réplicas)
- ⬆️ Latência inicial menor (-20%)
- ⬆️ Throughput inicial maior (+100%)
- ⬇️ Custo baseline maior (+100%)

### Cenário 3 (Distribuição)
- ⬆️ Alta disponibilidade
- ⬇️ Possível latência inter-node (+5-10%)
- ⬇️ Custo inicial maior (+200%)

### Cenário 4 (Recursos)
- ⬆️ Scaling mais agressivo
- ⬇️ CPU throttling frequente
- ≈ Custo similar (mais pods pequenos)

### Cenário 5 (Sem HPA)
- ⬇️ Over-provisioning constante
- ⬇️ Custo +73% maior
- ⬆️ Simplicidade operacional

## 📊 Saída Esperada

Após execução completa:

```
atividade-final-pspd/
├── results-scenario-1-base/
│   ├── baseline/, ramp/, spike/, soak/
│   ├── plots/
│   ├── k8s-config.yaml
│   └── pods-layout.txt
├── results-scenario-2-replicas/
├── results-scenario-3-distribution/
├── results-scenario-4-resources/
├── results-scenario-5-no-hpa/
└── scenario-comparison/
    ├── 01_scenario_latency_comparison.png
    ├── 02_scenario_throughput_comparison.png
    ├── 03_scenario_hpa_scaling.png
    ├── 04_scenario_success_rate.png
    ├── 05_scenario_cost_analysis.png
    ├── 06_scenario_performance_radar.png
    ├── SCENARIO_COMPARISON_REPORT.txt
    └── comparison-summary.md
```

### Gráficos Comparativos Gerados

1. **Latência P95**: Compara latência entre todos os cenários em cada tipo de teste
2. **Throughput**: Visualiza req/s de cada cenário
3. **HPA Scaling**: Mostra número de réplicas durante spike
4. **Taxa de Sucesso**: 4 gráficos (1 por teste) comparando success rate
5. **Análise de Custo**: Pods ativos e custo estimado (pod-hora)
6. **Radar Chart**: Visão multi-dimensional (throughput, latência, custo, HA)

## ✅ Checklist de Implementação

- [x] Cenário 1: Base (arquivos existentes)
- [x] Cenário 2: 2 réplicas iniciais
- [x] Cenário 3: Distribuição com anti-affinity
- [x] Cenário 4: Recursos limitados (50%)
- [x] Cenário 5: Sem HPA (réplicas fixas)
- [x] README.md de cada cenário
- [x] README.md geral dos cenários
- [x] Script de execução automatizada
- [x] Documentação de análise comparativa

## 🎓 Valor Acadêmico

Esta implementação atende ao requisito **3.c** demonstrando:

1. **Variação de réplicas**: Cenários 1, 2, 5
2. **Variação de distribuição**: Cenário 3 (anti-affinity)
3. **Variação de recursos**: Cenário 4 (CPU/Mem limits)
4. **Variação de autoscaling**: Cenário 5 (com vs sem HPA)

Cada variação permite análise de trade-offs entre:
- 💰 **Custo** (pod*min)
- 📈 **Performance** (latência, throughput)
- 🔒 **Resiliência** (HA, distribuição)
- ⚡ **Escalabilidade** (HPA, recursos)

## 📝 Próximos Passos

1. ✅ Executar cenário 1 (já executado - baseline atual)
2. ⏳ Executar cenários 2-5
3. ⏳ Gerar análise comparativa
4. ⏳ Documentar insights e conclusões
5. ⏳ Criar gráficos side-by-side

## 🚀 Execução Recomendada

```bash
# 1. Executar todos os cenários (2-3 horas)
./scripts/run_scenario_comparison.sh --all

# 2. Gerar comparação
./scripts/run_scenario_comparison.sh --compare

# 3. Revisar resultados
cat scenario-comparison/comparison-summary.md
```

---

**Status**: ✅ Implementação completa  
**Arquivos criados**: 18 (5 cenários × 3 YAMLs + 5 READMEs + 1 README geral + 1 script + 1 doc)  
**Pronto para execução**: Sim
