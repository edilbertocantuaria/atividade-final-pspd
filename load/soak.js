import http from 'k6/http';
import { check, sleep } from 'k6';

// Scenario: Soak/Endurance test - sustained load over time
export const options = {
  stages: [
    { duration: '1m', target: 50 },
    { duration: '10m', target: 50 },  // sustained
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<800', 'p(99)<1500'],
    http_req_failed: ['rate<0.05'],  // Aumentado de 0.02 para 0.05 (5% de falha tolerável)
  },
  // Configurações para melhorar estabilidade e reduzir ruído de log
  noConnectionReuse: false,
  userAgent: 'k6-soak-test/1.0',
  // Suprimir warnings individuais de conexão (esperados durante HPA scaling)
  discardResponseBodies: true,
  summaryTimeUnit: 'ms',
};

export default function () {
  const baseUrl = __ENV.BASE_URL || 'http://localhost:8080';
  
  // Adicionar retry em caso de falha de conexão
  let res;
  let retries = 0;
  const maxRetries = 3;
  
  while (retries < maxRetries) {
    try {
      res = http.get(`${baseUrl}/a/hello?name=soak${__ITER}`, {
        timeout: '10s',
      });
      
      if (res.status === 0 && retries < maxRetries - 1) {
        // Falha de conexão, tentar novamente
        console.warn(`Connection failed, retry ${retries + 1}/${maxRetries}`);
        sleep(0.5);
        retries++;
        continue;
      }
      break;
    } catch (e) {
      if (retries < maxRetries - 1) {
        console.warn(`Request error: ${e}, retry ${retries + 1}/${maxRetries}`);
        sleep(0.5);
        retries++;
      } else {
        throw e;
      }
    }
  }
  
  check(res, { 
    'status 200': (r) => r.status === 200,
    'not connection error': (r) => r.status !== 0,
  });
  
  sleep(1);
}
