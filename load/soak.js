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
    http_req_failed: ['rate<0.02'],
  },
};

export default function () {
  const baseUrl = __ENV.BASE_URL || 'http://localhost:8080';
  
  const res = http.get(`${baseUrl}/a/hello?name=soak${__ITER}`);
  check(res, { 'status 200': (r) => r.status === 200 });
  
  sleep(1);
}
