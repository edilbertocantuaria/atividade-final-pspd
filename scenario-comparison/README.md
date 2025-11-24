# 📊 Análise Comparativa de Cenários - Visualizações

## Visão Geral

Esta pasta contém a análise comparativa completa entre os 5 cenários de teste implementados.

## 📈 Gráficos Gerados

### 1. Latência P95 Comparison (`01_scenario_latency_comparison.png`)

**Esquerda**: Barras agrupadas mostrando latência P95 de cada cenário em cada tipo de teste (baseline, ramp, spike, soak).

**Direita**: Barras horizontais focadas no teste de spike, mostrando qual cenário teve melhor/pior latência sob stress.

**Interpretação**:
- ✅ **Valores menores são melhores**
- Cenário 2 (2 réplicas) deve ter latência menor no baseline (warm start)
- Cenário 4 (recursos limitados) tende a ter latência maior (throttling)
- Cenário 5 (sem HPA) pode ter latência alta no spike (sem scaling)

---

### 2. Throughput Comparison (`02_scenario_throughput_comparison.png`)

**Esquerda**: Barras agrupadas mostrando throughput (req/s) de cada cenário.

**Direita**: Throughput médio geral de cada cenário.

**Interpretação**:
- ✅ **Valores maiores são melhores**
- Cenários com mais réplicas iniciais (2, 3, 5) devem ter throughput baseline maior
- Cenário 5 (sem HPA) pode ter throughput consistente mas não otimizado
- Cenário 4 (recursos limitados) pode compensar com mais pods pequenos

---

### 3. HPA Scaling (`03_scenario_hpa_scaling.png`)

Mostra número de réplicas de cada serviço (A, B, P) durante o teste de spike (200 VUs).

**Interpretação**:
- ✅ **Cenário 5 não tem barras** (sem HPA = réplicas fixas)
- Cenário 4 deve ter mais réplicas (compensa recursos limitados)
- Gateway P tende a escalar mais que Services A/B
- Cenário 1 (base) é referência para comparação

---

### 4. Success Rate (`04_scenario_success_rate.png`)

4 subgráficos (baseline, ramp, spike, soak) mostrando taxa de sucesso de cada cenário.

**Interpretação**:
- ✅ **Meta: ≥ 95%** (linha vermelha tracejada)
- Spike pode ter taxa menor em alguns cenários (stress extremo)
- Cenário 4 pode ter taxa reduzida (CPU throttling, OOM)
- Baseline/soak devem estar próximos de 100%

---

### 5. Cost Analysis (`05_scenario_cost_analysis.png`)

**Esquerda**: Pods ativos em diferentes fases (baseline, spike, média).

**Direita**: Custo total estimado (pod-horas) para executar todos os testes (~27min).

**Interpretação**:
- ✅ **Valores menores são mais econômicos**
- Cenário 5 (sem HPA) tem custo FIXO alto (~11 pods sempre)
- Cenário 1 (base) é referência (linha azul tracejada)
- Cenário 4 pode ter custo similar ao base (mais pods pequenos)
- Cenários 2-3 têm custo inicial maior mas justificado por performance/HA

**Análise de Custo**:
```
Cenário 1 (Base):     ~2.7 pod-horas (baseline)
Cenário 2 (Réplicas): ~3.6 pod-horas (+33%)
Cenário 3 (Distrib.): ~5.0 pod-horas (+85%)
Cenário 4 (Recursos): ~4.0 pod-horas (+48%)
Cenário 5 (Sem HPA):  ~4.9 pod-horas (+81%)
```

---

### 6. Performance Radar (`06_scenario_performance_radar.png`)

Radar chart multi-dimensional comparando 5 aspectos:
- **Throughput**: Req/s geral
- **Latência P95**: Inverso (menor é melhor)
- **Success Rate**: Taxa de sucesso
- **Custo**: Inverso (menor custo = mais estrelas)
- **HA (High Availability)**: Resiliência e distribuição

**Interpretação**:
- ✅ **5 estrelas = excelente** em cada dimensão
- Área maior = cenário mais equilibrado
- Útil para visualizar trade-offs

