# 🚀 GUIA DE EXECUÇÃO COMPLETA - TODOS OS TESTES

> **Este é o ÚNICO arquivo que você precisa ler para executar TUDO do zero ao fim.**

---

## 📌 O QUE ESTE GUIA FAZ

Executa **TODOS** os testes cobrindo **TODOS** os requisitos acadêmicos:

✅ **Cluster Kubernetes Multi-Node** (1 master + 2 workers)  
✅ **Prometheus instalado no K8s** (via Helm)  
✅ **Interface Web de Monitoramento** (Grafana com dashboard customizado)  
✅ **5 Cenários de Teste de Carga** (baseline, ramp, spike, stress, soak)  
✅ **Métricas e Gráficos** (análise automatizada com Python)  
✅ **Sistema de Checkpoints** (continua de onde parou em caso de erro)

---

## ⚡ EXECUÇÃO RÁPIDA (4 COMANDOS)

### 🔴 IMPORTANTE: Diferença entre os scripts

- **`./RUN_COMPLETE.sh`** = **SETUP DO AMBIENTE** (executar 1 vez)
  - Cria cluster Kubernetes multi-node
  - Instala Prometheus + Grafana
  - Faz build e deploy das aplicações
  - **Execute apenas UMA VEZ** ou após deletar o cluster

- **`./scripts/run_all_tests.sh all`** = **TESTES DE CARGA** (pode executar várias vezes)
  - Executa os 4 testes de carga
  - Coleta métricas e logs
  - **Pode executar QUANTAS VEZES QUISER** sem refazer o setup

---

### Primeira Execução (do zero):

```bash
# 1️⃣ Setup completo (cluster + apps + Prometheus + Grafana) - 5-10 min
#    ⚠️ Execute apenas UMA VEZ
./RUN_COMPLETE.sh

# 2️⃣ Em OUTRO terminal: Port-forward estável
#    ⚠️ Deixe rodando durante os testes
./scripts/stable_port_forward.sh

# 3️⃣ Executar TODOS os testes - 15-20 min
#    ✅ Pode executar VÁRIAS VEZES sem refazer o setup
./scripts/run_all_tests.sh all
# Aguarde 15s (ou pressione Enter) para executar stress e soak automaticamente

# 4️⃣ Gerar gráficos e análise
python3 scripts/analyze_results.py
```

### Execuções Subsequentes (cluster já existe):

```bash
# ❌ NÃO precisa executar ./RUN_COMPLETE.sh novamente!
# ✅ Apenas rode os testes quantas vezes quiser:

./scripts/stable_port_forward.sh     # Se não estiver rodando
./scripts/run_all_tests.sh all       # Testes novamente
python3 scripts/analyze_results.py   # Novos gráficos
```

✅ **Pronto!** Todos os resultados estarão em `results/`

---

## 📖 EXECUÇÃO DETALHADA (PASSO A PASSO)

### ETAPA 1: Preparação do Ambiente

```bash
# Garantir que está no diretório correto
cd atividade-final-pspd

# Verificar dependências
which minikube kubectl helm docker k6 python3
# Se algo faltar, instale antes de continuar
```

**Dependências necessárias:**
- minikube (versão 1.34+)
- kubectl (versão 1.30+)
- helm (versão 3.0+)
- docker (para builds)
- k6 (para testes de carga)
- python3 + pip (para análise)

---

### ETAPA 2: Criar Cluster Multi-Node

```bash
# Opção A: Script automatizado (RECOMENDADO)
./RUN_COMPLETE.sh
# Este script tem checkpoints - se falhar, pode executar novamente que continua de onde parou

# Opção B: Passo a passo manual
./scripts/setup_multinode_cluster.sh    # Cria cluster 1+2
./scripts/deploy.sh setup                # Deploy das apps
./scripts/deploy.sh monitoring           # Configura Prometheus
```

**O que acontece:**
1. Cria cluster minikube com 3 nós (1 master + 2 workers)
2. Instala Helm se não estiver presente
3. Instala kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
4. Faz build das 3 imagens Docker (gateway-p, service-a, service-b)
5. Carrega imagens em todos os nós do cluster
6. Faz deploy de todos os deployments, services, HPAs
7. Configura 3 ServiceMonitors para scraping automático
8. Expõe Prometheus (NodePort 30090) e Grafana (NodePort 31510)
9. Importa dashboard customizado no Grafana

