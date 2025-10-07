#!/bin/bash
#SBATCH --job-name="sra_nf_v0"
#SBATCH --partition=slurm
######SBATCH --exclude=dc[119,077]
#SBATCH --account=datamesh
#SBATCH -N 1
#SBATCH --time=04:44:44
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
# module load gcc/11.2.0 binutils/2.35 cmake/3.29.0
#module load openmpi/4.1.4
#module load mkl
module load java/23.0.1
module list &> _modules.lis_
cat _modules.lis_
/bin/rm -f _modules.lis_

#Python version
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

# #Python version
# echo
# echo "python version"
# echo
# command -v python
# python --version
# export PYTHON_PATH=$(command -v python)

# SLURM_JOB_ID=111
# SLURM_JOB_NUM_NODES=1

export PREV_PWD=$(readlink -f .)
export DATALIFE_LIB_PATH="/qfs/projects/oddite/peng599/FlowForecaster/datalife_Candice/build/flow-monitor/src/libmonitor.so"
export DATALIFE_OUTPUT_PATH="${PREV_PWD}/datalife_stats"
export DATALIFE_FILE_PATTERNS="\
*.fits, *.vcf, *.lht, *.fna, *.*.bt2, \
*.fastq, *.fasta.amb, *.fasta.sa, *.fasta.bwt, *.fasta.pac, \
*.fasta.ann, *.fasta, *.stf, *.out, *.dot, \
*.gz, *.tar.gz, *.dcd, *.pt, *.h5, \
*.nc, *SAS, *EAS, *GBR, *AMR, \
*AFR, *EUR, *ALL, *.chr*.txt, *.datalifetest, \
columns.txt, \
*.sra, *.fastq, *.bam, *.bam.bai \
"

NUM_TESTS=1
NF_WORKSPACE="output.nf.workspace.${SLURM_JOB_ID}.$(date +%FT%T)"
NF_SCRIPT="/people/peng599/Projects/Datamesh/qfs/Workflows/sra-search-pegasus-workflow/scripts/nf00.sra-search.v0.nf"
WORKFLOW_SCRIPTS_DIR="/people/peng599/Projects/Datamesh/qfs/Workflows/sra-search-pegasus-workflow/scripts"
ID_LIST_FILE="/people/peng599/Projects/Datamesh/qfs/Workflows/sra-search-pegasus-workflow/tests/${NUM_TESTS}/sra_ids.txt"
REFERENCE_FILE="/people/peng599/Projects/Datamesh/qfs/Workflows/sra-search-pegasus-workflow/tests/${NUM_TESTS}/crassphage.fna"

rm -rf "${DATALIFE_OUTPUT_PATH}"
mkdir -p "${DATALIFE_OUTPUT_PATH}"

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
fi

echo
echo "NUM_TESTS: ${NUM_TESTS}"
echo "ID_LIST_FILE: ${ID_LIST_FILE}"
echo "REFERENCE_FILE: ${REFERENCE_FILE}"
echo "SLURM_JOB_NUM_NODES: ${SLURM_JOB_NUM_NODES}"
echo "SLURM_JOB_NODELIST: ${SLURM_JOB_NODELIST}"
echo

TT_TIME_START=$(date +%s.%N)

######################
# Set the Storage Type and Path
######################

# TODO: Replace the dummy script below

STORAGE_CONFIG_FILE="nextflow.config.params.storage.nf"
export SLURM_JOB_ID
export SLURM_JOB_NAME
bash ../scripts/test00.generate.nf.config.sh "${STORAGE_CONFIG_FILE}"


######################
# Run the workflow
######################

set -x
# mkdir "${WORKSPACE}"
# cd "${WORKSPACE}"
# bash "${NF_SCRIPT}" "${ID_LIST_FILE}" "${REFERENCE_FILE}" 2>&1 | tee "${output}"
nextflow run "${NF_SCRIPT}" \
    --id_list_file "${ID_LIST_FILE}" \
    --reference_file "${REFERENCE_FILE}" \
    --num_nodes ${SLURM_JOB_NUM_NODES} \
    --node_list "${NODES_STRING}" \
    --script_dir "${WORKFLOW_SCRIPTS_DIR}" \
    --datalife_lib_path "${DATALIFE_LIB_PATH}" \
    --python_path "${PYTHON_PATH}" \
    -c "${STORAGE_CONFIG_FILE}" \
    -work-dir "${NF_WORKSPACE}" \
    -ansi-log false \

set +x

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
