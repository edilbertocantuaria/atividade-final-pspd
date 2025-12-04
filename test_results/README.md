# Test Results

Esta pasta contém os resultados dos testes de carga e observabilidade dos 5 cenários.

## 📁 Estrutura

```
test_results/
├── scenario_1/          # Cenário 1: Baseline (1 replica + HPA 1-10)
├── scenario_2/          # Cenário 2: Warm Start (2 replicas + HPA 2-10)
├── scenario_3/          # Cenário 3: Distribution (3 replicas + anti-affinity + HPA 3-12)
├── scenario_4/          # Cenário 4: Limited Resources (1 replica + 50% CPU/Mem + HPA 1-15)
├── scenario_5/          # Cenário 5: No HPA (5 fixed replicas, no autoscaling)
└── scenario-comparison/ # Análise comparativa entre todos os cenários
```

## 📊 Conteúdo de cada cenário

Cada cenário (`scenario_X/`) contém:

```
scenario_X/
├── baseline/       # Resultados do teste baseline (10 VUs, 100s)
├── ramp/          # Resultados do teste ramp (1-150 VUs, 4min)
├── spike/         # Resultados do teste spike (1-200 VUs, 70s)
├── soak/          # Resultados do teste soak (50 VUs, 10min)
└── plots/         # 📈 Gráficos e relatórios gerados
    ├── 01_latency_comparison.png
    ├── 02_throughput_comparison.png
    ├── 03_success_rate.png
    ├── 04_hpa_scaling.png
    ├── 05_resource_usage.png
    ├── 06_latency_percentiles.png
    └── SUMMARY_REPORT.txt
```

## ⚠️ Arquivos ignorados pelo Git

Para reduzir o tamanho do repositório, os seguintes arquivos **NÃO são versionados**:
- `metrics.json` - Métricas detalhadas do k6 (50-100MB por teste)
- `output.txt` - Saída completa do k6
- `*.txt` nos diretórios de testes (hpa-status, pod-metrics, etc.)

Apenas a pasta **`plots/`** é versionada, contendo:
- ✅ Gráficos PNG gerados
- ✅ Relatório resumido (SUMMARY_REPORT.txt)

## 🚀 Como gerar os resultados

### Para um cenário específico:
```bash
# Executar testes
cd test/scenario_1
./run_all.sh

# Gerar gráficos
./scripts/generate_plots.sh 1
```

### Para todos os cenários:
```bash
# Executar todos os testes (todos os 5 cenários)
./test/run_all_scenarios.sh

# Gerar comparação entre cenários
python3 scripts/compare_scenarios.py
```

## 📈 Análise comparativa

A pasta `scenario-comparison/` contém:
- Gráficos comparativos entre os 5 cenários
- Radar chart multi-dimensional
- Análise de custo estimado
- Relatório comparativo completo

Para gerar:
```bash
python3 scripts/compare_scenarios.py
```

## 🔍 Visualização dos resultados

```bash
# Ver relatório de um cenário
cat test_results/scenario_1/plots/SUMMARY_REPORT.txt

# Ver comparação entre cenários
cat test_results/scenario-comparison/SCENARIO_COMPARISON_REPORT.txt

# Abrir pasta de gráficos
xdg-open test_results/scenario_1/plots/
```
