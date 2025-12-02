import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 10 },  // warm-up
    { duration: '1m', target: 10 },   // steady state
    { duration: '10s', target: 0 },   // cool-down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    http_req_failed: ['rate<0.01'],
  },
  discardResponseBodies: true,
  summaryTimeUnit: 'ms',
};

export default function () {
  const baseUrl = __ENV.BASE_URL || 'http://localhost:8080';
  
  // Simula usuário navegando na plataforma
  
  // 1. Listar catálogo completo
  let res = http.get(`${baseUrl}/api/content?type=all&limit=20`);
  check(res, {
    'catalog status is 200': (r) => r.status === 200,
    'catalog has items': (r) => JSON.parse(r.body).items.length > 0,
  });
  
  // 2. Filtrar filmes
  res = http.get(`${baseUrl}/api/content?type=movies&limit=10`);
  check(res, {
    'movies status is 200': (r) => r.status === 200,
  });
  
  // 3. Buscar metadados de um conteúdo específico
  res = http.get(`${baseUrl}/api/metadata/m1?userId=user_${__VU}`);
  check(res, {
    'metadata status is 200': (r) => r.status === 200,
    'metadata has items': (r) => JSON.parse(r.body).metadata.length > 0,
  });
  
  // 4. Endpoint combinado (browse)
  res = http.get(`${baseUrl}/api/browse?type=series&limit=5`);
  check(res, {
    'browse status is 200': (r) => r.status === 200,
  });
  
  sleep(0.1);
}
