#!/bin/bash
#SBATCH --job-name="beegfs_sra_nf_2node_5iter_10id"
#SBATCH --partition=slurm
######SBATCH --partition=short
######SBATCH --exclude=dc[119,077]
#SBATCH --account=oddite
#SBATCH -N 2
######SBATCH --time=01:01:01
#SBATCH --time=44:44:44
#SBATCH --output=output.%x.%j.out.log
#SBATCH --error=output.%x.%j.err.log
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=zhen.peng@pnnl.gov
#SBATCH --exclusive

#### sinfo -p <partition>
#### sinfo -N -r -l
#### srun -A CENATE -N 1 -t 20:20:20 --pty -u /bin/bash

#First make sure the module commands are available.
source /etc/profile.d/modules.sh

#Set up your environment you wish to run in with module commands.
echo
echo "loaded modules"
echo
module purge
module load java/24.0.2 python/miniconda25.5.1
module list &> _modules.lis_
cat _modules.lis_
/bin/rm -f _modules.lis_

#Python version
source /share/apps/python/miniconda25.5.1/etc/profile.d/conda.sh
eval "$(conda shell.bash hook)"
conda activate pp
echo
echo "python version"
echo
command -v python
python --version
export PYTHON_PATH=$(command -v python)


#Next unlimit system resources, and set any other environment variables you need.
ulimit -s unlimited
echo
echo limits
echo
ulimit -a

#Is extremely useful to record the modules you have loaded, your limit settings,
#your current environment variables and the dynamically load libraries that your executable
#is linked against in your job output file.
# echo
# echo "loaded modules"
# echo
# module list &> _modules.lis_
# cat _modules.lis_
# /bin/rm -f _modules.lis_
# echo
# echo limits
# echo
# ulimit -a
echo
echo "Environment Variables"
echo
printenv
# echo
# echo "ldd output"
# echo
# ldd your_executable

#Now you can put in your parallel launch command.
#For each different parallel executable you launch we recommend
#adding a corresponding ldd command to verify that the environment
#that is loaded corresponds to the environment the executable was built in.


set -euo pipefail

# # Shell testing
# SLURM_JOB_ID=111
# SLURM_JOB_NUM_NODES=1
# # End Shell testing

export PREV_PWD=$(readlink -f .)
export DATALIFE_LIB_PATH="/qfs/projects/oddite/peng599/FlowForecaster/datalife_Candice/build/flow-monitor/src/libmonitor.so"
# export DATALIFE_LIB_PATH="/qfs/projects/oddite/lenny/projects/datalife/install/lib/libmonitor.so"
export DATALIFE_OUTPUT_PATH="${PREV_PWD}/datalife_stats"
export DATALIFE_FILE_PATTERNS="\
*.fits, *.vcf, *.lht, \
*.fastq, *.fasta.amb, *.fasta.sa, *.fasta.bwt, *.fasta.pac, \
*.fasta.ann, *.fasta, *.stf, *.out, *.dot, \
*.gz, *.tar.gz, *.dcd, *.pt, *.h5, \
*.nc, *SAS, *EAS, *GBR, *AMR, \
*AFR, *EUR, *ALL, *.chr*.txt, *.datalifetest, \
columns.txt, \
reference.2.bt2, reference.3.bt2, reference.4.bt2, reference.rev.1.bt2, reference.rev.2.bt2, \
*.fastq, *.bam, *.bam.bai \
"

NUM_TESTS=10
NF_WORKSPACE="output.nf.workspace.${SLURM_JOB_ID}.$(date +%FT%T)"
NF_SCRIPT="${PREV_PWD}/../scripts/nf00.sra-search.v0.nf"
WORKFLOW_SCRIPTS_DIR="${PREV_PWD}/../scripts"
DATAMOVEMENT_SCRIPTS_DIR="${PREV_PWD}/../scripts_datamovement"
REFERENCE_FILE_DIR="${PREV_PWD}/../tests/${NUM_TESTS}"
ID_LIST_FILE="${REFERENCE_FILE_DIR}/sra_ids.txt"
REFERENCE_FILE="${REFERENCE_FILE_DIR}/crassphage.fna"
NFS_ORIGIN_DATA_DIR="${PREV_PWD}/../data"

# rm -rf "${DATALIFE_OUTPUT_PATH}"
if [ ! -d "${DATALIFE_OUTPUT_PATH}" ]; then
    mkdir -p "${DATALIFE_OUTPUT_PATH}"
fi

