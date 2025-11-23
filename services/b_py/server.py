import grpc
from concurrent import futures
import time, os
from prometheus_client import start_http_server, Counter, Histogram

from proto import services_pb2, services_pb2_grpc

# Prometheus metrics
REQUEST_COUNT = Counter(
    'grpc_server_requests_total',
    'Total gRPC requests to Service B',
    ['method', 'status']
)

REQUEST_LATENCY = Histogram(
    'grpc_server_request_duration_seconds',
    'gRPC request latency for Service B',
    ['method'],
    buckets=[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2, 5]
)

STREAM_ITEMS = Counter(
    'grpc_server_stream_items_total',
    'Total items streamed by Service B',
    ['method']
)

class ServiceBImpl(services_pb2_grpc.ServiceBServicer):
    def StreamNumbers(self, request, context):
        start = time.time()
        try:
            count = request.count if request.count > 0 else 5
            delay_ms = request.delay_ms if request.delay_ms > 0 else 0
            for i in range(1, count + 1):
                yield services_pb2.NumberReply(value=i)
                STREAM_ITEMS.labels(method='StreamNumbers').inc()
                if delay_ms > 0:
                    time.sleep(delay_ms/1000.0)
            REQUEST_COUNT.labels(method='StreamNumbers', status='success').inc()
        except Exception as e:
            REQUEST_COUNT.labels(method='StreamNumbers', status='error').inc()
            raise
        finally:
            REQUEST_LATENCY.labels(method='StreamNumbers').observe(time.time() - start)

def serve():
    # Start Prometheus metrics server
    metrics_port = int(os.environ.get("METRICS_PORT", "9102"))
    start_http_server(metrics_port)
    print(f"Metrics server started on :{metrics_port}", flush=True)
    
    port = int(os.environ.get("PORT", "50052"))
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    services_pb2_grpc.add_ServiceBServicer_to_server(ServiceBImpl(), server)
    server.add_insecure_port(f"[::]:{port}")
    server.start()
    print(f"Service B listening on :{port}", flush=True)
    try:
        while True:
            time.sleep(86400)
    except KeyboardInterrupt:
        server.stop(0)

if __name__ == "__main__":
    serve()
