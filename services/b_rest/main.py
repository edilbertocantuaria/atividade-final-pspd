from fastapi import FastAPI
from fastapi.responses import JSONResponse
import time

app = FastAPI(title="B-REST-Streaming")

# Base de metadados e recomendações
METADATA_DB = {
    "m1": [{"key": "director", "value": "James Cameron", "score": 0.95}, 
           {"key": "cast", "value": "Chris Evans, Zoe Saldana", "score": 0.90}, 
           {"key": "similar", "value": "Interestelar", "score": 0.85}],
    "m2": [{"key": "director", "value": "Christopher Nolan", "score": 0.95}, 
           {"key": "cast", "value": "Leonardo DiCaprio", "score": 0.90},
           {"key": "similar", "value": "Amnésia", "score": 0.88}],
    "m3": [{"key": "director", "value": "Nancy Meyers", "score": 0.92}, 
           {"key": "cast", "value": "Julia Roberts, Tom Hanks", "score": 0.88},
           {"key": "similar", "value": "Amor à Segunda Vista", "score": 0.85}],
    "m4": [{"key": "director", "value": "Ridley Scott", "score": 0.94}, 
           {"key": "cast", "value": "Tom Hardy, Charlize Theron", "score": 0.91},
           {"key": "similar", "value": "Mad Max", "score": 0.90}],
    "s1": [{"key": "creator", "value": "J.J. Abrams", "score": 0.96}, 
           {"key": "cast", "value": "Millie Bobby Brown", "score": 0.92},
           {"key": "similar", "value": "Dark", "score": 0.90}],
    "s2": [{"key": "creator", "value": "Vince Gilligan", "score": 0.95}, 
           {"key": "cast", "value": "Bryan Cranston", "score": 0.93},
           {"key": "similar", "value": "True Detective", "score": 0.89}],
}

@app.get("/api/metadata/{content_id}")
def get_metadata(content_id: str, userId: str = "guest"):
    """Retorna metadados e recomendações para um conteúdo"""
    metadata = METADATA_DB.get(content_id, [])
    
    # Simula processamento
    time.sleep(0.05)
    
    # Se não houver metadados, retorna recomendações genéricas
    if not metadata:
        metadata = [
            {"key": "recommendation", "value": f"Conteúdo recomendado #1", "score": 0.7},
            {"key": "recommendation", "value": f"Conteúdo recomendado #2", "score": 0.6},
            {"key": "recommendation", "value": f"Conteúdo recomendado #3", "score": 0.5},
        ]
    
    return JSONResponse({
        "content_id": content_id,
        "user_id": userId,
        "metadata": metadata,
        "source": "B-REST"
    })

