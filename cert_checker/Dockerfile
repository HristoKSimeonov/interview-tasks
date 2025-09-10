FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .
COPY config.json .

RUN useradd -m -u 1000 certchecker && \
    chown -R certchecker:certchecker /app

USER certchecker

CMD ["python", "main.py"]