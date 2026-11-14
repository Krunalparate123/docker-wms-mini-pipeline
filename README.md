# Docker-Based Whole Metagenomic Sequencing (WMS) Pipeline

**Author:** Krunal Parate  
**Project:** Whole Metagenomic Sequencing Analysis  
**Sample:** *Tetragonlairidipennis*  
**Environment:** Ubuntu WSL2, Docker, Bash, Python

---

## Project Overview

This project implements a containerized Whole Metagenomic Sequencing (WMS) analysis workflow using Docker. The pipeline processes paired-end FASTQ sequencing data and performs quality control, read trimming, metagenomic assembly, gene prediction, functional annotation, taxonomic classification, and abundance estimation.

The main objective is to create a reproducible and modular bioinformatics workflow in which individual tools run inside Docker containers, reducing the need to install bioinformatics software directly on the host system.

## Workflow

```text
             Paired-end FASTQ Files
                       |
                       v
                Quality Control
                    FastQC
                       |
                       v
                 Read Trimming
                  Trim Galore
                       |
                       v
              Metagenomic Assembly
                    MEGAHIT
                       |
                       v
                  Gene Prediction
                    Prodigal
                       |
              +--------+--------+
              |                 |
              v                 v
       Functional           Taxonomic
       Annotation         Classification
      COGclassifier           Kraken2
              |                 |
              v                 v
        COG Results            Bracken
                                |
                                v
                         BIOM Conversion
                                |
                                v
                         OTU Table (TSV)
```

## Tools and Technologies

| Tool / Technology | Purpose |
|---|---|
| Docker | Containerized execution of bioinformatics tools |
| Bash | Pipeline automation |
| FastQC | Raw and trimmed read quality assessment |
| Trim Galore | Adapter and quality trimming |
| MEGAHIT | Metagenomic assembly |
| Prodigal | Gene prediction |
| COGclassifier | Functional annotation |
| Kraken2 | Taxonomic classification |
| Bracken | Taxonomic abundance estimation |
| kraken-biom | Conversion of Kraken2 reports to BIOM |
| BIOM-format | BIOM to TSV conversion |
| Python | Supporting analysis and package execution |

## Pipeline Steps

### 1. Quality Control – FastQC
- Evaluates the quality of raw paired-end sequencing reads.
- Generates HTML and ZIP quality reports.
- Helps identify potential sequencing quality issues.

### 2. Read Trimming – Trim Galore
- Performs adapter trimming and quality filtering.
- Produces paired trimmed FASTQ files.
- Generates trimming reports.

### 3. Metagenomic Assembly – MEGAHIT
- Performs de novo metagenomic assembly.
- Produces assembled contigs in FASTA format.
- Uses a memory-efficient assembly approach.

### 4. Gene Prediction – Prodigal
- Identifies potential protein-coding genes from assembled contigs.
- Generates nucleotide sequences, protein sequences, GFF annotations, and GenBank-format output.

### 5. Functional Annotation – COGclassifier
- Performs functional classification of predicted proteins.
- Uses a COG database and BLAST-based searches.
- Generates COG classification and count tables.

### 6. Taxonomic Classification – Kraken2
- Classifies sequencing reads using a Kraken2 reference database.
- Generates classification output and taxonomic reports.

### 7. Abundance Estimation – Bracken
- Estimates taxonomic abundance from Kraken2 classification results.
- Produces species-level abundance estimates using the configured Bracken parameters.

### 8. BIOM Conversion – kraken-biom
- Converts the Kraken2 taxonomic report into BIOM format.

### 9. OTU Table Generation – BIOM-format
- Converts the BIOM file into a tab-separated table.
- Produces a TSV output for downstream analysis.

## Repository Structure

```text
Tetragonlairidipennis/
│
├── config/
│   └── config.sh
│
├── docker/
│   ├── Dockerfile
│   ├── images.txt
│   └── bioinfo-tools/
│       ├── Dockerfile
│       └── requirements.txt
│
├── scripts/
│   ├── run_wms.sh
│   └── pull_docker_images.sh
│
├── data/
│   └── raw/                 # Local input FASTQ files; not uploaded
│
├── results/
│   ├── assembly/
│   ├── gene_prediction/
│   ├── cog_annotation/
│   ├── kraken2/
│   ├── bracken/
│   ├── biom/
│   └── qc/
│
├── logs/                    # Local execution logs; not uploaded
│
├── .gitignore
└── README.md
```

## Docker Images

The pipeline uses separate Docker images for the individual tools.

