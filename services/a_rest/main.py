from fastapi import FastAPI
from fastapi.responses import JSONResponse
import time

app = FastAPI(title="A-REST-Streaming")

# Catálogo de conteúdo
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
]

@app.get("/api/content")
def get_content(type: str = "all", limit: int = 20, genre: str = ""):
    """Retorna catálogo de conteúdo filtrado"""
    # Filtrar por tipo
    filtered = CONTENT_CATALOG if type == "all" else [
        c for c in CONTENT_CATALOG if c["type"] == type
    ]
    
    # Filtrar por gênero
    if genre:
        filtered = [c for c in filtered if genre in c["genres"]]
    
    # Aplicar limite
    filtered = filtered[:limit]
    
    return JSONResponse({
        "items": filtered,
        "total": len(filtered),
        "source": "A-REST"
    })

@app.get("/api/content/{content_id}")
def get_content_by_id(content_id: str):
    """Retorna detalhes de um conteúdo específico"""
    for item in CONTENT_CATALOG:
        if item["id"] == content_id:
            return JSONResponse(item)
    return JSONResponse({"error": "Content not found"}, status_code=404)

