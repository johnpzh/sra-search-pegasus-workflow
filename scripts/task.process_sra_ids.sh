set -euo pipefail
# set -u

##########################################
# SRA_ID is passed from the parent script
##########################################

echo "#------------------"
echo "# Processing ${SRA_ID} on $(hostname)..."
echo "#------------------"

PROCESS_TIME_START=$(date +%s.%N)

sra_dir="${SRA_POOL_DIR}/${SRA_ID}"
if [ ! -d "$sra_dir" ]; then
    echo "Error: SRA directory $sra_dir does not exist."
    exit 1
fi

set -x
ln -s "${sra_dir}" ./
set +x

# Download FASTQ
set -x
LD_PRELOAD="${DATALIFE_LIB_PATH}" DATALIFE_TASK_NAME="fasterq-dump" \
    fasterq-dump --split-files "${SRA_ID}"
set +x

# Align with bowtie2 and create BAM/BAI
set -x
# bowtie2 -p 1 -q --no-unal -x reference -1 *_1.fastq -2 *_2.fastq |
LD_PRELOAD="${DATALIFE_LIB_PATH}" DATALIFE_TASK_NAME="bowtie2-samtools" \
    bowtie2 -p 1 -q --no-unal -x reference -1 "${SRA_ID}_1.fastq" -2 "${SRA_ID}_2.fastq" | \
        samtools view -bS - | \
        samtools sort -T tmp -O Bam -o "${SRA_ID}.bam" -

LD_PRELOAD="${DATALIFE_LIB_PATH}" DATALIFE_TASK_NAME="samtools" \
    samtools index "${SRA_ID}.bam"
set +x

PROCESS_TIME_END=$(date +%s.%N)
PROCESS_TIME_EXE=$(echo "${PROCESS_TIME_END} - ${PROCESS_TIME_START}" | bc -l)
echo
echo "PROCESS_TIME_EXE(s): ${PROCESS_TIME_EXE} SRA_ID: ${SRA_ID}"
echo
