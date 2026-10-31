
#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Docker-based Whole Metagenomic Sequencing (WMS) Mini Pipeline
# Workflow: FastQC -> MultiQC -> Trim Galore -> FastQC/MultiQC
#           -> Kraken2 -> kraken-biom -> BIOM -> OTU-style TSV
# Environment: Ubuntu on WSL2 + Docker
# ============================================================

# ---------------- Configuration ----------------
PROJECT_DIR="${PROJECT_DIR:-$HOME/docker_wms_mini}"
SAMPLE="PICHIA"

R1="$PROJECT_DIR/data/raw/${SAMPLE}_R1.fastq.gz"
R2="$PROJECT_DIR/data/raw/${SAMPLE}_R2.fastq.gz"

DB_PATH="${DB_PATH:-$PROJECT_DIR/databases/kraken2}"

THREADS="${THREADS:-2}"

# Docker images
FASTQC_IMAGE="staphb/fastqc:0.12.1"
MULTIQC_IMAGE="multiqc/multiqc:latest"
TRIMGALORE_IMAGE="ghcr.io/felixkrueger/trimgalore:latest"
KRAKEN2_IMAGE="staphb/kraken2:2.1.3"
PYTHON_IMAGE="python:3.11-slim"

# Output folders
RAW_QC="$PROJECT_DIR/results/qc/raw"
RAW_MQC="$PROJECT_DIR/results/qc/raw_multiqc"
CLEAN="$PROJECT_DIR/data/cleaned"
TRIM_QC="$PROJECT_DIR/results/qc/trimmed"
TRIM_MQC="$PROJECT_DIR/results/qc/trimmed_multiqc"
KRAKEN_OUT="$PROJECT_DIR/results/kraken2"
BIOM_OUT="$PROJECT_DIR/results/biom"
OTU_OUT="$BIOM_OUT/otu_table"
LOG_DIR="$PROJECT_DIR/logs"

# ---------------- Helper functions ----------------
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

run_logged() {
    local logfile="$1"
    shift
    "$@" 2>&1 | tee "$logfile"
}

# ---------------- Check requirements ----------------
command -v docker >/dev/null 2>&1 ||
    die "Docker is not installed or is not available in this WSL terminal."

docker info >/dev/null 2>&1 ||
    die "Docker is not running. Start Docker Desktop and enable Ubuntu WSL integration."

[[ -f "$R1" ]] || die "Missing input file: $R1"
[[ -f "$R2" ]] || die "Missing input file: $R2"

for file in hash.k2d opts.k2d taxo.k2d; do
    [[ -f "$DB_PATH/$file" ]] ||
        die "Missing Kraken2 database file: $DB_PATH/$file. Set DB_PATH to the directory containing all three .k2d files."
done

mkdir -p "$RAW_QC" "$RAW_MQC" "$CLEAN" "$TRIM_QC" "$TRIM_MQC"
mkdir -p "$KRAKEN_OUT" "$BIOM_OUT" "$OTU_OUT" "$LOG_DIR"

log "Starting pipeline for sample: $SAMPLE"
log "Project directory: $PROJECT_DIR"
log "Kraken2 database: $DB_PATH"

# ---------------- Step 1: Raw FastQC ----------------
log "STEP 1/7: Raw read quality control with FastQC"

run_logged "$LOG_DIR/01_raw_fastqc.log" \
    docker run --rm \
    -v "$PROJECT_DIR/data/raw:/input:ro" \
    -v "$RAW_QC:/output" \
    "$FASTQC_IMAGE" \
    fastqc \
    "/input/$(basename "$R1")" \
    "/input/$(basename "$R2")" \
    --threads "$THREADS" \
    --outdir /output

# ---------------- Step 2: Raw MultiQC ----------------
log "STEP 2/7: Summarizing raw FastQC results with MultiQC"

run_logged "$LOG_DIR/02_raw_multiqc.log" \
    docker run --rm \
    -v "$RAW_QC:/input:ro" \
    -v "$RAW_MQC:/output" \
    "$MULTIQC_IMAGE" \
    multiqc /input \
    --outdir /output \
    --filename raw_multiqc_report.html

# ---------------- Step 3: Trim Galore ----------------
log "STEP 3/7: Trimming paired-end reads"

run_logged "$LOG_DIR/03_trimgalore.log" \
    docker run --rm \
    -v "$PROJECT_DIR/data/raw:/input:ro" \
    -v "$CLEAN:/output" \
    "$TRIMGALORE_IMAGE" \
    trim_galore \
    --paired \
    --quality 20 \
    --length 20 \
    --cores "$THREADS" \
    --output_dir /output \
    "/input/$(basename "$R1")" \
    "/input/$(basename "$R2")"

