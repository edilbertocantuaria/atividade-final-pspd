import grpc
from concurrent import futures
import time, os
from prometheus_client import start_http_server, Counter, Histogram

from proto import services_pb2, services_pb2_grpc

# Prometheus metrics
REQUEST_COUNT = Counter(
    'grpc_server_requests_total',
    'Total gRPC requests to Service A',
    ['method', 'status']
)

REQUEST_LATENCY = Histogram(
    'grpc_server_request_duration_seconds',
    'gRPC request latency for Service A',
    ['method'],
    buckets=[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2, 5]
)

class ServiceAImpl(services_pb2_grpc.ServiceAServicer):
    def SayHello(self, request, context):
        start = time.time()
        try:
            name = request.name or "world"
            response = services_pb2.HelloReply(message=f"Olá, {name}! [A]")
            REQUEST_COUNT.labels(method='SayHello', status='success').inc()
            return response
        except Exception as e:
            REQUEST_COUNT.labels(method='SayHello', status='error').inc()
            raise
        finally:
            REQUEST_LATENCY.labels(method='SayHello').observe(time.time() - start)

def serve():
    # Start Prometheus metrics server
    metrics_port = int(os.environ.get("METRICS_PORT", "9101"))
    start_http_server(metrics_port)
    print(f"Metrics server started on :{metrics_port}", flush=True)
    
    port = int(os.environ.get("PORT", "50051"))
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    services_pb2_grpc.add_ServiceAServicer_to_server(ServiceAImpl(), server)
    server.add_insecure_port(f"[::]:{port}")
    server.start()
    print(f"Service A listening on :{port}", flush=True)
    try:
        while True:
            time.sleep(86400)
    except KeyboardInterrupt:
        server.stop(0)

if __name__ == "__main__":
    serve()
