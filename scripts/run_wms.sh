
#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Docker-Based Whole Metagenomic Sequencing Pipeline
# Author: Krunal Parate
# Version: 1.1
#
# Workflow:
# FastQC -> Trim Galore -> MEGAHIT -> Prodigal
# -> COGclassifier -> Kraken2 -> Bracken
# -> BIOM -> TSV
#
# Environment: Ubuntu WSL2 + Docker Desktop
# ============================================================


# ---------------- 1. CONFIGURATION ----------------

PROJECT_DIR="$HOME/docker_wms_mini"
SAMPLE="Tetragonlairidipennis"

SAMPLE_DIR="$PROJECT_DIR/$SAMPLE"

R1="$SAMPLE_DIR/data/raw/${SAMPLE}_1.fastq.gz"
R2="$SAMPLE_DIR/data/raw/${SAMPLE}_2.fastq.gz"

DB_PATH="$PROJECT_DIR/databases/kraken2"
COG_DB="$PROJECT_DIR/databases/cogclassifier"

THREADS="${THREADS:-2}"

# Bracken settings
# Set this to the read length for which the database
# distribution file was generated.
BRACKEN_READ_LENGTH="${BRACKEN_READ_LENGTH:-150}"
BRACKEN_LEVEL="${BRACKEN_LEVEL:-S}"
BRACKEN_THRESHOLD="${BRACKEN_THRESHOLD:-10}"

BRACKEN_DIST="$DB_PATH/database${BRACKEN_READ_LENGTH}mers.kmer_distrib"


# ---------------- 2. DOCKER IMAGES ----------------

FASTQC_IMAGE="staphb/fastqc:0.12.1"
TRIMGALORE_IMAGE="ghcr.io/felixkrueger/trimgalore:latest"
MEGAHIT_IMAGE="getwilds/megahit:1.2.9"
PRODIGAL_IMAGE="microbiomeinformatics/prodigal:2.6.3"
KRAKEN2_IMAGE="staphb/kraken2:2.1.3"
BRACKEN_IMAGE="staphb/bracken:3.1"
PYTHON_IMAGE="python:3.11-slim"


# ---------------- 3. OUTPUT FOLDERS ----------------

RAW_QC="$SAMPLE_DIR/results/qc/raw"
CLEAN="$SAMPLE_DIR/results/trimmed"

ASSEMBLY_OUT="$SAMPLE_DIR/results/assembly"
ASSEMBLY_DIR="$ASSEMBLY_OUT/megahit"

GENE_OUT="$SAMPLE_DIR/results/gene_prediction"
COG_OUT="$SAMPLE_DIR/results/cog_annotation"

KRAKEN_OUT="$SAMPLE_DIR/results/kraken2"
BRACKEN_OUT="$SAMPLE_DIR/results/bracken"

BIOM_OUT="$SAMPLE_DIR/results/biom"
OTU_OUT="$BIOM_OUT/otu_table"

LOG_DIR="$SAMPLE_DIR/logs"


# ---------------- 4. HELPER FUNCTIONS ----------------

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


# ---------------- 5. CHECK REQUIREMENTS ----------------

command -v docker >/dev/null 2>&1 ||
    die "Docker is not installed or unavailable."

docker info >/dev/null 2>&1 ||
    die "Docker is not running. Start Docker Desktop."

[[ -f "$R1" ]] ||
    die "Missing input file: $R1"

[[ -f "$R2" ]] ||
    die "Missing input file: $R2"

for file in hash.k2d opts.k2d taxo.k2d; do
    [[ -f "$DB_PATH/$file" ]] ||
        die "Missing Kraken2 database file: $DB_PATH/$file"
done

[[ -s "$BRACKEN_DIST" ]] ||
    die "Missing Bracken distribution file: $BRACKEN_DIST
Generate the matching file using bracken-build or obtain
the matching Bracken database files."

[[ -d "$COG_DB" ]] ||
    die "COG database directory is missing: $COG_DB"

# Verify required images are available locally.
for image in \
    "$FASTQC_IMAGE" \
    "$TRIMGALORE_IMAGE" \
    "$MEGAHIT_IMAGE" \
    "$PRODIGAL_IMAGE" \
    "$KRAKEN2_IMAGE" \
    "$BRACKEN_IMAGE" \
    "$PYTHON_IMAGE"; do

    docker image inspect "$image" >/dev/null 2>&1 ||
        die "Docker image not found: $image. Pull it first."
done


