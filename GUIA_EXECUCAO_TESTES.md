#!/bin/bash
# Guia de Execução dos Testes de Observabilidade
# Execute este arquivo para referência, não como script automatizado

cat << 'EOF'

╔══════════════════════════════════════════════════════════════╗
║  GUIA DE EXECUÇÃO - TESTES DE OBSERVABILIDADE K8S           ║
╚══════════════════════════════════════════════════════════════╝

PREPARAÇÃO (Terminal 1):
═══════════════════════════════════════════════════════════════
□ Verificar cluster: kubectl get pods -n pspd
□ Port-forward ativo: curl http://localhost:8080/healthz
□ Criar diretório: mkdir -p results/{baseline,ramp,spike,soak}

═══════════════════════════════════════════════════════════════
CENÁRIO 1: BASELINE (Configuração Base - 1 réplica cada)
═══════════════════════════════════════════════════════════════

[Terminal 1] Executar teste:
  BASE_URL=http://localhost:8080 k6 run \
    --out json=results/baseline/metrics.json \
    load/baseline.js | tee results/baseline/output.txt

[Terminal 2] Monitorar HPAs (paralelo):
  watch -n 2 'kubectl get hpa -n pspd'

[Terminal 3] Monitorar Pods (paralelo):
  watch -n 2 'kubectl get pods -n pspd -o wide'

[Terminal 4] Ver logs (paralelo):
  kubectl logs -f -n pspd -l app=p

[Durante o teste] Capturar métricas:
  # Em outro terminal, durante os últimos 30s do teste:
  kubectl top pods -n pspd > results/baseline/pod-metrics.txt
  kubectl get hpa -n pspd > results/baseline/hpa-status.txt

[Após teste] Aguardar estabilização:
  sleep 30

═══════════════════════════════════════════════════════════════
CENÁRIO 2: RAMP (Carga Crescente 10→150 VUs)
═══════════════════════════════════════════════════════════════

[Terminal 1] Executar teste:
  BASE_URL=http://localhost:8080 k6 run \
    --out json=results/ramp/metrics.json \
    load/ramp.js | tee results/ramp/output.txt

[Observação] Nos terminais 2 e 3:
  - Observe o HPA aumentando target de CPU
  - Veja novos pods sendo criados quando CPU > 70%
  - Anote em que momento o scaling aconteceu

[Durante pico] Capturar estado:
  # Quando VUs atingir ~100-150:
  kubectl top pods -n pspd > results/ramp/pod-metrics-peak.txt
  kubectl get hpa -n pspd > results/ramp/hpa-peak.txt
  kubectl get pods -n pspd -o wide > results/ramp/pods-scaled.txt

[Após teste] Aguardar scale-down:
  # Observe pods sendo removidos após carga diminuir
  sleep 60

═══════════════════════════════════════════════════════════════
CENÁRIO 3: SPIKE (Pico Súbito 10→200 VUs)
═══════════════════════════════════════════════════════════════

[Terminal 1] Executar teste:
  BASE_URL=http://localhost:8080 k6 run \
    --out json=results/spike/metrics.json \
    load/spike.js | tee results/spike/output.txt

[Observação] Impacto do spike:
  - Taxa de erro aumenta? (threshold: < 10%)
  - Latência p95/p99 durante spike
  - Tempo para HPA reagir

[Durante spike] Capturar:
  kubectl top pods -n pspd > results/spike/pod-metrics-spike.txt
  kubectl get events -n pspd --sort-by='.lastTimestamp' | tail -20 \
    > results/spike/events.txt

[Após teste] Aguardar:
  sleep 30

═══════════════════════════════════════════════════════════════
CENÁRIO 4: SOAK (OPCIONAL - 50 VUs por 10min)
═══════════════════════════════════════════════════════════════

[Terminal 1] Executar teste:
  BASE_URL=http://localhost:8080 k6 run \
    --out json=results/soak/metrics.json \
    load/soak.js | tee results/soak/output.txt

[Observação] Procurar por:
  - Memory leaks (uso de memória crescente)
  - CPU throttling contínuo
  - Restarts de containers
  - Degradação de performance ao longo do tempo

[A cada 2 min] Capturar snapshots:
  kubectl top pods -n pspd >> results/soak/pod-metrics-timeline.txt
  date >> results/soak/pod-metrics-timeline.txt

═══════════════════════════════════════════════════════════════
ANÁLISE PÓS-TESTES
═══════════════════════════════════════════════════════════════

[Métricas de Aplicação] Via Prometheus/Métricas do Gateway:
  curl http://localhost:8080/metrics > results/final-metrics.txt

[Métricas K8s] Estado final:
  kubectl get hpa -n pspd -o yaml > results/hpa-final.yaml
  kubectl top pods -n pspd > results/pods-final.txt
  kubectl describe hpa -n pspd > results/hpa-describe.txt

[Events] Histórico de eventos:
  kubectl get events -n pspd --sort-by='.lastTimestamp' \
    > results/events-history.txt

[Logs] Extrair logs completos:
  kubectl logs -n pspd -l app=p --tail=1000 > results/gateway-logs.txt
  kubectl logs -n pspd -l app=a --tail=500 > results/service-a-logs.txt
  kubectl logs -n pspd -l app=b --tail=500 > results/service-b-logs.txt

═══════════════════════════════════════════════════════════════
ANÁLISE COMPARATIVA
═══════════════════════════════════════════════════════════════

Extrair métricas-chave de cada teste:

  grep "http_req_duration" results/*/output.txt
  grep "http_reqs" results/*/output.txt
  grep "checks" results/*/output.txt

Comparar:
  - Baseline: latência base sem carga
  - Ramp: comportamento do autoscaling
  - Spike: resiliência a picos
  - Soak: estabilidade longo prazo

═══════════════════════════════════════════════════════════════
CENÁRIOS AVANÇADOS (Após testes básicos)
═══════════════════════════════════════════════════════════════

A) Testar com mais réplicas:
   kubectl scale deployment/p-deploy --replicas=3 -n pspd
   # Re-executar baseline e comparar

B) Simular falha:
   kubectl delete pod -n pspd -l app=a
   # Durante teste ramp, observar recuperação

C) Resource limits agressivos:
   kubectl set resources deployment/p-deploy \
     --limits=cpu=200m,memory=128Mi -n pspd
   # Re-executar spike

D) Desabilitar autoscaling:
   kubectl delete hpa -n pspd --all
   # Re-executar ramp, comparar com/sem HPA

═══════════════════════════════════════════════════════════════
LIMPEZA
═══════════════════════════════════════════════════════════════

Após todos os testes:
  kubectl delete namespace pspd
  minikube stop

Manter dados:
  tar -czf results-$(date +%Y%m%d-%H%M).tar.gz results/

EOF
