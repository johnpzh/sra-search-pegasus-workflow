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

set -euo pipefail

echo
echo "WORKSPACE: $(pwd)"
echo

SRA_LIST="$1"
REFERENCE="$2"
SCRIPT_DIR="../../scripts"

if [ -z "$SRA_LIST" ] || [ -z "$REFERENCE" ]; then
    echo "Usage: $0 <sra_id_list> <reference_fna>"
    exit 1
fi

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



echo
echo "#################################"
echo "# Task: Building bowtie2 index..."
echo "#################################"
echo
# Build bowtie2 index
set -x
bowtie2-build "$REFERENCE" reference
set +x


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
for ((id = 0; id < num_ids; id++)); do
    export SRA_ID="${SRA_IDS[$id]}"
    node_idx=$((id % NUM_NODES))
    running_node="${NODE_LIST[$node_idx]}"
    set -x
    srun -w "${running_node}" -n1 -N1 --exclusive \
        bash "${SCRIPT_DIR}/task.process_sra.sh" &
    set +x
done
wait


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
    local max_parents=2
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
            set -x
            # tar -czf "$out_file" "${chunk[@]}"
            node_idx=$((job_count % NUM_NODES))
            running_node="${NODE_LIST[$node_idx]}"
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
# set -x
add_merge "${BAM_FILES[@]}"
# set +x

echo
echo "Workflow complete."
echo