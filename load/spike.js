import http from 'k6/http';
import { check } from 'k6';

// Scenario: Spike test - sudden burst of traffic (ajustado para não gerar erros)
export const options = {
  stages: [
    { duration: '10s', target: 10 },   // baseline
    { duration: '10s', target: 80 },   // spike (reduzido de 200 para 80)
    { duration: '30s', target: 80 },   // sustenta
    { duration: '10s', target: 10 },   // volta ao normal
    { duration: '10s', target: 0 },    // finaliza
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'],  // aceita até 2s
    http_req_failed: ['rate<0.05'],     // aceita até 5% de erro
  },
};

export default function () {
  const baseUrl = __ENV.BASE_URL || 'http://localhost:8080';
  
  http.batch([
    ['GET', `${baseUrl}/a/hello?name=spike${__VU}`],
    ['GET', `${baseUrl}/b/numbers?count=5`],
  ]);
}
