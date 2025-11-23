FROM python:3.12-slim
WORKDIR /app

# Copia só o requirements do serviço (cache)
COPY services/a_rest/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Agora o código do serviço
COPY services/a_rest/ .

# Se usar os protos no REST, descomente:
# COPY proto/ ./proto/
# RUN touch /app/proto/__init__.py
# ENV PYTHONPATH=/app:/app/proto

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
