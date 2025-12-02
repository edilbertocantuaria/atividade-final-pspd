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

CONTENT_ITEMS_RETURNED = Counter(
    'content_items_returned_total',
    'Total content items returned',
    ['content_type']
)

# Catálogo de conteúdo simulado
CONTENT_CATALOG = [
    {"id": "m1", "title": "A Jornada Infinita", "description": "Uma aventura épica através das galáxias",
     "type": "movie", "genres": ["Ficção Científica", "Aventura"], "year": 2024, "rating": 8.7, "duration": "2h 15min"},
    {"id": "m2", "title": "Segredos do Passado", "description": "Um thriller psicológico sobre memórias esquecidas",
     "type": "movie", "genres": ["Thriller", "Drama"], "year": 2024, "rating": 8.2, "duration": "1h 55min"},
    {"id": "m3", "title": "Risadas na Cidade", "description": "Uma comédia romântica em uma metrópole agitada",
     "type": "movie", "genres": ["Comédia", "Romance"], "year": 2024, "rating": 7.5, "duration": "1h 45min"},
    {"id": "m4", "title": "O Último Guardião", "description": "Um guerreiro protege a última esperança da humanidade",
     "type": "movie", "genres": ["Ação", "Aventura"], "year": 2023, "rating": 8.9, "duration": "2h 30min"},
    {"id": "s1", "title": "Dimensões Paralelas", "description": "Cientistas descobrem portal para realidades alternativas",
     "type": "series", "genres": ["Ficção Científica", "Drama"], "year": 2024, "rating": 9.1, "duration": "3 temporadas"},
    {"id": "s2", "title": "Cidade Sombria", "description": "Detetives investigam crimes sobrenaturais",
     "type": "series", "genres": ["Suspense", "Sobrenatural"], "year": 2023, "rating": 8.8, "duration": "2 temporadas"},
    {"id": "s3", "title": "Família Moderna", "description": "O dia a dia de uma família brasileira contemporânea",
     "type": "series", "genres": ["Comédia", "Família"], "year": 2024, "rating": 7.9, "duration": "1 temporada"},
    {"id": "s4", "title": "Império do Crime", "description": "A ascensão de um sindicato do crime organizado",
     "type": "series", "genres": ["Drama", "Crime"], "year": 2023, "rating": 9.3, "duration": "4 temporadas"},
    {"id": "ch1", "title": "Canal Premium", "description": "Entretenimento ao vivo 24/7",
     "type": "live", "genres": ["Entretenimento"], "year": 2024, "rating": 8.5, "duration": "24/7"},
    {"id": "ch2", "title": "Canal Notícias", "description": "Notícias em tempo real",
     "type": "live", "genres": ["Notícias"], "year": 2024, "rating": 8.0, "duration": "24/7"},
    {"id": "ch3", "title": "Canal Esportes", "description": "Transmissões esportivas ao vivo",
     "type": "live", "genres": ["Esportes"], "year": 2024, "rating": 9.0, "duration": "24/7"},
]

class ServiceAImpl(services_pb2_grpc.ServiceAServicer):
    def GetContent(self, request, context):
        """Retorna catálogo de conteúdo filtrado por tipo e gênero"""
        start = time.time()
        try:
            # Filtrar por tipo
            content_type = request.type.lower() if request.type else "all"
            filtered = CONTENT_CATALOG if content_type == "all" else [
                c for c in CONTENT_CATALOG if c["type"] == content_type
            ]
            
            # Filtrar por gênero
            if request.genre:
                filtered = [c for c in filtered if request.genre in c["genres"]]
            
            # Aplicar limite
            limit = request.limit if request.limit > 0 else len(filtered)
            filtered = filtered[:limit]
            
            # Construir resposta
            items = [
                services_pb2.ContentItem(
                    id=c["id"],
                    title=c["title"],
                    description=c["description"],
                    thumbnail=f"/api/thumbnails/{c['id']}.jpg",
                    type=c["type"],
                    genres=c["genres"],
                    year=c["year"],
                    rating=c["rating"],
                    duration=c["duration"]
                )
                for c in filtered
            ]
            
            CONTENT_ITEMS_RETURNED.labels(content_type=content_type).inc(len(items))
            REQUEST_COUNT.labels(method='GetContent', status='success').inc()
            
            return services_pb2.ContentResponse(items=items, total=len(items))
            
        except Exception as e:
            REQUEST_COUNT.labels(method='GetContent', status='error').inc()
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(f"Error: {str(e)}")
            return services_pb2.ContentResponse()
        finally:
            REQUEST_LATENCY.labels(method='GetContent').observe(time.time() - start)

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
