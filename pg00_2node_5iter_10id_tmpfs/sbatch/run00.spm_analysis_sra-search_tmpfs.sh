#!/bin/bash
#SBATCH --job-name="spm_tmpfs_sra-search"
#SBATCH --partition=slurm
######SBATCH --exclude=dc[119,077]
#SBATCH --account=oddite
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

set -u

PREV_DIR="$(readlink -f .)"
export WORKFLOW_NAME="sra_search"
# export SPM_ANALYSIS_DIR="${PREV_DIR}/../../submodules/spm/workflow_analysis"
# export SPM_INPUT_DATA_DIR="${PREV_DIR}/../../submodules/spm/workflow_analysis/sra_search/sra_search_4n_999ids"
export SPM_ANALYSIS_DIR="/people/peng599/Projects/Datamesh/qfs/FlowForecaster/AutoFlowFlexer/submodules/spm/workflow_analysis"
export SPM_INPUT_DATA_DIR="/people/peng599/Projects/Datamesh/qfs/FlowForecaster/AutoFlowFlexer/submodules/spm/workflow_analysis/sra_search/sra_search_4n_999ids"
export DATALIFE_FILES_DIR="${PREV_DIR}/datalife_stats"

set -x
bash ../scripts/sh00.spm_analysis.sh
set +x