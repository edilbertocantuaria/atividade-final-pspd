import http from 'k6/http';
import { check } from 'k6';

// Scenario: Stress test - encontrar o limite máximo do sistema
// Este teste PODE gerar erros - é para identificar capacidade máxima
export const options = {
  stages: [
    { duration: '10s', target: 10 },
    { duration: '20s', target: 50 },
    { duration: '20s', target: 100 },
    { duration: '20s', target: 150 },
    { duration: '20s', target: 200 },  // pico máximo
    { duration: '10s', target: 0 },
  ],
  thresholds: {
    // Mais permissivo - objetivo é encontrar limite
    http_req_duration: ['p(95)<5000'],
    http_req_failed: ['rate<0.5'],  // aceita até 50% de erro no pico
  },
};

export default function () {
  const baseUrl = __ENV.BASE_URL || 'http://localhost:8080';
  
  http.batch([
    ['GET', `${baseUrl}/api/content?type=movies&limit=10`],
    ['GET', `${baseUrl}/api/metadata/m${(__VU % 4) + 1}?userId=stress${__VU}`],
  ]);
}
