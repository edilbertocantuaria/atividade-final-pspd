# Cenário 5: Sem HPA (Réplicas Fixas)

## Características

- **Réplicas**: FIXAS (não escalam)
  - Service A: 3 réplicas
  - Service B: 3 réplicas
  - Gateway P: 5 réplicas
- **HPA**: DESABILITADO (sem autoscaling)
- **Recursos**: Mesmos do cenário base
  - CPU: 100m request, 500m limit
  - Memory: 128Mi request, 256Mi limit
- **Distribuição**: Kubernetes scheduler padrão

## Objetivo

Baseline de comparação para avaliar benefício do HPA:
- Comportamento com carga fixa
- Over-provisioning (desperdício quando carga baixa)
- Under-provisioning (degradação quando carga alta)
- Latência sem elasticidade

## Como executar

```bash
# Limpar cenário anterior
kubectl delete -f k8s/ --all

# Aplicar este cenário (SEM HPA)
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/scenarios/scenario5-no-hpa/

# Verificar que NÃO há HPAs
kubectl get hpa -n pspd
# Deve retornar: No resources found

# Verificar pods fixos
kubectl get pods -n pspd
# Deve ter: 3 pods a, 3 pods b, 5 pods p = 11 pods total

# Executar testes
./scripts/run_all_tests.sh all
```

## Hipóteses

✅ **Esperado melhorar**:
- Latência baseline consistente (sem cold start de novos pods)
- Simplicidade operacional (sem surpresas de scaling)
- Throughput previsível

❌ **Esperado piorar**:
- Desperdício durante baseline/soak (over-provisioned)
- Degradação durante spike (under-provisioned)
- CPU/Memory utilization ineficiente
- Custo fixo alto

## Comparação com Cenário 1 (Base com HPA)

### Cenário 1 (HPA):
- **Baseline**: 3 pods total → baixo custo
- **Ramp**: 3→8 pods → scale-up gradual
- **Spike**: 8→11 pods → absorve pico
- **Soak**: 6-8 pods → otimizado
- **Custo médio**: ~6 pods

### Cenário 5 (Sem HPA):
- **Baseline**: 11 pods → DESPERDÍCIO (over-provisioned 3.6x)
- **Ramp**: 11 pods → OK
- **Spike**: 11 pods → POSSÍVEL DEGRADAÇÃO (pode precisar mais)
- **Soak**: 11 pods → DESPERDÍCIO (over-provisioned 1.8x)
- **Custo fixo**: 11 pods sempre

## Métricas Comparativas

| Métrica | Cenário 1 (HPA) | Cenário 5 (No HPA) | Análise |
|---------|-----------------|--------------------|---------| 
| Pods baseline | 3 | 11 | Over-provisioned 3.6x |
| Pods spike | ~11 | 11 | Similar |
| Pods soak | 6-8 | 11 | Over-provisioned 1.5x |
| Custo médio | ~6 pod*h | 11 pod*h | +83% custo |
| Latência baseline | ? | ? | Esperado similar |
| Latência spike | ? | ? | Esperado pior (sem HPA) |
| CPU utilization | Alta (scale-to-fit) | Baixa (over-provisioned) | Desperdício |

## Análise de Custo

```
Cenário 1 (HPA):
- Baseline (5min): 3 pods × 5min = 15 pod-min
- Ramp (5min): 6 pods × 5min = 30 pod-min  
- Spike (1.6min): 11 pods × 1.6min = 18 pod-min
- Soak (15min): 7 pods × 15min = 105 pod-min
TOTAL: ~168 pod-min (~2.8 pod-horas)

Cenário 5 (No HPA):
- Todos os testes: 11 pods × 26.6min = 293 pod-min (~4.9 pod-horas)
DESPERDÍCIO: +74% de custo
```

## Quando usar este cenário

✅ **Bom para**:
- Carga extremamente previsível e constante
- Ambientes onde latência de cold start é inaceitável
- Debugging (simplifica troubleshooting)
- Validar capacidade máxima sem variáveis de scaling

❌ **Evitar em**:
- Carga variável (spiky/bursty)
- Ambientes com otimização de custo
- Produção moderna (HPA é best practice)

## Observações

⚠️ **Atenção**:
- Réplicas fixas escolhidas para cenário spike (11 pods)
- Se spike precisar de mais, haverá degradação
- Se baseline precisar de menos, haverá desperdício

📊 **Para análise completa**:
```bash
# Monitorar uso de recursos (deve estar baixo no baseline)
watch -n 2 'kubectl top pods -n pspd'

# Confirmar que pods não mudam
watch -n 2 'kubectl get pods -n pspd | wc -l'
```

## Conclusão Esperada

Este cenário deve demonstrar o **valor do HPA** ao mostrar:
1. **Over-provisioning**: Desperdício de 74% de recursos
2. **Falta de elasticidade**: Não se adapta à carga
3. **Custo fixo alto**: Paga pelo pior caso sempre
