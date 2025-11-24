# Cenário 2: Réplicas Aumentadas

## Características

- **Réplicas**: 2 de cada serviço (a, b, p) - INÍCIO COM MAIS RÉPLICAS
- **HPA**: Habilitado
  - Service A: 2-5 réplicas, target CPU 70%
  - Service B: 2-5 réplicas, target CPU 70%
  - Gateway P: 2-10 réplicas, target CPU 70%
- **Recursos**: Mesmos do cenário base
  - CPU: 100m request, 500m limit
  - Memory: 128Mi request, 256Mi limit
- **Distribuição**: Kubernetes scheduler padrão

## Objetivo

Avaliar impacto de iniciar com mais réplicas:
- Menor latência inicial (sem cold start)
- Throughput maior desde o início
- Custo de recursos maior
- Tempo de scale-up menor

## Como executar

```bash
# Limpar cenário anterior
kubectl delete -f k8s/ --all

# Aplicar este cenário
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/scenarios/scenario2-replicas/

# Aguardar pods prontos
kubectl wait --for=condition=ready pod -l scenario=replicas -n pspd --timeout=60s

# Executar testes
./scripts/run_all_tests.sh all
```

## Hipóteses

✅ **Esperado melhorar**:
- Latência inicial menor (warm start)
- Throughput baseline maior
- Menos scale-up durante ramp

❌ **Esperado piorar**:
- Custo de recursos maior (2x desde início)
- Possível overhead de balanceamento

## Métricas Comparativas

| Métrica | Cenário 1 | Cenário 2 | Delta |
|---------|-----------|-----------|-------|
| Latência P95 baseline | ~500ms | ? | ? |
| Throughput baseline | ~420 req/s | ? | ? |
| Scale-up time | ~30s | ? | ? |
| Custo (pod*min) | ~50 | ~100 | +100% |
