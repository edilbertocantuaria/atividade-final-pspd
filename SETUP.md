# Atividade Final - Projeto de Observabilidade K8s

## O que foi adaptado

### Da atividade-extraclasse-1-pspd
✅ Arquitetura de microserviços gRPC (Gateway P, Service A, Service B)
✅ Manifestos Kubernetes base
✅ Estrutura de testes de carga com k6

### Da atividade-extraclasse-2-pspd
✅ Metodologia de testes (baseline + variações)
✅ Estrutura de scripts de automação
✅ Organização de resultados e relatórios

## Principais Mudanças Implementadas

### 1. Instrumentação com Prometheus
- **Gateway P**: Adicionado `prom-client` com métricas HTTP e gRPC client
- **Service A/B**: Adicionado `prometheus_client` com métricas gRPC server
- Todos os serviços expõem endpoint `/metrics`

### 2. Manifestos K8s Melhorados
- Adicionadas portas de métricas nos Deployments
- Configurados `resources.requests` e `resources.limits`
- Labels padronizados para ServiceMonitor

### 3. Monitoramento
- **ServiceMonitor**: Configuração para Prometheus Operator coletar métricas
- **HPA**: Autoscaling baseado em CPU/memória para P, A e B

### 4. Testes de Carga Expandidos
- `baseline.js`: Teste de referência (10 VUs, 2min)
- `ramp.js`: Teste de carga crescente (10→150 VUs)
- `spike.js`: Teste de pico (10→200 VUs)
- `soak.js`: Teste de resistência (50 VUs, 10min)

### 5. Scripts de Automação
- `build_images.sh`: Build de todas as imagens
- `deploy.sh`: Deploy completo no K8s
- `run_all_tests.sh`: Execução de todos os cenários k6
- `collect_metrics.sh`: Coleta de métricas do Prometheus

## Estrutura Pronta

```
atividade-final-pspd/
├── gateway_p_node/      ✅ Instrumentado com métricas
├── services/
│   ├── a_py/            ✅ Instrumentado com métricas
│   └── b_py/            ✅ Instrumentado com métricas
├── k8s/
│   ├── *.yaml           ✅ Manifestos com resources e labels
│   └── monitoring/      ✅ ServiceMonitor + HPA
├── load/                ✅ 4 cenários de teste
├── scripts/             ✅ Automação completa
├── results/             ✅ Estrutura para armazenar dados
└── README.md            ✅ Documentação completa
```

## Próximos Passos

1. **Ambiente Kubernetes**
   - [ ] Provisionar cluster multi-node (kubeadm, kops, ou cloud provider)
   - [ ] Instalar Prometheus Operator
   - [ ] Configurar kubectl

2. **Deploy e Validação**
   - [ ] Build das imagens: `./scripts/build_images.sh`
   - [ ] Deploy: `./scripts/deploy.sh`
   - [ ] Verificar métricas: acessar `http://<gateway>/metrics`

3. **Testes Baseline**
   - [ ] Executar `k6 run load/baseline.js`
   - [ ] Validar coleta no Prometheus
   - [ ] Documentar métricas de referência

4. **Cenários de Teste**
   - [ ] Cenário 1: Baseline (1-1-1)
   - [ ] Cenário 2: Scale P (3-1-1)
   - [ ] Cenário 3: Scale A/B (1-3-3)
   - [ ] Cenário 4: Autoscaling ativo
   - [ ] Cenário 5: Multi-node distribution
   - [ ] Cenário 6: Resource limits agressivos
   - [ ] Cenário 7: Fault injection

5. **Análise e Relatório**
   - [ ] Gerar gráficos comparativos
   - [ ] Análise de latência (p50/p95/p99)
   - [ ] Análise de throughput
   - [ ] Análise de uso de recursos
   - [ ] Relatório final consolidado

## Queries PromQL Essenciais

```promql
# Throughput
rate(http_requests_total{namespace="pspd"}[1m])

# Latência p95
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[1m]))

# CPU por pod
rate(container_cpu_usage_seconds_total{namespace="pspd",pod=~".*"}[1m])

# Réplicas ativas
kube_deployment_status_replicas_available{namespace="pspd"}
```

## Notas Importantes

- **ServiceMonitor**: Requer Prometheus Operator instalado
- **HPA**: Requer metrics-server no cluster
- **k6**: Instalar via `brew install k6` (macOS) ou equivalente
- **Multi-node**: Ajustar `nodeSelector`/`nodeAffinity` nos Deployments conforme cluster real
