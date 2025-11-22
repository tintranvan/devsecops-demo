FROM python:3.11-alpine

WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

# Copy pip.conf, install packages, then cleanup
COPY pip.conf /tmp/pip.conf
RUN mkdir -p ~/.pip && \
    cp /tmp/pip.conf ~/.pip/pip.conf && \
    pip install --dry-run --no-deps -r requirements.txt && \
    pip install --no-cache-dir --only-binary=all -r requirements.txt && \
    rm -rf ~/.pip /tmp/pip.conf

COPY app.py .

# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

USER appuser

EXPOSE 8080

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "1", "app:app"]
