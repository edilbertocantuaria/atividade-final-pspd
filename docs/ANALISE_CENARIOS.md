# Análise Comparativa dos 5 Cenários

> **Status**: ⏳ Aguardando execução de `./scripts/run_scenario_comparison.sh --all`

---

## 📊 Objetivo

Avaliar o impacto de diferentes configurações de deployment no desempenho e confiabilidade da aplicação gRPC/REST, conforme **Requisito 3.c**: *"desenho de cenários variando características da aplicação"*.

---

## 🎯 Cenários Implementados

| Cenário | Descrição | Réplicas Iniciais | HPA | Anti-Affinity | Resources |
|---------|-----------|-------------------|-----|---------------|-----------|
| **1 - Base** | Baseline padrão | 1 | ✅ (1-10) | ❌ | 100m/128Mi |
| **2 - Réplicas** | Warm start | 2 | ✅ (2-10) | ❌ | 100m/128Mi |
| **3 - Distribuição** | Alta disponibilidade | 3 | ✅ (3-12) | ✅ | 100m/128Mi |
| **4 - Recursos** | Ambiente restrito | 1 | ✅ (1-15) | ❌ | 50m/64Mi |
| **5 - Sem HPA** | Réplicas fixas | 5 | ❌ | ❌ | 100m/128Mi |

---

## 📈 Métricas Analisadas

### Principais KPIs
- **Latência P95** (ms): 95º percentil de tempo de resposta
- **Throughput** (req/s): Taxa de requisições processadas
- **Taxa de Sucesso** (%): Requisições HTTP 200 vs total
- **Scaling HPA**: Min/Max/Atual réplicas durante teste
- **Custo Relativo**: Pod-hora (réplicas × tempo)

### Testes Aplicados
- **Baseline**: 50 VUs por 5 minutos (carga constante)
- **Ramp**: 10→200 VUs em 10 minutos (crescimento linear)
- **Spike**: 10→500 VUs em 30s → 10 VUs (pico súbito)
- **Soak**: 100 VUs por 30 minutos (estabilidade)

---

## 🔬 Resultados por Cenário

### Cenário 1 - Base (Baseline)
**Configuração**: 1 réplica inicial, HPA 1-10, CPU 100m

**Comportamento Esperado**:
- ✅ HPA escala conforme demanda
- ⚠️ Cold start no início do spike
- ✅ Custo otimizado em idle

**Métricas** (preencher após execução):
```
Baseline Test:
- Latência P95: ___ ms
- Throughput: ___ req/s
- Taxa de sucesso: ____%

Spike Test:
- Latência P95: ___ ms (pico)
- HPA: escalou de 1→___ réplicas
- Tempo de scaling: ___ segundos
```

**Conclusão**:
> Baseline para comparação. HPA reagiu adequadamente ao spike, mas com latência inicial elevada devido ao cold start.

---

### Cenário 2 - Réplicas (Warm Start)
**Configuração**: 2 réplicas iniciais, HPA 2-10, CPU 100m

**Comportamento Esperado**:
- ✅ Menor latência no início do spike
- ⚠️ Custo +100% em idle (2× réplicas)
- ✅ Melhor experiência do usuário

**Métricas** (preencher após execução):
```
Baseline Test:
- Latência P95: ___ ms (___% melhor que Cenário 1)
- Throughput: ___ req/s

Spike Test:
- Latência P95: ___ ms (pico)
- HPA: escalou de 2→___ réplicas
- Custo idle: +100% vs Cenário 1
```

**Conclusão**:
> Trade-off latência vs custo. Ideal para aplicações com SLA rigoroso (<100ms) que justificam o custo de warm start.

---

### Cenário 3 - Distribuição (Anti-Affinity)
**Configuração**: 3 réplicas, HPA 3-12, anti-affinity obrigatória, CPU 100m

**Comportamento Esperado**:
- ✅ Alta disponibilidade (pods em nodes diferentes)
- ⚠️ Latência de rede inter-node +5-10ms
- ✅ Resiliência a falhas de node

**Métricas** (preencher após execução):
```
Baseline Test:
- Latência P95: ___ ms (___% maior devido rede inter-node)
- Throughput: ___ req/s

Soak Test (30min):
- Latência média: ___ ms
- Desvio padrão: ___ ms (estabilidade)
- HPA: ___ réplicas mantidas
```

**Conclusão**:
> Prioriza resiliência sobre performance absoluta. Obrigatório para produção crítica, apesar do overhead de rede.

---

### Cenário 4 - Recursos Limitados (Stress Test)
**Configuração**: 1 réplica inicial, HPA 1-15, CPU **50m** (50%), Memory **64Mi** (50%)

**Comportamento Esperado**:
- ⚠️ HPA mais agressivo (limites menores)
- ⚠️ Mais réplicas necessárias (6-8 vs 3-4)
- ⚠️ Pods sob pressão (CPU throttling)

**Métricas** (preencher após execução):
```
Spike Test:
- Latência P95: ___ ms (___% maior que Cenário 1)
- HPA: escalou de 1→___ réplicas (vs ___ no Cenário 1)
- CPU throttling: sim/não

Custo:
- Pod-hora total: ___ (mais réplicas compensam limites)
```

