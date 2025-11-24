# Guia de Execução Completa - Passo a Passo

Este guia garante a execução perfeita de todos os componentes do projeto.

## 📋 Pré-requisitos

Verifique se todas as ferramentas estão instaladas:

```bash
# Verificar versões
minikube version
kubectl version --client
docker --version
k6 version
python3 --version
```

## 🚀 Passo 1: Preparar o Cluster

### 1.1. Verificar/Iniciar Minikube

```bash
# Verificar status
minikube status

# Se não estiver rodando, iniciar
minikube start --cpus=4 --memory=8192 --driver=docker

# Habilitar addons necessários
minikube addons enable ingress
minikube addons enable metrics-server
```

### 1.2. Verificar Contexto Kubernetes

```bash
# Confirmar que está usando o contexto correto
kubectl config current-context

# Deve retornar: minikube
```

## 🏗️ Passo 2: Build das Imagens Docker

```bash
cd /home/edilberto/pspd/atividade-final-pspd

# Executar script de build
./scripts/build_images.sh

# Verificar imagens criadas
minikube image ls | grep -E "(a-service|b-service|p-gateway)"
```

**Saída esperada**:
```
docker.io/library/a-service:local
docker.io/library/b-service:local
docker.io/library/p-gateway:local
```

## 📦 Passo 3: Deploy da Aplicação

### 3.1. Deploy dos Serviços

```bash
# Executar script de deploy
./scripts/deploy.sh

# Aguardar todos os pods ficarem prontos (pode levar 1-2 minutos)
kubectl wait --for=condition=ready pod --all -n pspd --timeout=180s
```

### 3.2. Verificar Deployment

```bash
# Verificar pods
kubectl get pods -n pspd

# Verificar services
kubectl get svc -n pspd

# Verificar HPA
kubectl get hpa -n pspd
```

**Saída esperada**:
```
NAME                        READY   STATUS    RESTARTS   AGE
a-deploy-xxxxxxxxxx-xxxxx   1/1     Running   0          Xm
b-deploy-xxxxxxxxxx-xxxxx   1/1     Running   0          Xm
p-deploy-xxxxxxxxxx-xxxxx   1/1     Running   0          Xm
```

## 🔍 Passo 4: Verificar Métricas

### 4.1. Verificar Endpoints de Métricas

```bash
# Port-forward para o Gateway P
kubectl port-forward -n pspd svc/p-service 8080:80 > /dev/null 2>&1 &
PF_PID=$!

# Aguardar port-forward estar pronto
sleep 2

# Testar endpoint de métricas do Gateway P
curl -s http://localhost:8080/metrics | head -20

# Testar endpoint da aplicação
curl -s http://localhost:8080/

# Matar port-forward
kill $PF_PID 2>/dev/null
```

### 4.2. Verificar Métricas dos Services

```bash
# Service A
kubectl port-forward -n pspd svc/a-service 9101:9101 > /dev/null 2>&1 &
PF_A=$!
sleep 2
curl -s http://localhost:9101/metrics | grep grpc_server
kill $PF_A 2>/dev/null

# Service B
kubectl port-forward -n pspd svc/b-service 9102:9102 > /dev/null 2>&1 &
PF_B=$!
sleep 2
curl -s http://localhost:9102/metrics | grep grpc_server
kill $PF_B 2>/dev/null
```

## 📊 Passo 5: Executar Testes de Carga

### 5.1. Preparar Ambiente de Testes

```bash
# Iniciar port-forward em background
kubectl port-forward -n pspd svc/p-service 8080:80 > /tmp/pf.log 2>&1 &
PF_PID=$!

# Aguardar estabilização
sleep 5

# Verificar conectividade
curl -s http://localhost:8080/ | jq .
```

### 5.2. Executar Suite Completa de Testes

```bash
# Limpar resultados anteriores (opcional)
rm -rf results/baseline results/ramp results/spike results/soak
mkdir -p results/{baseline,ramp,spike,soak}

# Executar todos os testes
BASE_URL=http://localhost:8080 ./scripts/run_all_tests.sh
```

**Tempo estimado**: ~20 minutos
- Baseline: 2 min
- Ramp: 4 min  
- Spike: 2 min
- Soak: 11 min
- Coleta de métricas entre testes: ~3 min total

### 5.3. Monitorar Execução em Tempo Real

Em outro terminal, execute:

```bash
cd /home/edilberto/pspd/atividade-final-pspd
./scripts/monitor.sh
```

Você verá:
- Status dos pods
- Uso de CPU/Memory
- Réplicas do HPA
- Atualização a cada 5 segundos

## 📈 Passo 6: Gerar Análise e Gráficos

### 6.1. Executar Análise

```bash
# Gerar gráficos comparativos
python3 scripts/analyze_results.py
```

