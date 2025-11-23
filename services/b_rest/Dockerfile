FROM python:3.12-slim
WORKDIR /app

# 1) Instala deps específicas do serviço REST B
COPY services/b_rest/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 2) Copia só o código do serviço
COPY services/b_rest/ .

# (Opcional) Se o REST B usar os protos, descomente:
# COPY proto/ ./proto/
# RUN touch /app/proto/__init__.py
# ENV PYTHONPATH=/app:/app/proto

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