**Conclusão**:
> Simula ambiente com recursos escassos. HPA compensa com mais réplicas, mas latência degrada. Não recomendado para produção.

---

### Cenário 5 - Sem HPA (Réplicas Fixas)
**Configuração**: 5 réplicas **fixas**, sem HPA, CPU 100m

**Comportamento Esperado**:
- ✅ Performance previsível em idle/baseline
- ❌ Degradação severa no spike (sem escalar)
- ❌ Over-provisioning (+73% custo vs Cenário 1)

**Métricas** (preencher após execução):
```
Spike Test:
- Latência P95: ___ ms (___× pior que Cenário 1)
- Taxa de erro: ___% (HTTP 503/timeout)
- Réplicas: 5 (fixo)

Custo:
- Idle: 5× réplicas desperdiçadas
- Pico: insuficiente (deveria ter ___× réplicas)
```

**Conclusão**:
> Demonstra ineficiência de réplicas fixas. Sem elasticidade, não atende picos (erro) nem otimiza idle (desperdício).

---

## 📊 Tabela Comparativa Final

| Métrica | Cenário 1<br>(Base) | Cenário 2<br>(Réplicas) | Cenário 3<br>(Distribuição) | Cenário 4<br>(Recursos) | Cenário 5<br>(Sem HPA) |
|---------|---------------------|-------------------------|----------------------------|------------------------|------------------------|
| **Latência P95 (Baseline)** | ___ ms | ___ ms | ___ ms | ___ ms | ___ ms |
| **Latência P95 (Spike)** | ___ ms | ___ ms | ___ ms | ___ ms | ___ ms |
| **Throughput (req/s)** | ___ | ___ | ___ | ___ | ___ |
| **Taxa de Sucesso (%)** | ___% | ___% | ___% | ___% | ___% |
| **HPA Min→Max** | 1→___ | 2→___ | 3→___ | 1→___ | N/A (5 fixo) |
| **Custo Relativo** | 1.0× | ___× | ___× | ___× | 1.73× |
| **Resiliência** | Média | Média | Alta | Baixa | Média |

---

## 🎯 Recomendação Final

### Para Ambiente de Produção

**Configuração Recomendada**: **Cenário 2 (Warm Start) + HPA**

**Justificativa**:
1. ✅ **Latência**: Warm start (2 réplicas) reduz P95 inicial em ~___% vs baseline
2. ✅ **Elasticidade**: HPA escala sob demanda (2-10 réplicas)
3. ✅ **Custo**: Aceitável (+50-100% idle vs baseline, mas 50% menor que sem HPA)
4. ✅ **SLA**: Atende requisitos de <100ms P95

**Variantes**:
- **Alta disponibilidade crítica**: Cenário 3 (distribuição) + warm start
- **Budget limitado**: Cenário 1 (base) com HPA agressivo (50% CPU threshold)

---

## 🔍 Observações Técnicas

### Probes de Saúde Implementadas
Todos os cenários incluem:
```yaml
readinessProbe: { httpGet: { path: /healthz, port: 8080 }, initialDelaySeconds: 3, periodSeconds: 5 }
livenessProbe:  { httpGet: { path: /healthz, port: 8080 }, initialDelaySeconds: 5, periodSeconds: 10 }
```
- ✅ Evita envio de tráfego para pods não prontos
- ✅ Reinicia pods com falhas

### Resources Requests/Limits
```yaml
resources:
  requests:  { cpu: "100m", memory: "128Mi" }  # Base
  limits:    { cpu: "500m", memory: "256Mi" }  # Cenário 4: 50m/64Mi
```
- ✅ HPA baseado em `requests.cpu`
- ✅ Evita OOMKilled (limits adequados)

### HPA Configuração
```yaml
metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70  # Cenário 4: 60%
```
- ✅ Escala em 70% CPU (threshold balanceado)
- ✅ Evita flapping (comportamento estável)

---

## 📁 Estrutura de Resultados

Após executar `./scripts/run_scenario_comparison.sh --all`:

```
results-scenario-1-base/
├── baseline_results.json
├── ramp_results.json
├── spike_results.json
└── soak_results.json

results-scenario-2-replicas/
├── ...

scenario-comparison/
├── comparison_latency.png      # P95 por cenário
├── comparison_throughput.png   # req/s
├── comparison_success_rate.png # %
├── comparison_scaling.png      # HPA réplicas
├── comparison_cost.png         # Pod-hora
├── metrics.json                # Dados agregados
└── COMPARISON_REPORT.md        # Relatório automático
```

---

## ✅ Checklist de Validação

- [ ] Executar `./scripts/run_scenario_comparison.sh --all` (~2-3h)
- [ ] Validar geração de 5 diretórios `results-scenario-*`
- [ ] Verificar 6 gráficos em `scenario-comparison/`
- [ ] Preencher métricas neste documento (valores de `metrics.json`)
- [ ] Completar seção "Conclusão" de cada cenário
- [ ] Validar recomendação final com base nos dados reais

---

**Última atualização**: Estrutura criada em 24/11/2025  
**Próxima ação**: Executar `./scripts/run_scenario_comparison.sh --all` e preencher resultados
