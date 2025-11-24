# Soluções para Problemas de Conectividade em Testes Longos

## Problema Identificado

Durante o teste **soak** (11 minutos de carga sustentada), o `kubectl port-forward` pode cair, causando erros:
```
connection reset by peer
```

## 🔧 Solução 1: Port-Forward Auto-Recuperável (RECOMENDADO)

Use o script que monitora e reinicia o port-forward automaticamente:

```bash
# Terminal 1: Iniciar port-forward estável
./scripts/stable_port_forward.sh

# Terminal 2: Executar testes
BASE_URL=http://localhost:8080 ./scripts/run_all_tests.sh
```

O script `stable_port_forward.sh`:
- Monitora o processo a cada 5 segundos
- Reinicia automaticamente se cair
- Loga todas as ações em `/tmp/pf_stable.log`

Para parar:
```bash
kill $(cat /tmp/pf_stable.pid)
```

## 🔧 Solução 2: NodePort (Mais Estável)

Expor o serviço via NodePort elimina a dependência do port-forward:

```bash
# 1. Aplicar NodePort
kubectl apply -f k8s/p-nodeport.yaml

# 2. Obter URL do minikube
NODEPORT_URL=$(minikube service p-svc-nodeport -n pspd --url)
echo $NODEPORT_URL

# 3. Executar testes com NodePort
BASE_URL=$NODEPORT_URL ./scripts/run_all_tests.sh
```

**Vantagens:**
- Não cai durante testes longos
- Conexão direta com o pod
- Melhor performance

## 🔧 Solução 3: Ingress + /etc/hosts

Para ambiente mais próximo de produção:

```bash
# 1. Verificar se ingress está habilitado
minikube addons list | grep ingress

# 2. Adicionar entrada no /etc/hosts
echo "$(minikube ip) pspd.local" | sudo tee -a /etc/hosts

# 3. Aplicar ingress
kubectl apply -f k8s/ingress.yaml

# 4. Aguardar ingress ficar pronto
kubectl wait --for=condition=ready ingress -n pspd --all --timeout=120s

# 5. Executar testes
BASE_URL=http://pspd.local ./scripts/run_all_tests.sh
```

## 🔧 Solução 4: Melhorias no Teste (JÁ APLICADA)

O arquivo `load/soak.js` foi atualizado com:

### Retry automático
```javascript
// Tenta até 3 vezes em caso de falha de conexão
let retries = 0;
const maxRetries = 3;
while (retries < maxRetries) {
  try {
    res = http.get(...);
    if (res.status === 0 && retries < maxRetries - 1) {
      sleep(0.5);
      retries++;
      continue;
    }
    break;
  } catch (e) {
    // retry
  }
}
```

### Threshold mais tolerante
```javascript
thresholds: {
  http_req_failed: ['rate<0.05'],  // 5% de falha tolerável
}
```

### Timeout explícito
```javascript
http.get(url, { timeout: '10s' })
```

## 📊 Comparação das Soluções

| Solução | Estabilidade | Complexidade | Produção-like |
|---------|-------------|--------------|---------------|
| Port-Forward Auto-Recuperável | ⭐⭐⭐ | ⭐ | ❌ |
| NodePort | ⭐⭐⭐⭐⭐ | ⭐ | ⚠️ |
| Ingress | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ✅ |
| Retry no k6 | ⭐⭐⭐⭐ | ⭐ | ✅ |

## 🎯 Recomendação de Uso

### Para testes rápidos (baseline, ramp, spike):
```bash
kubectl port-forward -n pspd svc/p-svc 8080:80 &
BASE_URL=http://localhost:8080 k6 run load/baseline.js
```

### Para teste soak (11 minutos):
```bash
# Opção A: Port-forward monitorado
./scripts/stable_port_forward.sh &
sleep 5
BASE_URL=http://localhost:8080 k6 run load/soak.js

# Opção B: NodePort (mais simples)
kubectl apply -f k8s/p-nodeport.yaml
BASE_URL=$(minikube service p-svc-nodeport -n pspd --url) k6 run load/soak.js
```

## 🐛 Troubleshooting

### Port-forward ainda cai mesmo com stable_port_forward.sh

Verifique os logs:
```bash
tail -f /tmp/pf_stable.log
```

Se estiver reiniciando muito, use NodePort.

### NodePort não funciona

```bash
# Verificar se está criado
kubectl get svc -n pspd p-svc-nodeport

# Testar acesso
minikube service p-svc-nodeport -n pspd --url
curl $(minikube service p-svc-nodeport -n pspd --url)
```

### Ingress retorna 404

```bash
# Verificar status
kubectl get ingress -n pspd

# Ver detalhes
kubectl describe ingress p-ingress -n pspd

# Testar com IP direto
curl -H "Host: pspd.local" http://$(minikube ip)/
```

## 📝 Atualização do Script run_all_tests.sh

Para usar port-forward estável automaticamente, você pode modificar o script:

```bash
# Antes de executar testes
if [ ! -f /tmp/pf_stable.pid ]; then
    echo "Iniciando port-forward estável..."
    ./scripts/stable_port_forward.sh &
    STABLE_PF_PID=$!
    sleep 5
fi

# Executar testes...

# Ao final
if [ -n "$STABLE_PF_PID" ]; then
    kill $(cat /tmp/pf_stable.pid) 2>/dev/null
fi
```

## ✅ Próximos Passos

1. **Teste atual**: O k6 já tem retry implementado
2. **Para novo teste completo**: Use NodePort
   ```bash
   kubectl apply -f k8s/p-nodeport.yaml
   BASE_URL=$(minikube service p-svc-nodeport -n pspd --url) ./scripts/run_all_tests.sh
   ```
3. **Para monitoramento**: Use `./scripts/monitor.sh` em paralelo

---

**Última atualização**: 23/11/2025
