set -euo pipefail

##########################################
# SRA_ID is passed from the parent script
##########################################

echo "#------------------"
echo "# Processing ${SRA_ID} on $(hostname)..."
echo "#------------------"

# Download FASTQ
set -x
fasterq-dump --split-files "${SRA_ID}"
set +x

# Align with bowtie2 and create BAM/BAI
set -x
# bowtie2 -p 1 -q --no-unal -x reference -1 *_1.fastq -2 *_2.fastq | \
bowtie2 -p 1 -q --no-unal -x reference -1 "${SRA_ID}_1.fastq" -2 "${SRA_ID}_2.fastq" | \
  samtools view -bS - | \
  samtools sort -T tmp -O Bam -o "${SRA_ID}.bam" -
samtools index "${SRA_ID}.bam"
set +x