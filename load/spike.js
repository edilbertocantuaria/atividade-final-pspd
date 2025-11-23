import http from 'k6/http';
import { check } from 'k6';

// Scenario: Spike test - sudden burst of traffic
export const options = {
  stages: [
    { duration: '10s', target: 10 },
    { duration: '10s', target: 200 },  // spike
    { duration: '30s', target: 200 },
    { duration: '10s', target: 10 },
    { duration: '10s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'],
    http_req_failed: ['rate<0.1'],
  },
};

export default function () {
  const baseUrl = __ENV.BASE_URL || 'http://localhost:8080';
  
  http.batch([
    ['GET', `${baseUrl}/a/hello?name=spike${__VU}`],
    ['GET', `${baseUrl}/b/numbers?count=5`],
  ]);
}
