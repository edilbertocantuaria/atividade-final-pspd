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

# Base de metadados e recomendações
METADATA_DB = {
    "m1": [("director", "James Cameron", 0.95), ("cast", "Chris Evans, Zoe Saldana", 0.90), 
           ("similar", "Interestelar", 0.85), ("similar", "Gravidade", 0.80)],
    "m2": [("director", "Christopher Nolan", 0.95), ("cast", "Leonardo DiCaprio", 0.90),
           ("similar", "Amnésia", 0.88), ("similar", "Ilha do Medo", 0.82)],
    "m3": [("director", "Nancy Meyers", 0.92), ("cast", "Julia Roberts, Tom Hanks", 0.88),
           ("similar", "Amor à Segunda Vista", 0.85), ("similar", "Você Tem Um Email", 0.80)],
    "m4": [("director", "Ridley Scott", 0.94), ("cast", "Tom Hardy, Charlize Theron", 0.91),
           ("similar", "Mad Max", 0.90), ("similar", "John Wick", 0.85)],
    "s1": [("creator", "J.J. Abrams", 0.96), ("cast", "Millie Bobby Brown", 0.92),
           ("similar", "Dark", 0.90), ("similar", "Stranger Things", 0.88)],
    "s2": [("creator", "Vince Gilligan", 0.95), ("cast", "Bryan Cranston", 0.93),
           ("similar", "True Detective", 0.89), ("similar", "Mindhunter", 0.84)],
    "s3": [("creator", "Greg Garcia", 0.90), ("cast", "Amy Poehler", 0.87),
           ("similar", "Modern Family", 0.88), ("similar", "Brooklyn Nine-Nine", 0.83)],
    "s4": [("creator", "David Chase", 0.97), ("cast", "James Gandolfini", 0.95),
           ("similar", "The Wire", 0.92), ("similar", "Breaking Bad", 0.90)],
}

class ServiceBImpl(services_pb2_grpc.ServiceBServicer):
    def StreamMetadata(self, request, context):
        """Retorna stream de metadados e recomendações para um conteúdo"""
        start = time.time()
        try:
            content_id = request.content_id
            metadata_list = METADATA_DB.get(content_id, [])
            
            # Simula processamento incremental (análise de dados)
            for key, value, score in metadata_list:
                time.sleep(0.01)  # Simula latência de processamento
                yield services_pb2.MetadataItem(
                    key=key,
                    value=value,
                    relevance_score=score
                )
                STREAM_ITEMS.labels(method='StreamMetadata').inc()
            
            # Adiciona recomendações genéricas se não houver metadados
            if not metadata_list:
                for i in range(3):
                    time.sleep(0.01)
                    yield services_pb2.MetadataItem(
                        key="recommendation",
                        value=f"Conteúdo recomendado #{i+1}",
                        relevance_score=0.7 - (i * 0.1)
                    )
                    STREAM_ITEMS.labels(method='StreamMetadata').inc()
            
            REQUEST_COUNT.labels(method='StreamMetadata', status='success').inc()
            
        except Exception as e:
            REQUEST_COUNT.labels(method='StreamMetadata', status='error').inc()
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(f"Error: {str(e)}")
        finally:
            REQUEST_LATENCY.labels(method='StreamMetadata').observe(time.time() - start)

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