NODE_LIST=()
if [ -v SLURM_JOB_NODELIST ]; then
    NODE_NAMES=`echo $SLURM_JOB_NODELIST | scontrol show hostnames`

    while read -ra tmp; do
        NODE_LIST+=("${tmp[@]}")
    done <<< "$NODE_NAMES"

    NODES_STRING=$(echo "$NODE_NAMES" | tr '\n' ',')
    echo "NODES_STRING: $NODES_STRING"
else
    NODES_STRING=""
    SLURM_JOB_NODELIST=""
fi

echo
echo "NUM_TESTS: ${NUM_TESTS}"
echo "ID_LIST_FILE: ${ID_LIST_FILE}"
echo "REFERENCE_FILE: ${REFERENCE_FILE}"
echo "SLURM_JOB_NUM_NODES: ${SLURM_JOB_NUM_NODES}"
echo "SLURM_JOB_NODELIST: ${SLURM_JOB_NODELIST}"
echo


TT_TIME_START=$(date +%s.%N)

#####################################################################################
# 1. Run SPM Linux storage explorer (only need running once), get all storage paths.
#####################################################################################
LOCAL_DIR_CONFIG="local_dir_config.csv"

###############################
# 2. run SPM, dump the ranking
###############################
SPM_RESULTS_FILE="workflow_spm_results/sra_search_filtered_spm_results.v0.4n_999ids.csv"

##############################################################################
# 3. Run Storage Selection Algorithm, output the storage selections for tasks.
##############################################################################

STORAGE_CONFIG_TIME_START=$(date +%s.%N)

STORAGE_CONFIG_FILE="nextflow.config.params.storage.nf"
python ../scripts/py01.select_storage_type_from_spm.sra_search.v3.beegfs.py \
    -s "${SPM_RESULTS_FILE}" \
    -l "${LOCAL_DIR_CONFIG}" \
    -o "${STORAGE_CONFIG_FILE}"

STORAGE_CONFIG_TIME_END=$(date +%s.%N)
STORAGE_CONFIG_TIME_EXE=$(echo "${STORAGE_CONFIG_TIME_END} - ${STORAGE_CONFIG_TIME_START}" | bc -l)
echo
echo "STORAGE_CONFIG_TIME_EXE(s): ${STORAGE_CONFIG_TIME_EXE}"
echo

########################################################################################
# 4. Pass the paths to Nextflow, and run Nextflow. Do data movement based on the paths.
########################################################################################

num_iterations=5

WORKFLOW_TIME_START=$(date +%s.%N)

for ((iter = 0; iter < num_iterations; iter++)); do

    ITERATION_TIME_START=$(date +%s.%N)
    echo
    echo "WORKFLOW_ITERATION: ${iter}"
    echo
    set -x
    nextflow run "${NF_SCRIPT}" \
        --id_list_file "${ID_LIST_FILE}" \
        --reference_file "${REFERENCE_FILE}" \
        --num_nodes ${SLURM_JOB_NUM_NODES} \
        --node_list "${NODES_STRING}" \
        --script_dir "${WORKFLOW_SCRIPTS_DIR}" \
        --datamovement_scripts_dir "${DATAMOVEMENT_SCRIPTS_DIR}" \
        --reference_file_dir "${REFERENCE_FILE_DIR}" \
        --datalife_lib_path "${DATALIFE_LIB_PATH}" \
        --python_path "${PYTHON_PATH}" \
        --nfs_origin_data_dir "${NFS_ORIGIN_DATA_DIR}" \
        -c "${STORAGE_CONFIG_FILE}" \
        -work-dir "${NF_WORKSPACE}" \
        -ansi-log false
    set +x
    ITERATION_TIME_END=$(date +%s.%N)
    ITERATION_TIME_EXE=$(echo "${ITERATION_TIME_END} - ${ITERATION_TIME_START}" | bc -l)
    echo
    echo "ITERATION_TIME_EXE(s) for iteration ${iter}: ${ITERATION_TIME_EXE}"
    echo
done

WORKFLOW_TIME_END=$(date +%s.%N)
WORKFLOW_TIME_EXE=$(echo "${WORKFLOW_TIME_END} - ${WORKFLOW_TIME_START}" | bc -l)
echo
echo "WORKFLOW_TIME_EXE(s) for ${num_iterations} iterations: ${WORKFLOW_TIME_EXE}"
echo

######################
# Show all job states
######################
echo
echo "Job State Summary:"
hostname;date;
sacct -j $SLURM_JOB_ID -o jobid,submit,start,end,state

TT_TIME_END=$(date +%s.%N)
TT_TIME_EXE=$(echo "${TT_TIME_END} - ${TT_TIME_START}" | bc -l)
echo
echo "TT_TIME_EXE(s): ${TT_TIME_EXE}"
echo