# Testes Modulares - Atividade Final PSPD

## 📁 Estrutura

```
test/
├── scenario_1/       # Baseline (1 replica + HPA 1-10)
├── scenario_2/       # Warm Start (2 replicas + HPA 2-10)
├── scenario_3/       # Distribution (3 replicas + anti-affinity + HPA 3-12)
├── scenario_4/       # Limited Resources (1 replica + 50% CPU/Mem + HPA 1-15)
└── scenario_5/       # No HPA (5 fixed replicas)

test_results/
├── scenario_1/
├── scenario_2/
├── scenario_3/
├── scenario_4/
└── scenario_5/
```

## 🚀 Execução

### Executar teste individual

```bash
# Exemplo: apenas o teste baseline do scenario 1
./test/scenario_1/baseline.sh

# Exemplo: apenas o teste spike do scenario 3
./test/scenario_3/spike.sh
```

### Executar todos os testes de um cenário

```bash
# Executa: baseline + ramp + spike + soak
./test/scenario_1/run_all.sh
./test/scenario_2/run_all.sh
./test/scenario_3/run_all.sh
./test/scenario_4/run_all.sh
./test/scenario_5/run_all.sh
```

### Executar todos os cenários (manual)

```bash
# Executar um por um
./test/scenario_1/run_all.sh
./test/scenario_2/run_all.sh
./test/scenario_3/run_all.sh
./test/scenario_4/run_all.sh
./test/scenario_5/run_all.sh
```

## 📊 Scripts Disponíveis

Cada cenário (`scenario_1` a `scenario_5`) contém:

| Script | Descrição | Duração |
|--------|-----------|---------|
| `00_setup.sh` | Faz deploy do cenário e prepara o ambiente | ~20s |
| `baseline.sh` | Teste baseline (carga constante) | 1m40s |
| `ramp.sh` | Teste de rampa (carga crescente) | 4min |
| `spike.sh` | Teste de pico (carga súbita) | 1min |
| `soak.sh` | Teste de resistência (carga prolongada) | 11m30s |
| `run_all.sh` | Executa todos os 4 testes acima | ~17min |

## 📊 Resultados

Os resultados são salvos em `test_results/scenario_X/`:

```
test_results/scenario_1/
├── baseline/
│   ├── metrics.json           # Métricas k6 (formato JSON)
│   ├── output.txt            # Saída completa do k6
│   ├── pod-metrics-pre.txt   # Métricas antes do teste
│   ├── pod-metrics-post.txt  # Métricas depois do teste
│   ├── hpa-status-pre.txt
│   ├── hpa-status-post.txt
│   ├── pods-status-pre.txt
│   └── pods-status-post.txt
├── ramp/
│   └── (mesma estrutura)
├── spike/
│   └── (mesma estrutura)
├── soak/
│   └── (mesma estrutura)
└── plots/                     # Gráficos gerados automaticamente
    ├── 01_latency_comparison.png
    ├── 02_throughput_comparison.png
    ├── 03_success_rate.png
    ├── 04_hpa_scaling.png
    ├── 05_resource_usage.png
    ├── 06_latency_percentiles.png
    └── SUMMARY_REPORT.txt
```

**Gráficos gerados automaticamente** ao executar `run_all.sh`.

### Gerar gráficos manualmente

Se você executou os testes individualmente (baseline.sh, ramp.sh, etc.) e quer gerar os gráficos depois:

```bash
# Gerar gráficos de um cenário específico
./scripts/generate_plots.sh 1

# Gerar gráficos de todos os cenários
./scripts/generate_plots.sh all
```

## ⚙️ Pré-requisitos

- Minikube rodando (`minikube status`)
- Namespace `pspd` criado (o script cria automaticamente)
- k6 instalado
- kubectl configurado

## 🔧 Troubleshooting

### Porta 8080 já em uso

```bash
pkill -f "port-forward.*pspd"
```

### Pods não ficam prontos

```bash
kubectl get pods -n pspd
kubectl describe pod <pod-name> -n pspd
```

### Limpar tudo

```bash
kubectl delete namespace pspd
pkill -f "port-forward.*pspd"
```

## 📋 Exemplo de Fluxo Completo

```bash
# 1. Testar apenas baseline no scenario 1
./test/scenario_1/baseline.sh

# 2. Se der certo, rodar todos os testes do scenario 1
./test/scenario_1/run_all.sh

# 3. Verificar resultados
ls -lh test_results/scenario_1/

# 4. Repetir para outros cenários conforme necessário
./test/scenario_2/run_all.sh
```

## ⏱️ Tempo Estimado

- **1 teste individual**: 1min - 11m30s (depende do teste)
- **1 cenário completo** (`run_all.sh`): ~17min
- **5 cenários completos**: ~1h25min

## 🎯 Vantagens da Estrutura Modular

✅ Executar apenas o teste que precisa  
✅ Depurar falhas específicas sem reexecutar tudo  
✅ Resultados organizados por cenário  
✅ Controle granular sobre cada etapa  
✅ Fácil paralelização (rodar cenários em terminais diferentes)