**Tempo estimado:** 5-10 minutos (primeira vez)

**Validação:**
```bash
# Verificar cluster
minikube profile list
kubectl get nodes

# Verificar pods
kubectl get pods -n pspd
kubectl get pods -n monitoring

# Verificar serviços
kubectl get svc -n pspd
kubectl get svc -n monitoring

# Todos os pods devem estar Running/Completed
```

---

### ETAPA 3: Configurar Port-Forwards

```bash
# Em um TERMINAL SEPARADO, deixe rodando:
./scripts/stable_port_forward.sh
```

**O que faz:**
- Port-forward para Prometheus: `http://localhost:9090`
- Port-forward para Grafana: `http://localhost:3000`
- Port-forward para Gateway P: `http://localhost:8080`
- Auto-restart em caso de queda (útil durante testes pesados)

**Validação:**
```bash
# Em outro terminal:
curl http://localhost:8080          # Gateway P
curl http://localhost:9090/-/ready  # Prometheus
curl http://localhost:3000/api/health  # Grafana
```

---

### ETAPA 4: Acessar Grafana e Dashboard

1. **Abrir navegador:** `http://localhost:3000`
2. **Login:**
   - Usuário: `admin`
   - Senha: `admin` (pode pular alteração)
3. **Dashboard:**
   - Menu lateral → Dashboards → "PSPD - Microservices Observability"

**Painel do Dashboard (7 gráficos):**
- HTTP Request Rate (req/s)
- HTTP Request Duration P95 (ms)
- CPU Usage (%)
- Memory Usage (MB)
- Pod Replicas
- HTTP Error Rate (%)
- gRPC Request Duration P95 (ms)

---

### ETAPA 5: Executar TODOS os Testes

```bash
# TERMINAL PRINCIPAL (não o do port-forward):
./scripts/run_all_tests.sh all
```

**💡 Executar testes individuais:**

```bash
# Apenas um teste específico:
./scripts/run_all_tests.sh baseline   # 30s
./scripts/run_all_tests.sh ramp       # 90s
./scripts/run_all_tests.sh spike      # 30s
./scripts/run_all_tests.sh soak       # 11 min
```

**Sequência automática:**

1. **Baseline** (30s)
   - 10 VUs constantes
   - Validação: taxa erro < 1%, p95 < 500ms

2. **Ramp** (90s)
   - 10 → 150 VUs gradual
   - Validação: HPA escala pods

3. **Spike** (30s)
   - 10 → 200 VUs súbito
   - Validação: resiliência sob carga extrema (pode ter erros)

4. **Soak** (11 minutos) - *Aguarda 15s ou pressione Enter*
   - 50 VUs por 10 minutos
   - Validação: estabilidade prolongada

**Comportamento padrão:**
- Se não responder nada, **EXECUTA TUDO** automaticamente
- Para pular stress ou soak: digite `n` antes dos 15s

**Tempo total:** 15-20 minutos (com todos os testes)

**O que é coletado durante os testes:**
- Métricas JSON do k6 (`results/{test}/metrics.json`)
- Logs de execução (`results/{test}/output.txt`)
- Snapshots de pods antes/depois (`results/{test}/pod-metrics-{pre|post}.txt`)
- Status do HPA (`results/{test}/hpa-status-{pre|post}.txt`)
- Eventos do K8s (apenas spike: `results/{test}/events.txt`)

---

### ETAPA 6: Analisar Resultados

```bash
# Gerar gráficos e análise estatística
python3 scripts/analyze_results.py
```

**Saídas geradas em `results/plots/`:**

1. **response_times_comparison.png**
   - Comparação de latências (p50, p95, p99) entre todos os testes

2. **throughput_comparison.png**
   - Requests por segundo de cada teste

3. **error_rates.png**
   - Taxa de erro (%) por teste

4. **{test}_timeline.png** (para cada teste)
   - Evolução temporal: latência, throughput, erros

5. **hpa_scaling.png**
   - Evolução do número de réplicas durante os testes

6. **resource_usage.png**
   - CPU e memória dos pods ao longo do tempo

**Resumo em texto:** `results/test_summary.txt`

---

## 📊 RESULTADOS ESPERADOS

### Testes Sem Erros (baseline, ramp, spike, soak)

