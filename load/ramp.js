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
  
  const res1 = http.get(`${baseUrl}/a/hello?name=load${__VU}`);
  check(res1, { 'a: status 200': (r) => r.status === 200 });
  
  const res2 = http.get(`${baseUrl}/b/numbers?count=10&delay_ms=10`);
  check(res2, { 'b: status 200': (r) => r.status === 200 });
  
  sleep(0.5);
}
