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
};

export default function () {
  const baseUrl = __ENV.BASE_URL || 'http://localhost:8080';
  
  let res = http.get(`${baseUrl}/a/hello?name=k6test`);
  check(res, {
    'status is 200': (r) => r.status === 200,
    'has message': (r) => r.json('message') !== undefined,
  });
  
  res = http.get(`${baseUrl}/b/numbers?count=5`);
  check(res, {
    'status is 200': (r) => r.status === 200,
    'has values': (r) => r.json('values') !== undefined,
  });
  
  sleep(0.1);
}