# ---------------- 6. CREATE OUTPUT FOLDERS ----------------

mkdir -p \
    "$RAW_QC" \
    "$CLEAN" \
    "$ASSEMBLY_OUT" \
    "$GENE_OUT" \
    "$COG_OUT" \
    "$KRAKEN_OUT" \
    "$BRACKEN_OUT" \
    "$BIOM_OUT" \
    "$OTU_OUT" \
    "$LOG_DIR"


log "Starting WMS pipeline"
log "Sample: $SAMPLE"
log "Threads: $THREADS"
log "Kraken2 database: $DB_PATH"
log "Bracken read length: $BRACKEN_READ_LENGTH"
log "Bracken level: $BRACKEN_LEVEL"


# ---------------- STEP 1: RAW FASTQC ----------------

log "STEP 1/9: Raw read quality control with FastQC"

run_logged "$LOG_DIR/01_raw_fastqc.log" \
    docker run --rm \
    -v "$SAMPLE_DIR/data/raw:/input:ro" \
    -v "$RAW_QC:/output" \
    "$FASTQC_IMAGE" \
    fastqc \
    "/input/$(basename "$R1")" \
    "/input/$(basename "$R2")" \
    --threads "$THREADS" \
    --outdir /output


# ---------------- STEP 2: TRIM GALORE ----------------

log "STEP 2/9: Trimming paired-end reads"

CLEAN_R1="$CLEAN/${SAMPLE}_1_val_1.fq.gz"
CLEAN_R2="$CLEAN/${SAMPLE}_2_val_2.fq.gz"

if [[ ! -s "$CLEAN_R1" || ! -s "$CLEAN_R2" ]]; then

    run_logged "$LOG_DIR/02_trimgalore.log" \
        docker run --rm \
        -v "$SAMPLE_DIR/data/raw:/input:ro" \
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

else
    log "Existing trimmed FASTQ files found. Reusing them."
fi

[[ -s "$CLEAN_R1" ]] ||
    die "Trimmed R1 missing: $CLEAN_R1"

[[ -s "$CLEAN_R2" ]] ||
    die "Trimmed R2 missing: $CLEAN_R2"


# ---------------- STEP 3: MEGAHIT ASSEMBLY ----------------

log "STEP 3/9: Metagenome assembly using MEGAHIT"

CONTIGS="$ASSEMBLY_DIR/final.contigs.fa"

if [[ ! -s "$CONTIGS" ]]; then

    run_logged "$LOG_DIR/03_megahit.log" \
        docker run --rm \
        -v "$CLEAN:/input:ro" \
        -v "$ASSEMBLY_OUT:/output" \
        "$MEGAHIT_IMAGE" \
        megahit \
        -1 "/input/$(basename "$CLEAN_R1")" \
        -2 "/input/$(basename "$CLEAN_R2")" \
        -o /output/megahit \
        -t "$THREADS" \
        --min-contig-len 200

else
    log "Existing MEGAHIT assembly found. Reusing it."
fi

[[ -s "$CONTIGS" ]] ||
    die "MEGAHIT assembly missing."


# ---------------- STEP 4: PRODIGAL ----------------

log "STEP 4/9: Gene prediction using Prodigal"

run_logged "$LOG_DIR/04_prodigal.log" \
    docker run --rm \
    -v "$ASSEMBLY_DIR:/input:ro" \
    -v "$GENE_OUT:/output" \
    "$PRODIGAL_IMAGE" \
    prodigal \
    -i /input/final.contigs.fa \
    -a /output/proteins.faa \
    -d /output/genes.fna \
    -o /output/genes.gff \
    -f gff \
    -p meta

run_logged "$LOG_DIR/04_prodigal_gbk.log" \
    docker run --rm \
    -v "$ASSEMBLY_DIR:/input:ro" \
    -v "$GENE_OUT:/output" \
    "$PRODIGAL_IMAGE" \
    prodigal \
    -i /input/final.contigs.fa \
    -o /output/genes.gbk \
    -f gbk \
    -p meta

for file in proteins.faa genes.fna genes.gff genes.gbk; do
    [[ -s "$GENE_OUT/$file" ]] ||
        die "Prodigal output missing: $file"
done


# ---------------- STEP 5: COG CLASSIFICATION ----------------

log "STEP 5/9: COG functional annotation"

[[ -s "$GENE_OUT/proteins.faa" ]] ||
    die "Missing Prodigal protein file."

