
#!/usr/bin/env bash
set -Eeuo pipefail

IMAGES=(
  "staphb/fastqc:0.12.1"
  "ghcr.io/felixkrueger/trimgalore:latest"
  "getwilds/megahit:1.2.9"
  "microbiomeinformatics/prodigal:2.6.3"
  "staphb/kraken2:2.1.3"
  "staphb/bracken:3.1"
  "python:3.11-slim"
)

# Optional custom utility image
IMAGES+=("kparate/wms-pipeline:1.0")

for IMAGE in "${IMAGES[@]}"; do
    echo "=================================="
    echo "Pulling $IMAGE"
    docker pull "$IMAGE"
done

echo "All requested Docker images downloaded."

