# Cenário 1: Base (Configuração Atual)

## Características

- **Réplicas**: 1 de cada serviço (a, b, p)
- **HPA**: Habilitado
  - Service A: 1-5 réplicas, target CPU 70%
  - Service B: 1-5 réplicas, target CPU 70%
  - Gateway P: 1-10 réplicas, target CPU 70%
- **Recursos**:
  - CPU: 100m request, 500m limit
  - Memory: 128Mi request, 256Mi limit
- **Distribuição**: Kubernetes scheduler padrão

## Objetivo

Estabelecer baseline de performance com HPA ativo e configuração padrão.

## Como executar

```bash
# Aplicar configuração
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/a.yaml
kubectl apply -f k8s/b.yaml
kubectl apply -f k8s/p.yaml

# Executar testes
./scripts/run_all_tests.sh all
```

## Métricas Esperadas

- Latência P95: < 1000ms
- Throughput: ~420 req/s (baseline)
- Scale-up durante spike/ramp
- Taxa de sucesso: > 90%