**Saída esperada**:
```
✅ Métricas coletadas de 4 cenário(s)
✅ Gráfico salvo: results/plots/01_latency_comparison.png
✅ Gráfico salvo: results/plots/02_throughput_comparison.png
✅ Gráfico salvo: results/plots/03_success_rate.png
✅ Gráfico salvo: results/plots/04_hpa_scaling.png
✅ Gráfico salvo: results/plots/05_resource_usage.png
✅ Gráfico salvo: results/plots/06_latency_percentiles.png
✅ Relatório salvo: results/plots/SUMMARY_REPORT.txt
```

### 6.2. Visualizar Resultados

```bash
# Ver relatório resumido
cat results/plots/SUMMARY_REPORT.txt

# Abrir gráficos (se tiver interface gráfica)
xdg-open results/plots/01_latency_comparison.png 2>/dev/null
```

## 🧹 Passo 7: Limpeza (Opcional)

### 7.1. Parar Port-Forward

```bash
# Encontrar e matar processos de port-forward
pkill -f "kubectl port-forward"
```

### 7.2. Resetar Deployment (manter cluster)

```bash
# Deletar apenas os recursos da aplicação
kubectl delete namespace pspd
```

### 7.3. Parar Cluster Completo

```bash
# Parar minikube
minikube stop

# Ou deletar completamente
minikube delete
```

## ✅ Checklist de Verificação

Marque cada item conforme for completando:

- [ ] Minikube rodando com addons (ingress, metrics-server)
- [ ] 3 imagens Docker criadas (a-service, b-service, p-gateway)
- [ ] 3 pods rodando em status Ready
- [ ] HPA configurado (3 instâncias: p-hpa, a-hpa, b-hpa)
- [ ] Métricas acessíveis em /metrics (Gateway P, Service A, Service B)
- [ ] Endpoint da aplicação respondendo (http://localhost:8080/)
- [ ] 4 testes de carga executados (baseline, ramp, spike, soak)
- [ ] Métricas coletadas em results/{baseline,ramp,spike,soak}/
- [ ] 6 gráficos gerados em results/plots/
- [ ] Relatório resumido disponível (SUMMARY_REPORT.txt)

## 🐛 Troubleshooting

### Pods não iniciam

```bash
# Ver logs do pod com problema
kubectl logs -n pspd <pod-name>

# Descrever pod para ver eventos
kubectl describe pod -n pspd <pod-name>

# Reconstruir imagem e redeployar
./scripts/build_images.sh
kubectl rollout restart deployment -n pspd p-deploy a-deploy b-deploy
```

### Port-forward morre durante testes

```bash
# Matar processos antigos
pkill -f "kubectl port-forward"

# Reiniciar
kubectl port-forward -n pspd svc/p-service 8080:80 &
sleep 3

# Testar conectividade
curl http://localhost:8080/
```

### HPA mostra <unknown> em TARGETS

Isso é normal logo após o deploy. Aguarde 30-60 segundos para o metrics-server coletar dados.

```bash
# Forçar coleta de métricas
kubectl top pods -n pspd

# Verificar novamente
kubectl get hpa -n pspd
```

### k6 retorna erro de conexão

```bash
# Verificar se port-forward está ativo
ps aux | grep "port-forward"

# Testar conectividade manual
curl -v http://localhost:8080/

# Se não responder, reiniciar port-forward
```

### Análise falha por falta de dados

```bash
# Verificar se os arquivos de resultados existem
ls -lh results/baseline/output.txt
ls -lh results/ramp/output.txt
ls -lh results/spike/output.txt

# Se faltarem, reexecutar os testes específicos
cd load
k6 run baseline.js --out json=../results/baseline/metrics.json | tee ../results/baseline/output.txt
```

## 📞 Ordem Recomendada de Execução

Para execução perfeita do zero:

```bash
# 1. Preparar cluster
minikube start --cpus=4 --memory=8192
minikube addons enable ingress metrics-server

# 2. Build
./scripts/build_images.sh

# 3. Deploy
./scripts/deploy.sh
kubectl wait --for=condition=ready pod --all -n pspd --timeout=180s

# 4. Iniciar port-forward
kubectl port-forward -n pspd svc/p-service 8080:80 &
sleep 5

# 5. Executar testes (em outro terminal, abra ./scripts/monitor.sh)
BASE_URL=http://localhost:8080 ./scripts/run_all_tests.sh

# 6. Gerar análise
python3 scripts/analyze_results.py

# 7. Ver resultados
cat results/plots/SUMMARY_REPORT.txt
```

## 🎯 Métricas de Sucesso

Se tudo estiver funcionando perfeitamente, você deve ver:

- **Baseline**: ~150 req/s, latência p95 < 25ms, 100% sucesso
- **Ramp**: HPA escalando de 1→3+ réplicas, latência aumenta mas mantém < 500ms
- **Spike**: Pico de latência, HPA reagindo com delay, possíveis timeouts
- **Soak**: Estabilidade por 10 minutos, uso de recursos constante

---

**Última atualização**: 23/11/2025
