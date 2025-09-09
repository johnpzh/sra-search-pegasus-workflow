#!/bin/bash

# SLURM directives - adjust as needed for your cluster
#SBATCH --job-name=sra-search
#SBATCH --output=sra-search-%j.out
#SBATCH --error=sra-search-%j.err
#SBATCH --time=24:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20  # Adjust based on desired parallelism for downloads/alignments
#SBATCH --mem=64G  # Adjust based on your needs

# Usage: sbatch this_script.sh <path_to_sra_id_list> <path_to_reference_fna>

# Prerequisites:
# - Bowtie2, Samtools, NCBI SRA Toolkit (fasterq-dump), and GNU Parallel installed and in PATH.
# - SRA Toolkit configured via vdb-config.
# - Submit with: sbatch this_script.sh tests/10/sra_ids.txt tests/10/crassphage.fna

set -e  # Exit on error

SRA_LIST="$1"
REFERENCE="$2"

if [ -z "$SRA_LIST" ] || [ -z "$REFERENCE" ]; then
  echo "Usage: $0 <sra_id_list> <reference_fna>"
  exit 1
fi

# Build bowtie2 index
echo "Building bowtie2 index..."
bowtie2-build "$REFERENCE" reference

# Read SRA IDs, skipping short/empty lines
mapfile -t SRA_IDS < <(grep '^SRR' "$SRA_LIST" || true)

if [ ${#SRA_IDS[@]} -eq 0 ]; then
  echo "No valid SRA IDs found in $SRA_LIST"
  exit 1
fi

# Function to process one SRA ID
process_sra() {
  local id="$1"
  echo "Processing $id..."

  # Download FASTQ
  fasterq-dump --split-files "$id"

  # Align with bowtie2 and create BAM/BAI
  bowtie2 -p 1 -q --no-unal -x reference -1 *_1.fastq -2 *_2.fastq | \
    samtools view -bS - | \
    samtools sort -T tmp -O Bam -o "${id}.bam" -
  samtools index "${id}.bam"
}

export -f process_sra

# Run in parallel, limiting to 20 concurrent (like original workflow)
echo "Processing ${#SRA_IDS[@]} SRA IDs in parallel..."
parallel -j 20 process_sra ::: "${SRA_IDS[@]}"

# Collect all BAM and BAI files for merging
BAM_FILES=(*.bam *.bam.bai)

# Hierarchical merge function, adapted from the original workflow
add_merge() {
  local -a parents=("${@}")
  local max_parents=25
  local level=1
  local job_count=0

  while [ ${#parents[@]} -gt 1 ]; do
    local -a children=()
    job_count=0

    for ((i=0; i<${#parents[@]}; i+=max_parents)); do
      local -a chunk=("${parents[@]:i:max_parents}")
      job_count=$((job_count + 1))

      local out_file="results-l${level}-j${job_count}.tar.gz"
      if [ ${#parents[@]} -le $max_parents ]; then
        out_file="results.tar.gz"
      fi

      echo "Merging into $out_file..."
      tar -czf "$out_file" "${chunk[@]}"

      children+=("$out_file")
    done

    level=$((level + 1))
    parents=("${children[@]}")
  done
}

# Perform the merge
echo "Merging results..."
add_merge "${BAM_FILES[@]}"

echo "Workflow complete. Final output: results.tar.gz"