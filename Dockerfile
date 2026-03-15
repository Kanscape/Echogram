FROM python:3.10-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TZ=Asia/Shanghai

RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg tzdata \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY backend ./backend
COPY config ./config
COPY core ./core
COPY dashboard ./dashboard
COPY extractors ./extractors
COPY models ./models
COPY utils ./utils
COPY main.py ./

RUN mkdir -p /app/data /app/logs

EXPOSE 8765

CMD ["python", "main.py"]
