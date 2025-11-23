from fastapi import FastAPI
from fastapi.responses import JSONResponse

app = FastAPI(title="A-REST")

@app.get("/a/hello")
def hello(name: str = "mundo"):
    return JSONResponse({"message": f"Olá, {name}! [A-REST]"})
