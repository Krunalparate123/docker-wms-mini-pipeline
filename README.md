
# Docker-Based Whole Metagenomic Sequencing Mini Pipeline

## Overview

This project implements a small, reproducible bioinformatics workflow for
paired-end metagenomic sequencing data using Docker containers on Ubuntu/WSL2.

The pipeline automates read quality control, adapter and quality trimming,
taxonomic classification, and conversion of Kraken2 taxonomic reports into
BIOM and TSV outputs.

## Workflow

1. Raw paired-end FASTQ input
2. FastQC quality control
3. MultiQC raw QC report
4. Trim Galore read trimming
5. FastQC on trimmed reads
6. MultiQC trimmed QC report
7. Kraken2 taxonomic classification
8. Kraken2 report conversion using kraken-biom
9. BIOM conversion to an OTU-style TSV table

## Tools

- Docker
- FastQC
- MultiQC
- Trim Galore
- Kraken2
- kraken-biom
- BIOM Format
- Bash
- Ubuntu on WSL2

## Project Structure

```text
docker_wms_mini/
├── data/
│   ├── raw/
│   └── cleaned/
├── databases/
│   └── kraken2/
├── logs/
├── results/
│   ├── qc/
│   │   ├── raw/
│   │   ├── raw_multiqc/
│   │   ├── trimmed/
│   │   └── trimmed_multiqc/
│   ├── kraken2/
│   └── biom/
│       └── otu_table/
├── scripts/
│   └── run_wms.sh
├── .gitignore
└── README.md
```

## Input Data

The example sample uses paired-end FASTQ files:

- `PICHIA_R1.fastq.gz`
- `PICHIA_R2.fastq.gz`

Place the files in `data/raw/`.

These names are example filenames and can be changed in `scripts/run_wms.sh`.

## Prerequisites

- Docker installed and running
- Ubuntu/WSL2 or a Linux environment
- Paired-end FASTQ input files
- A compatible, prebuilt Kraken2 database

The Kraken2 database must contain `hash.k2d`, `opts.k2d`, and `taxo.k2d`.

## Run the Pipeline

From the project root:

```bash
chmod +x scripts/run_wms.sh
./scripts/run_wms.sh
```

If the database is stored in another location:

```bash
DB_PATH="/path/to/kraken2_database" ./scripts/run_wms.sh
```

Replace the example path with the actual database directory.

## Expected Outputs

### Quality Control
- Raw FastQC HTML reports
- Raw MultiQC HTML report
- Trimmed FastQC HTML reports
- Trimmed MultiQC HTML report

### Taxonomic Classification
- `results/kraken2/PICHIA.report`
- `results/kraken2/PICHIA.kraken`

### BIOM and Taxonomy Table
- `results/biom/PICHIA.biom`
- `results/biom/otu_table/OTU_TABLE.tsv`

### Logs
The `logs/` folder contains logs for individual pipeline stages.

## Reproducibility and Limitations

The workflow uses Docker images to reduce the need to install individual
bioinformatics tools directly into Ubuntu.

The results depend on the input data, the Kraken2 database, and the versions
of the tools used. Record the database name/version and Docker image versions
when publishing results.

The final taxonomy table is derived from Kraken2 reports. It should not be
assumed to be a conventional 16S OTU table or an amplicon-based diversity
analysis table without additional validation.

## Future Improvements

- Support multiple samples
- Add automated reports and summary statistics
- Add Bracken abundance estimation
- Add diversity analysis where appropriate
- Add a Docker Compose or workflow-manager configuration
- Add tests for input validation and output generation

## Author

Add your name and contact information here.