```
Baseline:  10 VUs × 30s   → p95 < 500ms, erro = 0%
Ramp:      10→150 VUs     → p95 < 1s,    erro = 0%, HPA escala
Spike:     10→200 VUs     → p95 < 2s,    erro < 10%, recuperação rápida
Soak:      50 VUs × 10min → p95 < 800ms, erro = 0%, sem memory leak
```

### Teste Stress (opcional, pode ter erros)

```
Stress:    10→200 VUs     → p95 < 2s, erro < 50%, identifica limite
```

**Indicadores de sucesso:**
- ✅ HPA escalou de 1 para 3+ réplicas durante ramp/spike
- ✅ Pods retornaram a 1 réplica após testes
- ✅ Taxa de erro = 0% em baseline, ramp e soak
- ✅ Taxa de erro < 10% no spike (carga extrema)
- ✅ P95 abaixo dos thresholds definidos
- ✅ Prometheus coletou métricas de todos os serviços
- ✅ Grafana mostra gráficos em tempo real

---

## 🔍 VERIFICAÇÃO E TROUBLESHOOTING

### Verificar Estado do Sistema

```bash
# Pods rodando
kubectl get pods -n pspd
# Deve mostrar: gateway-p, service-a, service-b (Running)

# HPA funcionando
kubectl get hpa -n pspd
# Deve mostrar 3 HPAs com TARGETS preenchidos

# Prometheus scraping
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus -c prometheus | grep "pspd"
# Deve mostrar scrapes bem-sucedidos

# ServiceMonitors
kubectl get servicemonitor -n pspd
# Deve mostrar: gateway-p-monitor, service-a-monitor, service-b-monitor
```

### Problemas Comuns

**1. Port-forward cai durante teste spike/stress**
- ✅ **Normal!** O script `stable_port_forward.sh` reinicia automaticamente
- Aguarde 5-10 segundos, ele reconecta sozinho

**2. "Serviço não acessível em http://localhost:8080"**
```bash
# Verificar se port-forward está rodando
ps aux | grep "port-forward"

# Se não estiver, executar em terminal separado:
./scripts/stable_port_forward.sh
```

**3. Pods não escalam durante ramp**
```bash
# Verificar HPA
kubectl describe hpa -n pspd

# Verificar metrics-server
kubectl top pods -n pspd

# Se métricas não aparecem, esperar 1-2 minutos (warm-up)
```

**4. Teste spike causa erros (~33%)**
- ✅ **Normal!** Spike de 200 VUs testa limite do sistema
- Sistema deve se recuperar após o pico
- Para relatório: mostre a capacidade de recuperação

**5. Teste stress causa muitos erros (>50%)**
- ✅ **Esperado!** Stress encontra o limite absoluto
- Use stress apenas para análise de capacidade máxima

**6. Grafana não carrega dashboard**
```bash
# Reimportar dashboard
./scripts/deploy.sh monitoring

# Ou acessar Grafana e importar manualmente:
# Dashboards → Import → Colar JSON de k8s/grafana-dashboard.json
```

---

## 📁 ESTRUTURA DE RESULTADOS

Após execução completa:

```
results/
├── baseline/
│   ├── metrics.json          # Dados brutos k6
│   ├── output.txt            # Log do teste
│   ├── pod-metrics-pre.txt   # Recursos antes
│   └── pod-metrics-post.txt  # Recursos depois
├── ramp/
├── spike/
│   └── events.txt            # Eventos K8s (HPA scaling)
├── stress/
├── soak/
├── plots/                    # GRÁFICOS GERADOS
│   ├── response_times_comparison.png
│   ├── throughput_comparison.png
│   ├── error_rates.png
│   ├── baseline_timeline.png
│   ├── ramp_timeline.png
│   ├── spike_timeline.png
│   ├── stress_timeline.png
│   ├── soak_timeline.png
│   ├── hpa_scaling.png
│   └── resource_usage.png
├── test_summary.txt          # Resumo estatístico
├── hpa-final.yaml            # Configuração HPA final
├── pods-final.txt            # Estado final dos pods
├── prometheus-metrics.txt    # Snapshot de métricas
└── gateway-logs.txt          # Logs das aplicações
```

---

## 🎯 CHECKLIST COMPLETO

### Antes de Iniciar
- [ ] Dependências instaladas (minikube, kubectl, helm, docker, k6, python3)
- [ ] Docker daemon rodando
- [ ] Pelo menos 8GB RAM disponível
- [ ] Pelo menos 20GB disco disponível

