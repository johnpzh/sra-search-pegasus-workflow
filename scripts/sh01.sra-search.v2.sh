#!/bin/bash

# Prerequisites:
# - Bowtie2, Samtools, NCBI SRA Toolkit (fasterq-dump).
# - Submit with: sbatch this_script.sh tests/10/sra_ids.txt tests/10/crassphage.fna

set -euo pipefail
# set -u

#----------------------------------------
# Entry, checking commandline parameters
#----------------------------------------
SRA_LIST="$1"
REFERENCE="$2"


if [ -z "$SRA_LIST" ] || [ -z "$REFERENCE" ]; then
    echo "Usage: $0 <sra_id_list> <reference_fna>"
    exit 1
fi

SCRIPT_DIR="../../scripts"
MERGE_CHUNK_SIZE=50
echo
echo "WORKSPACE: $(pwd)"
echo

#-------------------
# Slurm Environment
#-------------------
NODE_LIST=()
if [ -v SLURM_JOB_NODELIST ]; then
    NODE_NAMES=`echo $SLURM_JOB_NODELIST | scontrol show hostnames`

    while read -ra tmp; do
        NODE_LIST+=("${tmp[@]}")
    done <<< "$NODE_NAMES"

    NODES_STRING=$(echo "$NODE_NAMES" | tr '\n' ',')
    echo "NODES_STRING: $NODES_STRING"
    echo "NODE_LIST: ${NODE_LIST[@]}"
fi
NUM_NODES=$SLURM_JOB_NUM_NODES
export NODE_LIST


#----------
# Workflow
#----------
echo
echo "#################################"
echo "# Task: Building bowtie2 index..."
echo "#################################"
echo
# Build bowtie2 index
export REFERENCE
BOWTIE2_BUILD_INDEX_TIME_START=$(date +%s.%N)
set -x
# bowtie2-build "$REFERENCE" reference
# LD_PRELOAD="${DATALIFE_LIB_PATH}" DATALIFE_TASK_NAME="bowtie2_build_index" \
    srun -n1 -N1 --exclusive \
        bash "${SCRIPT_DIR}/task.bowtie2_build_index.sh" &
set +x
wait
BOWTIE2_BUILD_INDEX_TIME_END=$(date +%s.%N)
BOWTIE2_BUILD_INDEX_TIME_EXE=$(echo "${BOWTIE2_BUILD_INDEX_TIME_END} - ${BOWTIE2_BUILD_INDEX_TIME_START}" | bc -l)
echo
echo "BOWTIE2_BUILD_INDEX_TIME_EXE(s): ${BOWTIE2_BUILD_INDEX_TIME_EXE}"
echo


echo
echo "########################################################"
echo "# Task: Processing SRA IDs in parallel..."
echo "########################################################"
echo

# Read SRA IDs, skipping short/empty lines
set -x
mapfile -t SRA_IDS < <(grep '^SRR' "$SRA_LIST" || true)
set +x

if [ ${#SRA_IDS[@]} -eq 0 ]; then
    echo "No valid SRA IDs found in $SRA_LIST"
    exit 1
fi


# Run in parallel
num_ids=${#SRA_IDS[@]}
echo
echo "num_ids: ${num_ids}"
echo
PROCESS_SRA_TIME_START=$(date +%s.%N)
batch_size=$((NUM_NODES * 8))
for ((id = 0; id < num_ids; id++)); do
    export SRA_ID="${SRA_IDS[$id]}"
    node_idx=$((id % NUM_NODES))
    running_node="${NODE_LIST[$node_idx]}"
    set -x
    # LD_PRELOAD="${DATALIFE_LIB_PATH}" DATALIFE_TASK_NAME="process_sra_ids"
        srun -w "${running_node}" -n1 -N1 --exclusive \
            bash "${SCRIPT_DIR}/task.process_sra_ids.sh" &
    set +x

    # # test timeout
    # export SCRIPT_DIR
    # set -x
    # srun -w "${running_node}" -n1 -N1 --exclusive \
    #     bash "${SCRIPT_DIR}/debug.timeout_process_sra_ids.sh" &
    # set +x

    # if (( (id + 1) % (NUM_NODES * 8) == 0 )); then
    #     wait
    # fi
    # # end test timeout

    # test
    while [ $(jobs -r | wc -l) -ge ${batch_size} ]; do
        echo "Waiting for ${batch_size} jobs to finish..."
        sleep 1
    done

    echo
    echo "Current job count: $((id + 1))"
    echo "Current running jobs number: $(jobs -r | wc -l) / ${batch_size}"
    echo "Current open files number: $(lsof -p $$ | wc -l)"
    echo
    # end test
done
wait
PROCESS_SRA_TIME_END=$(date +%s.%N)
PROCESS_SRA_TIME_EXE=$(echo "${PROCESS_SRA_TIME_END} - ${PROCESS_SRA_TIME_START}" | bc -l)
echo
echo "PROCESS_SRA_TIME_EXE(s): ${PROCESS_SRA_TIME_EXE}"
echo


echo
echo "##########################"
echo "# Task: Merging results..."
echo "##########################"
echo
# Collect all BAM and BAI files for merging
BAM_FILES=(*.bam *.bam.bai)

# Hierarchical merge function
add_merge() {
    local -a parents=("${@}")
    local max_parents="${MERGE_CHUNK_SIZE}"
    local level=1
    local job_count=0

    while [ ${#parents[@]} -gt 1 ]; do
        local -a children=()
        local job_count=0

        echo "#--------------------------------------------"
        echo "# Level: $level with ${#parents[@]} parents"
        echo "# Parents: ${parents[@]}"
        echo "#--------------------------------------------"

        for ((i=0; i<${#parents[@]}; i+=max_parents)); do
            local -a chunk=("${parents[@]:i:max_parents}")
            job_count=$((job_count + 1))

            local out_file="results-l${level}-j${job_count}.tar.gz"
            if [ ${#parents[@]} -le $max_parents ]; then
                out_file="results.tar.gz"
            fi

            echo "#--------------------------------------------"
            echo "# Merging chunk ${chunk[@]} into $out_file..."
            echo "#--------------------------------------------"
            export LEVEL="${level}"
            export JOB_COUNT="${job_count}"
            node_idx=$((job_count % NUM_NODES))
            running_node="${NODE_LIST[$node_idx]}"
            set -x
            # LD_PRELOAD="${DATALIFE_LIB_PATH}" DATALIFE_TASK_NAME="merge_files"
                srun -w "${running_node}" -n1 -N1 --exclusive \
                    bash "${SCRIPT_DIR}/task.merge.sh" "$out_file" "${chunk[@]}" &
            set +x
            children+=("$out_file")
        done
        wait

        level=$((level + 1))
        parents=("${children[@]}")
    done
}

# Perform the merge
MERGE_TASK_TIME_START=$(date +%s.%N)
# set -x
add_merge "${BAM_FILES[@]}"
# set +x
MERGE_TASK_TIME_END=$(date +%s.%N)
MERGE_TASK_TIME_EXE=$(echo "${MERGE_TASK_TIME_END} - ${MERGE_TASK_TIME_START}" | bc -l)
echo
echo "MERGE_TASK_TIME_EXE(s): ${MERGE_TASK_TIME_EXE}"
echo

echo
echo "Workflow complete."
echo