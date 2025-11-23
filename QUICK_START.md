# Quick Start - Execução de Testes

## 🎯 Resumo: Como Executar

### Opção 1: Automatizado (Recomendado para primeira execução)

```bash
# Terminal Único
cd /home/edilberto/pspd/atividade-final-pspd
BASE_URL=http://localhost:8080 ./scripts/run_all_tests.sh
```

**O que acontece:**
- Executa baseline → ramp → spike sequencialmente
- Captura métricas K8s antes/depois de cada teste
- Aguarda estabilização entre testes (30-60s)
- Pergunta se quer executar soak (opcional, 11min)
- Gera relatório comparativo ao final

---

### Opção 2: Manual com Monitoramento (Recomendado para análise profunda)

#### Setup Inicial

```bash
# Terminal 1 - Port-forward (manter rodando)
kubectl port-forward -n pspd svc/p-svc 8080:80
```

#### Cenário 1: Baseline

```bash
# Terminal 2 - Monitoramento em tempo real
./scripts/monitor.sh pspd 2

# Terminal 3 - Executar teste
cd /home/edilberto/pspd/atividade-final-pspd
BASE_URL=http://localhost:8080 k6 run \
  --out json=results/baseline/metrics.json \
  load/baseline.js | tee results/baseline/output.txt
```

**Observar no Terminal 2:**
- CPU/Memory permanecem baixos (~10-30%)
- Nenhum scaling acontece
- Latência p95 < 10ms

#### Cenário 2: Ramp (Testar Autoscaling)

```bash
# Terminal 3 - Executar teste de rampa
BASE_URL=http://localhost:8080 k6 run \
  --out json=results/ramp/metrics.json \
  load/ramp.js | tee results/ramp/output.txt
```

**Observar no Terminal 2:**
- ⏱️ Min 0-1: CPU começa a subir
- ⏱️ Min 1-2: CPU atinge ~70%, HPA detecta
- ⏱️ Min 2-3: Novos pods são criados (PENDING → RUNNING)
- ⏱️ Min 3-4: Carga distribuída, CPU normaliza
- ⏱️ Após teste: Scale-down gradual (60s de stabilization)

**Capturar durante pico:**
```bash
# Terminal 4 - Quando VUs atingir ~100-150
kubectl top pods -n pspd
kubectl get hpa -n pspd
```

#### Cenário 3: Spike (Testar Resiliência)

```bash
# Terminal 3 - Executar spike
BASE_URL=http://localhost:8080 k6 run \
  --out json=results/spike/metrics.json \
  load/spike.js | tee results/spike/output.txt
```

**Observar:**
- Taxa de erro (deve ser < 10%)
- Latência durante spike (p95 pode subir para ~2s)
- HPA pode não reagir a tempo (spike é rápido demais)

---

### Opção 3: Testes Individuais

```bash
# Apenas baseline
k6 run -e BASE_URL=http://localhost:8080 load/baseline.js

# Apenas ramp
k6 run -e BASE_URL=http://localhost:8080 load/ramp.js

# Apenas spike
k6 run -e BASE_URL=http://localhost:8080 load/spike.js

# Apenas soak (11min)
k6 run -e BASE_URL=http://localhost:8080 load/soak.js
```

---

## 📊 Configuração de Terminais para Análise Completa

### Terminal 1: Port-forward (deixar rodando)
```bash
kubectl port-forward -n pspd svc/p-svc 8080:80
```

### Terminal 2: Monitor geral (script automatizado)
```bash
./scripts/monitor.sh pspd 2
```

### Terminal 3: Execução de testes
```bash
BASE_URL=http://localhost:8080 k6 run load/ramp.js
```

### Terminal 4: Logs em tempo real
```bash
kubectl logs -f -n pspd -l app=p --tail=50
```

