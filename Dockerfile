FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential autoconf libtool pkg-config curl ca-certificates xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Optional: LibreDWG for higher-fidelity Civil 3D DWG → DXF (preserves proxies)
ARG INSTALL_LIBREDWG=1
RUN if [ "$INSTALL_LIBREDWG" = "1" ]; then \
      curl -fsSL -o /tmp/libredwg.tar.gz \
        https://github.com/LibreDWG/libredwg/releases/download/0.14/libredwg-0.14.tar.gz \
      && tar -xzf /tmp/libredwg.tar.gz -C /tmp \
      && cd /tmp/libredwg-0.14 \
      && ./configure --prefix=/usr/local --disable-python --disable-bindings \
      && make -j"$(nproc)" && make install && ldconfig \
      && rm -rf /tmp/libredwg*; \
    fi

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app
COPY static ./static
RUN mkdir -p data/uploads data/outputs

ENV PYTHONUNBUFFERED=1
ENV LD_LIBRARY_PATH=/usr/local/lib
EXPOSE 8000

CMD ["python", "-m", "app"]
