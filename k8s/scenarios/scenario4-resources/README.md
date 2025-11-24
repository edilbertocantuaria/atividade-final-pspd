# Cenário 4: Recursos Limitados

## Características

- **Réplicas**: 1 de cada serviço (início)
- **Recursos**: REDUZIDOS (stress test)
  - CPU request: 50m (vs 100m base) - 50% MENOR
  - CPU limit: 200m (vs 500m base) - 60% MENOR
  - Memory request: 64Mi (vs 128Mi base) - 50% MENOR
  - Memory limit: 128Mi (vs 256Mi base) - 50% MENOR
- **HPA**: Habilitado e mais agressivo
  - Target CPU: 60% (vs 70% base)
  - Max réplicas aumentado (8-15 vs 5-10)
  - Scale-up mais rápido devido a recursos limitados

## Objetivo

Testar comportamento com recursos escassos:
- Como HPA compensa com mais réplicas
- Impacto na latência e throughput
- Eficiência de custo (mais pods pequenos vs poucos pods grandes)
- Throttling de CPU e OOM

## Como executar

```bash
# Limpar cenário anterior
kubectl delete -f k8s/ --all

# Aplicar este cenário
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/scenarios/scenario4-resources/

# Monitorar scaling (vai escalar mais agressivamente)
watch -n 2 'kubectl get hpa -n pspd; echo ""; kubectl top pods -n pspd'

# Executar testes
./scripts/run_all_tests.sh all
```

## Hipóteses

✅ **Esperado acontecer**:
- Scale-up muito mais agressivo (pods chegam no limite rápido)
- Maior número de pods durante picos
- CPU throttling mais frequente
- Possível OOMKill em casos extremos

❌ **Esperado piorar**:
- Latência P95 maior (throttling)
- Throughput por pod menor
- Mais overhead de rede (mais pods = mais hops)

💰 **Trade-off de custo**:
- Recursos por pod: 50% menor
- Número de pods: potencialmente 2-3x maior
- Custo total: pode ser similar ou maior (overhead)

## Métricas Comparativas

| Métrica | Cenário 1 (Base) | Cenário 4 (Limitado) | Delta |
|---------|------------------|----------------------|-------|
| CPU request/pod | 100m | 50m | -50% |
| CPU limit/pod | 500m | 200m | -60% |
| Memory/pod | 128-256Mi | 64-128Mi | -50% |
| Max réplicas A/B | 5 | 8 | +60% |
| Max réplicas P | 10 | 15 | +50% |
| Latência P95 | ~500ms | ? | ? |
| Pods spike | ~10 | ? | ? |

## Observações Importantes

⚠️ **Monitorar**:
- CPU throttling: `kubectl top pods -n pspd --containers`
- OOMKills: `kubectl get events -n pspd | grep OOMKilled`
- Pending pods: `kubectl get pods -n pspd | grep Pending`

📊 **Métricas chave**:
```bash
# Ver CPU real vs throttled
kubectl top pods -n pspd --containers

# Ver scaling events
kubectl describe hpa -n pspd | grep -A 5 Events
```

## Quando usar este cenário

✅ **Bom para**:
- Ambientes com recursos limitados (dev/staging)
- Testes de resiliência e limites
- Validar comportamento sob stress

❌ **Evitar em**:
- Produção sem testes prévios
- Cargas críticas de baixa latência
