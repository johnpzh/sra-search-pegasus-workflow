#!/bin/bash
#SBATCH --job-name="sra_v2_datalife"
#SBATCH --partition=slurm
######SBATCH --partition=short
######SBATCH --exclude=dc[119,077]
#SBATCH --account=datamesh
#SBATCH -N 1
#SBATCH --time=01:01:01
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
# module load rocm/5.6.0
#module load cuda/12.3
# Modules needed by Orca
module load gcc/11.2.0 binutils/2.35 cmake/3.29.0
#module load openmpi/4.1.4
#module load mkl
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

# set -euo pipefail
set -u

export PREV_PWD=$(readlink -f .)
export DATALIFE_LIB_PATH="/qfs/projects/oddite/peng599/FlowForecaster/datalife_Candice/build/flow-monitor/src/libmonitor.so"
# export DATALIFE_LIB_PATH="/qfs/projects/oddite/lenny/projects/datalife/install/lib/libmonitor.so"
export DATALIFE_OUTPUT_PATH="${PREV_PWD}/datalife_stats"
# export DATALIFE_FILE_PATTERNS="\
# *.fits, *.vcf, *.lht, *.fna, *.*.bt2, \
# *.fastq, *.fasta.amb, *.fasta.sa, *.fasta.bwt, *.fasta.pac, \
# *.fasta.ann, *.fasta, *.stf, *.out, *.dot, \
# *.gz, *.tar.gz, *.dcd, *.pt, *.h5, \
# *.nc, *SAS, *EAS, *GBR, *AMR, \
# *AFR, *EUR, *ALL, *.chr*.txt, *.datalifetest, \
# columns.txt, \
# *.sra, *.fastq, *.bam, *.bam.bai \
# "
# export DATALIFE_FILE_PATTERNS="\
# *.fits, *.vcf, *.lht, \
# *.fastq, *.fasta.amb, *.fasta.sa, *.fasta.bwt, *.fasta.pac, \
# *.fasta.ann, *.fasta, *.stf, *.out, *.dot, \
# *.gz, *.tar.gz, *.dcd, *.pt, *.h5, \
# *.nc, *SAS, *EAS, *GBR, *AMR, \
# *AFR, *EUR, *ALL, *.chr*.txt, *.datalifetest, \
# columns.txt, \
# *.fna, \
# reference.2.bt2, reference.3.bt2, reference.4.bt2, reference.rev.1.bt2, reference.rev.2.bt2, \
# *.sra, *.fastq, *.bam, *.bam.bai \
# "
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

rm -rf "${DATALIFE_OUTPUT_PATH}"
mkdir -p "${DATALIFE_OUTPUT_PATH}"

export SRA_POOL_DIR="../../data"

num_tests=1
workspace="output.workspace.${SLURM_JOB_NAME}.${SLURM_JOB_ID}.$(date +%FT%T)"
script="../../scripts/sh01.sra-search.v2.sh"
id_list_file="../../tests/${num_tests}/sra_ids.txt"
reference_file="../../tests/${num_tests}/crassphage.fna"

output="output.sra-search-test.$(date +%FT%T).log"

echo
echo "num_tests: ${num_tests}"
echo "id_list_file: ${id_list_file}"
echo "reference_file: ${reference_file}"
echo "workspace: ${workspace}"
echo "SLURM_JOB_NUM_NODES: ${SLURM_JOB_NUM_NODES}"
echo "SLURM_JOB_NODELIST: ${SLURM_JOB_NODELIST}"
echo

TT_TIME_START=$(date +%s.%N)

######################
# Run the workflow
######################

set -x
mkdir "${workspace}"
cd "${workspace}"
bash "${script}" "${id_list_file}" "${reference_file}" 2>&1 | tee "${output}"
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
echo | tee -a "${output}"
echo "TT_TIME_EXE(s): ${TT_TIME_EXE}" | tee -a "${output}"
echo | tee -a "${output}"
