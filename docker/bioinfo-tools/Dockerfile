
FROM python:3.11-slim

LABEL maintainer="Krunal Parate"
LABEL description="Docker image for WMS functional annotation and BIOM conversion"
LABEL version="1.0"

ENV DEBIAN_FRONTEND=noninteractive

# Install NCBI BLAST+
RUN apt-get update && \
    apt-get install -y --no-install-recommends ncbi-blast+ && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install pinned Python dependencies
WORKDIR /opt/wms

COPY requirements.txt /opt/wms/requirements.txt

RUN pip install --no-cache-dir \
    --requirement /opt/wms/requirements.txt

CMD ["/bin/bash"]