### Execução
- [ ] Cluster multi-node criado (1+2 nós)
- [ ] Prometheus instalado e rodando
- [ ] Grafana acessível com dashboard
- [ ] Port-forwards ativos (terminal separado)
- [ ] Teste baseline executado (0% erro)
- [ ] Teste ramp executado (HPA escalou)
- [ ] Teste spike executado (0% erro)
- [ ] Teste stress executado (limite encontrado)
- [ ] Teste soak executado (estabilidade confirmada)
- [ ] Análise Python executada (gráficos gerados)

### Validação Final
- [ ] 10+ arquivos PNG em `results/plots/`
- [ ] `test_summary.txt` com estatísticas
- [ ] Todos os testes com p95 dentro dos limites
- [ ] HPA escalou e voltou ao normal
- [ ] Prometheus coletando métricas de 3 serviços
- [ ] Grafana mostrando dados em tempo real

---

## 🎓 PARA O RELATÓRIO ACADÊMICO

**Use estes resultados:**

1. **Arquitetura:**
   - Diagrama do cluster multi-node (README.md)
   - Print do `kubectl get nodes`
   - Print do Grafana dashboard

2. **Monitoramento:**
   - Print do Prometheus Targets (todos UP)
   - Print do Grafana mostrando métricas
   - ServiceMonitors configurados

3. **Testes de Carga:**
   - Tabela comparativa de `test_summary.txt`
   - Gráficos de `results/plots/`
   - Foco em: baseline, ramp, spike, soak

4. **Escalabilidade:**
   - `hpa_scaling.png` mostrando auto-scaling
   - Prints de `kubectl get hpa` durante ramp
   - Comparação de latência 1 vs 3 réplicas

5. **Conclusões:**
   - Sistema escala automaticamente com HPA
   - Prometheus + Grafana permitem observabilidade completa
   - Cluster multi-node distribui carga entre workers
   - Todos os testes passaram nos thresholds

---

## 📞 COMANDOS ÚTEIS

### Executar Testes Individuais

```bash
# Todos os testes (15-20 min)
./scripts/run_all_tests.sh all

# Testes individuais:
./scripts/run_all_tests.sh baseline   # 30s - Carga constante
./scripts/run_all_tests.sh ramp       # 90s - Escalonamento gradual
./scripts/run_all_tests.sh spike      # 30s - Pico súbito
./scripts/run_all_tests.sh stress     # 90s - Limite máximo
./scripts/run_all_tests.sh soak       # 11min - Estabilidade prolongada
```

### Monitoramento em Tempo Real

```bash
# Ver logs em tempo real durante testes
kubectl logs -f -n pspd -l app=p

# Monitorar HPA
watch -n 2 kubectl get hpa -n pspd

# Ver eventos de scaling
kubectl get events -n pspd --sort-by='.lastTimestamp' | grep -i scale

# Consultar Prometheus direto
curl 'http://localhost:9090/api/v1/query?query=up'
```

### Gerenciamento do Cluster

```bash
# Reiniciar tudo do zero
minikube delete -p pspd-cluster
./RUN_COMPLETE.sh

# Parar cluster (sem deletar)
minikube stop -p pspd-cluster

# Iniciar cluster parado
minikube start -p pspd-cluster
```

---

## ✅ RESUMO: 4 COMANDOS PARA TUDO

### 🔴 Primeira Vez (ou após `minikube delete`):

```bash
# 1. Setup (UMA VEZ) - Cria cluster + instala Prometheus + deploy apps
./RUN_COMPLETE.sh

# 2. Port-forward (terminal separado) - Deixe rodando
./scripts/stable_port_forward.sh

# 3. Testes (pode executar VÁRIAS VEZES) - Coleta métricas
./scripts/run_all_tests.sh all

# 4. Análise (após cada execução de testes) - Gera gráficos
python3 scripts/analyze_results.py
```

### 🟢 Execuções Seguintes (cluster já existe):

```bash
# ❌ NÃO execute ./RUN_COMPLETE.sh novamente!
# ✅ Apenas os testes:

./scripts/run_all_tests.sh all       # Quantas vezes quiser
python3 scripts/analyze_results.py   # Atualizar gráficos
```

---

**Analogia simples:**
- `RUN_COMPLETE.sh` = **construir a casa** 🏗️ (uma vez)
- `run_all_tests.sh` = **testar a casa** 🔬 (quantas vezes quiser)

**Pronto! Você tem TUDO necessário para o trabalho acadêmico.** 🎓✨
