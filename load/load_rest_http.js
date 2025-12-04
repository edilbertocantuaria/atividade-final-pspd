import http from 'k6/http';
export const options = { vus: 100, duration: '30s' };
export default function () {
  http.get('http://localhost:8081/api/content?type=all&limit=10');
  http.get('http://localhost:8081/api/metadata/m1?userId=user123');
}
