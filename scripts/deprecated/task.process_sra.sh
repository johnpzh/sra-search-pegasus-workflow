# set -euo pipefail

# ##########################################
# # SRA_ID is passed from the parent script
# ##########################################

# echo "#------------------"
# echo "# Processing ${SRA_ID} on $(hostname)..."
# echo "#------------------"

# # Download FASTQ
# set -x
# fasterq-dump --split-files "${SRA_ID}"
# set +x

# # Align with bowtie2 and create BAM/BAI
# set -x
# # bowtie2 -p 1 -q --no-unal -x reference -1 *_1.fastq -2 *_2.fastq | \
# bowtie2 -p 1 -q --no-unal -x reference -1 "${SRA_ID}_1.fastq" -2 "${SRA_ID}_2.fastq" | \
#   samtools view -bS - | \
#   samtools sort -T tmp -O Bam -o "${SRA_ID}.bam" -
# samtools index "${SRA_ID}.bam"
# set +x


#!/bin/bash

set -euo pipefail

# Validate SRA_ID
if [ -z "${SRA_ID}" ]; then
    echo "Error: SRA_ID is unset or empty."
    exit 1
fi

echo "#------------------"
echo "# Processing ${SRA_ID} on $(hostname)..."
echo "#------------------"

# Download FASTQ
echo "Running fasterq-dump..."
set -x
fasterq-dump --split-files "${SRA_ID}" 2> fasterq-dump.log
EXIT_CODE=$?
set +x
if [ $EXIT_CODE -ne 0 ]; then
    echo "Error: fasterq-dump failed with exit code $EXIT_CODE. Check fasterq-dump.log."
    exit $EXIT_CODE
fi

# Verify FASTQ files exist
if [ ! -f "${SRA_ID}_1.fastq" ] || [ ! -f "${SRA_ID}_2.fastq" ]; then
    echo "Error: FASTQ files (${SRA_ID}_1.fastq or ${SRA_ID}_2.fastq) not found."
    exit 1
fi

# Verify reference index
if [ ! -f "reference.1.bt2" ]; then
    echo "Error: Bowtie2 reference index (reference.1.bt2) not found."
    exit 1
fi

# Ensure tmp directory exists
mkdir -p tmp || { echo "Error: Cannot create tmp directory."; exit 1; }

# Align with bowtie2 and create BAM/BAI
echo "Running bowtie2 and samtools pipeline..."
set -x
bowtie2 -p 1 -q --no-unal -x reference -1 "${SRA_ID}_1.fastq" -2 "${SRA_ID}_2.fastq" 2> bowtie2.log | \
  samtools view -bS - 2> samtools_view.log | \
  samtools sort -T tmp -O Bam -o "${SRA_ID}.bam" - 2> samtools_sort.log
EXIT_CODE=$?
set +x
if [ $EXIT_CODE -ne 0 ]; then
    echo "Error: Pipeline failed with exit code $EXIT_CODE. Check bowtie2.log, samtools_view.log, or samtools_sort.log."
    exit $EXIT_CODE
fi

echo "Indexing BAM file..."
set -x
samtools index "${SRA_ID}.bam" 2> samtools_index.log
EXIT_CODE=$?
set +x
if [ $EXIT_CODE -ne 0 ]; then
    echo "Error: samtools index failed with exit code $EXIT_CODE. Check samtools_index.log."
    exit $EXIT_CODE
fi

echo "Processing completed successfully."