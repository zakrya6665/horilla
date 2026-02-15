# ---- Builder Stage ----
FROM python:3.12-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
        libjpeg-dev \
        zlib1g-dev \
        libffi-dev \
        gcc \
        g++ && \
    rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Python dependencies
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt gunicorn psycopg2-binary


# ---- Production Stage ----
FROM python:3.12-slim AS production

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

# Install runtime dependencies (including curl for health checks)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libpq5 \
        libjpeg62-turbo \
        zlib1g \
        libffi8 \
        curl && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

# Create non-root user
RUN useradd --create-home --uid 1000 appuser
USER appuser

# Copy virtual environment and application code
COPY --from=builder --chown=appuser:appuser /opt/venv /opt/venv
WORKDIR /app
COPY --chown=appuser:appuser . .

# Create media/static directories
RUN mkdir -p staticfiles media

# Expose port
EXPOSE 8000

# Health check (allow 90s for DB/migrations)
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -f http://127.0.0.1:8000/health/ || exit 1

# Entrypoint and startup command
ENTRYPOINT ["./docker/entrypoint.sh"]
CMD ["gunicorn", "horilla.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3", "--timeout", "120"]