| Tool | Docker Image |
|---|---|
| FastQC | `staphb/fastqc:0.12.1` |
| Trim Galore | `ghcr.io/felixkrueger/trimgalore:latest` |
| MEGAHIT | `getwilds/megahit:1.2.9` |
| Prodigal | `microbiomeinformatics/prodigal:2.6.3` |
| Kraken2 | `staphb/kraken2:2.1.3` |
| Bracken | `staphb/bracken:3.1` |
| Supporting Python tools | `kparate/wms-bioinfo-tools:1.0` |

**Docker Hub:** [kparate/wms-pipeline](https://hub.docker.com/r/kparate/wms-pipeline)

The custom `kparate/wms-pipeline:1.0` image is a separate utility image. The pipeline's individual bioinformatics tools use their respective container images.

## Requirements

- Ubuntu Linux or Ubuntu on WSL2
- Docker Engine or Docker Desktop with WSL integration
- Bash
- Paired-end FASTQ files
- Kraken2 reference database
- Bracken database distribution file matching the configured read length
- COG database
- Sufficient storage for sequencing data, databases, and assembly outputs

## Input Data

The pipeline expects paired-end FASTQ files:

```text
data/
└── raw/
    ├── Tetragonlairidipennis_1.fastq.gz
    └── Tetragonlairidipennis_2.fastq.gz
```

Large sequencing files and reference databases are excluded from this GitHub repository. Users must provide their own input files and configure the database locations locally.

## Running the Pipeline

### 1. Clone the repository

```bash
git clone https://github.com/Krunalparate123/docker-wms-mini-pipeline.git
cd docker-wms-mini-pipeline
```

### 2. Prepare the input data

Create the input directory and place your paired-end FASTQ files inside:

```bash
mkdir -p data/raw
```

Use the filenames expected by the pipeline or update the configuration accordingly.

### 3. Configure database paths

Update `config/config.sh` with the local paths to:

- Kraken2 database
- COG database
- Input FASTQ files
- Thread settings
- Bracken parameters

The databases must be downloaded separately and are not included in this repository.

### 4. Pull Docker images

```bash
bash scripts/pull_docker_images.sh
```

### 5. Execute the pipeline

```bash
bash scripts/run_wms.sh
```

**Note:** Check the configuration and path settings in the scripts before running. The pipeline requires the input files and databases to be available at the configured locations.

## Expected Results

The pipeline generates the following outputs:

| Analysis | Example output |
|---|---|
| Raw read QC | FastQC HTML reports |
| Trimmed read QC | FastQC HTML reports |
| Assembly | `final.contigs.fa` |
| Gene prediction | `genes.gff`, `genes.fna`, `proteins.faa` |
| Functional annotation | `cog_classify.tsv`, `cog_count.tsv` |
| Taxonomic classification | Kraken2 report |
| Abundance estimation | Bracken output |
| BIOM conversion | `.biom` file |
| OTU table | `OTU_TABLE.tsv` |

Example output locations:

```text
results/
├── assembly/megahit/final.contigs.fa
├── gene_prediction/
├── cog_annotation/
├── kraken2/
├── bracken/
├── biom/otu_table/OTU_TABLE.tsv
└── qc/
```

## Reproducibility and Containerization

This project uses Docker containers to isolate bioinformatics tools and their dependencies.

Key implementation features:

- Container-based execution of individual tools.
- Bash-based pipeline automation.
- Separate configuration for sample and database settings.
- Modular workflow with distinct analysis stages.
- Organized output directories for downstream analysis.
- GitHub version control for project files and scripts.

## Future Improvements

- Implement workflow management using Nextflow.
- Add MultiQC-based consolidated QC reporting.
- Integrate alpha and beta diversity analysis.
- Generate taxonomic abundance visualizations.
- Add phylogenetic analysis.
- Integrate AMR and virulence factor annotation.
- Extend functional analysis using KEGG and other databases.

## Author

**Krunal Parate**  
B.Tech – Biomedical Engineering with Honors in Bioinformatics

- GitHub: [Krunalparate123](https://github.com/Krunalparate123)
- Project Repository: [Docker WMS Mini Pipeline](https://github.com/Krunalparate123/docker-wms-mini-pipeline)
- Docker Hub: [kparate](https://hub.docker.com/u/kparate)

---

*This project was developed as a practical bioinformatics portfolio project to demonstrate metagenomic data processing, Docker-based tool execution, Bash automation, and functional and taxonomic analysis.*
