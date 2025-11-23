import http from 'k6/http';
export const options = { vus: 100, duration: '30s' };
export default function () {
  http.get('http://localhost:8080/a/hello?name=pspd');
  http.get('http://localhost:8080/b/numbers?count=10&delay_ms=5');
}
