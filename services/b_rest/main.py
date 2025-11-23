from fastapi import FastAPI
from fastapi.responses import JSONResponse
import time

app = FastAPI(title="B-REST")

@app.get("/b/numbers")
def numbers(count: int = 5, delay_ms: int = 0):
    count = max(0, int(count))
    delay_ms = max(0, int(delay_ms))
    out = []
    for i in range(1, count + 1):
        out.append(i)
        if delay_ms > 0:
            time.sleep(delay_ms/1000.0)
    return JSONResponse({"values": out})