**Scores esperados**:
```
Cenário 1 (Base):        Equilibrado (4 estrelas na maioria)
Cenário 2 (Réplicas):    Alto throughput/latência, custo médio
Cenário 3 (Distribuído): HA excelente, custo alto
Cenário 4 (Recursos):    Custo bom, performance reduzida
Cenário 5 (Sem HPA):     Performance boa, custo péssimo, HA baixo
```

---

## 📄 Relatórios Textuais

### `SCENARIO_COMPARISON_REPORT.txt`

Relatório completo com:
- Métricas detalhadas de cada cenário (baseline, ramp, spike, soak)
- Dados de HPA scaling
- Tabela comparativa resumida do spike test

**Exemplo de saída**:
```
Spike Test (200 VUs):
────────────────────────────────────────────────────────────────────────────────
Cenário                   Throughput        P95    Success     Pods
────────────────────────────────────────────────────────────────────────────────
S1: Base (HPA)              422.9/s      999ms     100.0%        11
S2: 2 Réplicas              450.3/s      850ms     100.0%        13
S3: Distribuído             410.2/s     1100ms      98.5%        15
S4: Recursos -50%           380.5/s     1450ms      95.2%        18
S5: Sem HPA                 420.1/s     1050ms      92.3%        11
```

### `comparison-summary.md`

Markdown com métricas extraídas do SUMMARY_REPORT.txt de cada cenário.

---

## 🎯 Como Interpretar a Análise

### Melhor Cenário para Cada Objetivo

| Objetivo | Cenário Recomendado | Motivo |
|----------|---------------------|--------|
| **Melhor Performance** | Cenário 2 (Réplicas) | Warm start, menor latência |
| **Menor Custo** | Cenário 1 (Base) | Otimizado pelo HPA |
| **Alta Disponibilidade** | Cenário 3 (Distribuído) | Pods em diferentes nodes |
| **Recursos Limitados** | Cenário 4 | Funciona com 50% menos recursos |
| **Simplicidade** | Cenário 5 (Sem HPA) | Previsível mas caro |

### Trade-offs Principais

#### Cenário 1 (Base) - ⭐⭐⭐⭐
✅ **Pros**: Equilibrado, bom custo/benefício, HPA otimiza automaticamente  
❌ **Cons**: Cold start no baseline

#### Cenário 2 (2 Réplicas) - ⭐⭐⭐⭐⭐
✅ **Pros**: Melhor latência baseline, warm start, throughput alto  
❌ **Cons**: +33% de custo baseline

#### Cenário 3 (Distribuído) - ⭐⭐⭐⭐
✅ **Pros**: Alta disponibilidade, resiliente a falhas de node  
❌ **Cons**: +85% custo, possível latência inter-node

#### Cenário 4 (Recursos Limitados) - ⭐⭐⭐
✅ **Pros**: Funciona com metade dos recursos, HPA compensa  
❌ **Cons**: CPU throttling, latência maior, mais pods necessários

#### Cenário 5 (Sem HPA) - ⭐⭐
✅ **Pros**: Simples, previsível, sem cold start  
❌ **Cons**: +81% custo, over-provisioning, sem elasticidade

---

## 🚀 Gerando Análise

### Automático (após executar cenários)
```bash
./scripts/run_scenario_comparison.sh --all
# Gera automaticamente ao final
```

### Manual (cenários já executados)
```bash
./scripts/run_scenario_comparison.sh --compare
# Ou diretamente:
python3 scripts/compare_scenarios.py
```

---

## 📊 Requisitos

- Python 3.8+
- matplotlib (`pip3 install matplotlib`)
- Resultados dos cenários em `results-scenario-{1-5}/`

---

## 🎓 Conclusão Esperada

A análise comparativa deve demonstrar:

1. **HPA é essencial**: Cenário 5 (sem HPA) é 81% mais caro com performance similar
2. **Warm start vale a pena**: Cenário 2 tem melhor latência por +33% custo
3. **HA tem custo**: Cenário 3 oferece resiliência por +85% custo
4. **Recursos limitados funcionam**: Cenário 4 compensa com mais pods
5. **Trade-offs claros**: Não há "melhor cenário", depende do objetivo

**Recomendação geral**: Cenário 1 (Base) ou 2 (Réplicas) para produção, com HPA sempre habilitado.
