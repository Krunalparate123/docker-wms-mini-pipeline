
# Custom WMS pipeline utility image
# Maintainer: Krunal Parate

FROM ubuntu:24.04

LABEL maintainer="Krunal Parate"
LABEL description="Docker-based Whole Metagenomic Sequencing pipeline utilities"
LABEL version="1.0"

ENV DEBIAN_FRONTEND=noninteractive

# Install general workflow utilities
RUN apt-get update && apt-get install -y \
    bash \
    coreutils \
    findutils \
    gzip \
    wget \
    curl \
    ca-certificates \
    procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Working directory
WORKDIR /wms

# Default shell
CMD ["/bin/bash"]
