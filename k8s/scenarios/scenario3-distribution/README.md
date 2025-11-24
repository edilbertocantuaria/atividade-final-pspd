# Cenário 3: Distribuição Forçada nos Workers

## Características

- **Réplicas**: 3 de cada serviço (a, b, p)
- **Distribuição**: Pod Anti-Affinity (1 pod por node)
  - Garante que cada serviço tenha pods distribuídos entre os 3 nodes
- **HPA**: Habilitado
  - Service A: 3-6 réplicas
  - Service B: 3-6 réplicas
  - Gateway P: 3-12 réplicas
- **Recursos**: Mesmos do cenário base

## Objetivo

Avaliar impacto da distribuição geográfica dos pods:
- Resiliência a falhas de node
- Latência de rede entre nodes
- Balanceamento de carga mais uniforme

## Como executar

```bash
# Limpar cenário anterior
kubectl delete -f k8s/ --all

# Aplicar este cenário
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/scenarios/scenario3-distribution/

# Verificar distribuição
kubectl get pods -n pspd -o wide

# Confirmar que cada serviço está em nodes diferentes
kubectl get pods -n pspd -l app=a -o wide
kubectl get pods -n pspd -l app=b -o wide
kubectl get pods -n pspd -l app=p -o wide

# Executar testes
./scripts/run_all_tests.sh all
```

## Hipóteses

✅ **Esperado melhorar**:
- Alta disponibilidade (falha de 1 node não derruba serviço)
- Balanceamento de carga entre nodes
- Utilização mais uniforme de recursos

❌ **Esperado piorar**:
- Possível aumento de latência (comunicação cross-node)
- Overhead de rede entre nodes

⚠️ **Para investigar**:
- Impacto da latência de rede inter-node
- Comportamento durante falha de node

## Métricas Comparativas

| Métrica | Cenário 1 | Cenário 3 | Delta |
|---------|-----------|-----------|-------|
| Latência P95 | ~500ms | ? | ? |
| Latência inter-serviço | ? | ? | ? |
| HA Score | Baixo | Alto | +++ |
| Network overhead | Baixo | ? | ? |

## Validação da Distribuição

Todos os pods devem estar em nodes diferentes:

```bash
# Deve mostrar 3 pods em 3 nodes diferentes
kubectl get pods -n pspd -l app=a -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
```
