import http from 'k6/http';
import { check, sleep } from 'k6';

// Scenario: Ramping load test
export const options = {
  stages: [
    { duration: '30s', target: 10 },
    { duration: '1m', target: 50 },
    { duration: '1m', target: 100 },
    { duration: '1m', target: 150 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<800', 'p(99)<1500'],
    http_req_failed: ['rate<0.05'],
  },
  discardResponseBodies: true,
  summaryTimeUnit: 'ms',
};

export default function () {
  const baseUrl = __ENV.BASE_URL || 'http://localhost:8080';
  const contentTypes = ['movies', 'series', 'live', 'all'];
  const contentType = contentTypes[Math.floor(Math.random() * contentTypes.length)];
  
  // Simula navegação variável na plataforma
  const res1 = http.get(`${baseUrl}/api/content?type=${contentType}&limit=15`);
  check(res1, { 'content: status 200': (r) => r.status === 200 });
  
  // 50% buscam metadados
  if (Math.random() > 0.5) {
    const contentIds = ['m1', 'm2', 's1', 's2'];
    const id = contentIds[Math.floor(Math.random() * contentIds.length)];
    const res2 = http.get(`${baseUrl}/api/metadata/${id}`);
    check(res2, { 'metadata: status 200': (r) => r.status === 200 });
  }
  
  sleep(0.5);
}
