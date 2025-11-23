FROM python:3.11-slim AS builder

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Final stage
FROM python:3.11-slim

WORKDIR /app

# Copy dependencies from builder
COPY --from=builder /root/.local /root/.local

# Copy application
COPY . .

# Make sure scripts in .local are usable
ENV PATH=/root/.local/bin:$PATH

# Generate proto files
RUN python -m grpc_tools.protoc -I. \
    --python_out=. \
    --grpc_python_out=. \
    proto/services.proto

EXPOSE 50051 9101

CMD ["python", "server.py"]
