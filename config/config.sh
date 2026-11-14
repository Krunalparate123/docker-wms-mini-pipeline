
#!/usr/bin/env bash

# ==========================================
# WMS Pipeline Configuration
# ==========================================

# Sample information
SAMPLE="${SAMPLE:-Tetragonlairidipennis}"

# Input files
R1="${R1:-$PROJECT_DIR/data/raw/${SAMPLE}_1.fastq.gz}"
R2="${R2:-$PROJECT_DIR/data/raw/${SAMPLE}_2.fastq.gz}"

# Database locations
# Update these paths on a different laptop.
DB_PATH="${DB_PATH:-$PROJECT_DIR/../databases/kraken2}"
COG_DB="${COG_DB:-$PROJECT_DIR/../databases/cogclassifier}"

# Computational resources
THREADS="${THREADS:-2}"

# Bracken configuration
BRACKEN_READ_LENGTH="${BRACKEN_READ_LENGTH:-150}"
BRACKEN_LEVEL="${BRACKEN_LEVEL:-S}"
BRACKEN_THRESHOLD="${BRACKEN_THRESHOLD:-10}"

BRACKEN_DIST="$DB_PATH/database${BRACKEN_READ_LENGTH}mers.kmer_distrib"

