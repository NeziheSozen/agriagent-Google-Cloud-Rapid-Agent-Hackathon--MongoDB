FROM python:3.12-slim

LABEL maintainer="AgriAgent Team"
LABEL description="AgriAgent — AI-Powered Agricultural Advisory API"

WORKDIR /app

# Install dependencies first for Docker layer caching
COPY requirements.txt .
RUN apt-get update && apt-get install -y nodejs npm && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Use PORT environment variable provided by Cloud Run, fallback to 8000
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