run_logged "$LOG_DIR/05_cogclassifier.log" \
    docker run --rm \
    -v "$GENE_OUT:/input:ro" \
    -v "$COG_OUT:/output" \
    -v "$COG_DB:/database" \
    "$PYTHON_IMAGE" \
    bash -lc '
        apt-get update &&
        apt-get install -y --no-install-recommends ncbi-blast+ &&
        pip install --no-cache-dir cogclassifier &&
        COGclassifier \
            -i /input/proteins.faa \
            -o /output \
            -d /database \
            -t '"$THREADS"' \
            -e 0.01
    '

[[ -s "$COG_OUT/cog_classify.tsv" ]] ||
    die "COG classification output missing."

[[ -s "$COG_OUT/cog_count.tsv" ]] ||
    die "COG count output missing."


# ---------------- STEP 6: KRAKEN2 ----------------

log "STEP 6/9: Taxonomic classification using Kraken2"

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

[[ -s "$KRAKEN_OUT/${SAMPLE}.report" ]] ||
    die "Kraken2 report missing."


# ---------------- STEP 7: BRACKEN ----------------

log "STEP 7/9: Species abundance estimation using Bracken"

run_logged "$LOG_DIR/07_bracken.log" \
    docker run --rm \
    -v "$KRAKEN_OUT:/input:ro" \
    -v "$DB_PATH:/db:ro" \
    -v "$BRACKEN_OUT:/output" \
    "$BRACKEN_IMAGE" \
    bracken \
    -d /db \
    -i "/input/${SAMPLE}.report" \
    -o "/output/${SAMPLE}.bracken" \
    -r "$BRACKEN_READ_LENGTH" \
    -l "$BRACKEN_LEVEL" \
    -t "$BRACKEN_THRESHOLD"

[[ -s "$BRACKEN_OUT/${SAMPLE}.bracken" ]] ||
    die "Bracken abundance output missing."


# ---------------- STEP 8: KRAKEN2 REPORT TO BIOM ----------------

log "STEP 8/9: Converting Kraken2 report to BIOM"

run_logged "$LOG_DIR/08_kraken_biom.log" \
    docker run --rm \
    -v "$KRAKEN_OUT:/input:ro" \
    -v "$BIOM_OUT:/output" \
    "$PYTHON_IMAGE" \
    bash -lc '
        pip install --no-cache-dir kraken-biom &&
        kraken-biom "/input/'"${SAMPLE}"'.report" \
            --fmt hdf5 \
            -o "/output/'"${SAMPLE}"'.biom"
    '

[[ -s "$BIOM_OUT/${SAMPLE}.biom" ]] ||
    die "BIOM file missing."


# ---------------- STEP 9: BIOM TO TSV ----------------

log "STEP 9/9: Converting BIOM to TSV"

run_logged "$LOG_DIR/09_biom_to_tsv.log" \
    docker run --rm \
    -v "$BIOM_OUT:/input:ro" \
    -v "$OTU_OUT:/output" \
    "$PYTHON_IMAGE" \
    bash -lc '
        pip install --no-cache-dir biom-format &&
        biom convert \
            -i "/input/'"${SAMPLE}"'.biom" \
            -o "/output/OTU_TABLE.tsv" \
            --to-tsv \
            --header-key taxonomy
    '

[[ -s "$OTU_OUT/OTU_TABLE.tsv" ]] ||
    die "BIOM TSV output missing."


# ---------------- FINAL SUMMARY ----------------

log "WMS pipeline completed successfully."

echo
echo "========== WMS OUTPUT SUMMARY =========="

echo "Sample:                 $SAMPLE"
echo "Raw FastQC:             $RAW_QC"
echo "Trimmed FASTQ:          $CLEAN"
echo "MEGAHIT assembly:       $CONTIGS"

echo "Predicted proteins:     $GENE_OUT/proteins.faa"
echo "Predicted genes:        $GENE_OUT/genes.fna"
echo "Gene annotation:        $GENE_OUT/genes.gff"

echo "COG classification:     $COG_OUT/cog_classify.tsv"
echo "COG category counts:    $COG_OUT/cog_count.tsv"

echo "Kraken2 report:         $KRAKEN_OUT/${SAMPLE}.report"
echo "Bracken abundance:      $BRACKEN_OUT/${SAMPLE}.bracken"

echo "BIOM file:              $BIOM_OUT/${SAMPLE}.biom"
echo "Taxonomic table:        $OTU_OUT/OTU_TABLE.tsv"

echo "Logs:                   $LOG_DIR"

echo "========================================"