### Terminal 5 (Opcional): Watch específico
```bash
# Opção A - Ver apenas HPAs
watch -n 2 'kubectl get hpa -n pspd'

# Opção B - Ver apenas pods
watch -n 2 'kubectl get pods -n pspd -o wide'

# Opção C - Ver métricas
watch -n 5 'kubectl top pods -n pspd'
```

---

## 🔍 Análise Pós-Teste

### Ver resultados consolidados
```bash
# Latências por teste
grep "http_req_duration.*avg" results/*/output.txt

# Throughput por teste
grep "http_reqs\.*:" results/*/output.txt

# Taxas de sucesso
grep "checks.*100\.00%" results/*/output.txt
```

### Verificar comportamento do HPA
```bash
# Histórico de decisões do HPA
cat results/hpa-describe.txt

# Estado final
cat results/hpa-final.yaml

# Eventos de scaling
cat results/events-history.txt | grep -i "scaled"
```

### Ver métricas Prometheus
```bash
# Todas as métricas
cat results/prometheus-metrics.txt

# Apenas métricas HTTP
grep "^http_" results/prometheus-metrics.txt

# Apenas métricas gRPC
grep "^grpc_" results/prometheus-metrics.txt
```

---

## 🧪 Cenários Avançados

### A) Comparar com/sem Autoscaling

```bash
# 1. Testar COM autoscaling (default)
BASE_URL=http://localhost:8080 k6 run load/ramp.js | tee results/with-hpa.txt

# 2. Desabilitar HPA
kubectl delete hpa -n pspd --all

# 3. Testar SEM autoscaling
BASE_URL=http://localhost:8080 k6 run load/ramp.js | tee results/without-hpa.txt

# 4. Comparar latências
grep "http_req_duration" results/with-hpa.txt results/without-hpa.txt
```

### B) Testar Recuperação de Falhas

```bash
# Terminal 1 - Iniciar teste longo
BASE_URL=http://localhost:8080 k6 run load/soak.js

# Terminal 2 - Após 2min, deletar um pod
kubectl delete pod -n pspd -l app=a

# Terminal 3 - Observar recuperação
watch -n 1 'kubectl get pods -n pspd'

# Análise: verificar se houve pico de erros nos logs do k6
```

### C) Escalar Manualmente e Testar

```bash
# 1. Escalar Gateway P para 3 réplicas
kubectl scale deployment/p-deploy --replicas=3 -n pspd

# 2. Aguardar pods ficarem ready
kubectl wait --for=condition=ready pod -l app=p -n pspd --timeout=60s

# 3. Executar baseline e comparar throughput
BASE_URL=http://localhost:8080 k6 run load/baseline.js | tee results/scaled-3.txt

# 4. Voltar para 1 réplica
kubectl scale deployment/p-deploy --replicas=1 -n pspd
```

---

## 📝 Checklist de Execução

- [ ] Port-forward ativo (Terminal 1)
- [ ] Monitor rodando (Terminal 2)
- [ ] Cluster estável (aguardar 60s após deploy)
- [ ] Teste baseline executado
- [ ] Teste ramp executado (observar scaling)
- [ ] Teste spike executado (observar resiliência)
- [ ] (Opcional) Teste soak executado
- [ ] Métricas capturadas
- [ ] Logs exportados
- [ ] Resultados comparados

---

## 🆘 Troubleshooting

**Port-forward parou:**
```bash
# Matar processos antigos
pkill -f "port-forward.*pspd"

# Reiniciar
kubectl port-forward -n pspd svc/p-svc 8080:80
```

**Métricas não aparecem:**
```bash
# Aguardar 60s após iniciar cluster
# Verificar metrics-server
kubectl top nodes
kubectl top pods -n pspd
```

**HPA não está escalando:**
```bash
# Verificar se metrics-server está rodando
kubectl get deployment metrics-server -n kube-system

# Ver motivo
kubectl describe hpa -n pspd

# Forçar atualização
kubectl patch hpa p-hpa -n pspd -p '{"spec":{"minReplicas":1}}'
```

**k6 não encontrado:**
```bash
# Instalar k6
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6
```
