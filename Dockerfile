FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        gdal-bin python3 python3-gdal python3-numpy python3-pil python3-requests ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN useradd --system --create-home --home-dir /app app
WORKDIR /app
COPY server.py straighten_sat.py dem.py ./
COPY ui ./ui
USER app
EXPOSE 8080
STOPSIGNAL SIGINT
CMD ["python3", "-u", "server.py"]