CLEAN_R1="$CLEAN/${SAMPLE}_R1_val_1.fq.gz"
CLEAN_R2="$CLEAN/${SAMPLE}_R2_val_2.fq.gz"

[[ -f "$CLEAN_R1" ]] ||
    die "Trimmed R1 not found at $CLEAN_R1. Check $LOG_DIR/03_trimgalore.log"
[[ -f "$CLEAN_R2" ]] ||
    die "Trimmed R2 not found at $CLEAN_R2. Check $LOG_DIR/03_trimgalore.log"

# ---------------- Step 4: Post-trimming QC ----------------
log "STEP 4/7: FastQC on trimmed reads"

run_logged "$LOG_DIR/04_trimmed_fastqc.log" \
    docker run --rm \
    -v "$CLEAN:/input:ro" \
    -v "$TRIM_QC:/output" \
    "$FASTQC_IMAGE" \
    fastqc \
    "/input/$(basename "$CLEAN_R1")" \
    "/input/$(basename "$CLEAN_R2")" \
    --threads "$THREADS" \
    --outdir /output

log "Summarizing trimmed FastQC results with MultiQC"

run_logged "$LOG_DIR/05_trimmed_multiqc.log" \
    docker run --rm \
    -v "$TRIM_QC:/input:ro" \
    -v "$TRIM_MQC:/output" \
    "$MULTIQC_IMAGE" \
    multiqc /input \
    --outdir /output \
    --filename trimmed_multiqc_report.html

# ---------------- Step 5: Kraken2 classification ----------------
log "STEP 5/7: Taxonomic classification with Kraken2"

run_logged "$LOG_DIR/06_kraken2.log" \
    docker run --rm \
    -v "$CLEAN:/input:ro" \
    -v "$DB_PATH:/db:ro" \
    -v "$KRAKEN_OUT:/output" \
    "$KRAKEN2_IMAGE" \
    kraken2 \
    --db /db \
    --paired \
    --threads "$THREADS" \
    --report "/output/${SAMPLE}.report" \
    --output "/output/${SAMPLE}.kraken" \
    "/input/$(basename "$CLEAN_R1")" \
    "/input/$(basename "$CLEAN_R2")"

# ---------------- Step 6: Kraken report to BIOM ----------------
log "STEP 6/7: Converting Kraken2 report to BIOM"

run_logged "$LOG_DIR/07_kraken_biom.log" \
    docker run --rm \
    -v "$KRAKEN_OUT:/input:ro" \
    -v "$BIOM_OUT:/output" \
    "$PYTHON_IMAGE" \
    bash -lc 'pip install --no-cache-dir kraken-biom &&
              kraken-biom "/input/'"${SAMPLE}"'.report" \
              --fmt hdf5 \
              -o "/output/'"${SAMPLE}"'.biom"'

[[ -s "$BIOM_OUT/${SAMPLE}.biom" ]] ||
    die "BIOM file was not created. Check $LOG_DIR/07_kraken_biom.log"

# ---------------- Step 7: BIOM to TSV ----------------
log "STEP 7/7: Converting BIOM to a taxonomy TSV table"

run_logged "$LOG_DIR/08_biom_to_tsv.log" \
    docker run --rm \
    -v "$BIOM_OUT:/input:ro" \
    -v "$OTU_OUT:/output" \
    "$PYTHON_IMAGE" \
    bash -lc 'pip install --no-cache-dir biom-format &&
              biom convert \
              -i "/input/'"${SAMPLE}"'.biom" \
              -o "/output/OTU_TABLE.tsv" \
              --to-tsv \
              --header-key taxonomy'

[[ -s "$OTU_OUT/OTU_TABLE.tsv" ]] ||
    die "OTU table was not created. Check $LOG_DIR/08_biom_to_tsv.log"

# ---------------- Summary ----------------
log "Pipeline completed successfully."
echo
echo "========== OUTPUT SUMMARY =========="
echo "Raw QC report:       $RAW_MQC/raw_multiqc_report.html"
echo "Trimmed QC report:   $TRIM_MQC/trimmed_multiqc_report.html"
echo "Trimmed FASTQ files: $CLEAN"
echo "Kraken2 report:      $KRAKEN_OUT/${SAMPLE}.report"
echo "Kraken2 reads:       $KRAKEN_OUT/${SAMPLE}.kraken"
echo "BIOM file:           $BIOM_OUT/${SAMPLE}.biom"
echo "OTU-style TSV:       $OTU_OUT/OTU_TABLE.tsv"
echo "Logs:                $LOG_DIR"
echo "===================================="
