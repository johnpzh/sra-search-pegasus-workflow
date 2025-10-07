set -euo pipefail
# set -u

##########################################
# SRA_ID is passed from the parent script
##########################################

echo "#------------------"
echo "# Processing ${SRA_ID} on $(hostname)..."
echo "#------------------"

PROCESS_TIME_START=$(date +%s.%N)

###################################
# Data preparation before the task
###################################
if [ ! -v NEXTFLOW_ON ] || [ "${NEXTFLOW_ON}" != "on" ]; then
    echo "NEXTFLOW_ON is not set to 'on', do data preparation for local bash run."
    sra_dir="${SRA_POOL_DIR}/${SRA_ID}"
    if [ ! -d "$sra_dir" ]; then
        echo "Error: SRA directory $sra_dir does not exist."
        exit 1
    fi

    set -x
    ln -s "${sra_dir}" ./
    set +x
else
    echo "NEXTFLOW_ON is set to '${NEXTFLOW_ON}', the data movement is done by Nextflow script."
fi

##########################################################
# Download FASTQ. If the cache is available, no download.
##########################################################
set -x
LD_PRELOAD="${DATALIFE_LIB_PATH}" DATALIFE_TASK_NAME="fasterq-dump" \
    fasterq-dump --split-files "${SRA_ID}"
set +x

########################################
# bowtie2-samtools create *.bam
########################################
set -x
# bowtie2 -p 1 -q --no-unal -x reference -1 *_1.fastq -2 *_2.fastq |
LD_PRELOAD="${DATALIFE_LIB_PATH}" DATALIFE_TASK_NAME="bowtie2-samtools" \
    bowtie2 -p 1 -q --no-unal -x reference -1 "${SRA_ID}_1.fastq" -2 "${SRA_ID}_2.fastq" | \
        samtools view -bS - | \
        samtools sort -T tmp -O Bam -o "${SRA_ID}.bam" -
set +x

#############################
# samtools creates *.bam.bai
#############################
set -x
LD_PRELOAD="${DATALIFE_LIB_PATH}" DATALIFE_TASK_NAME="samtools" \
    samtools index "${SRA_ID}.bam"
set +x

PROCESS_TIME_END=$(date +%s.%N)
PROCESS_TIME_EXE=$(echo "${PROCESS_TIME_END} - ${PROCESS_TIME_START}" | bc -l)
echo
echo "PROCESS_TIME_EXE(s): ${PROCESS_TIME_EXE} SRA_ID: ${SRA_ID}"
echo
