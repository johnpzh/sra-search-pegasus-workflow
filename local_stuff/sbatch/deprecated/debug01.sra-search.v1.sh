
# set -euo pipefail
set -euo pipefail

SLURM_JOB_ID=1111
SLURM_JOB_NODELIST=node1111
num_tests=10
workspace="output.workspace.${SLURM_JOB_ID}.debug_workflow"
script="../../scripts/test01.sra-search.v1.sh"
id_list_file="../../tests/${num_tests}/sra_ids.txt"
reference_file="../../tests/${num_tests}/crassphage.fna"

output="output.sra-search-test.$(date +%FT%T).log"

echo
echo "num_tests: ${num_tests}"
echo "id_list_file: ${id_list_file}"
echo "reference_file: ${reference_file}"
echo "workspace: ${workspace}"
echo "SLURM_JOB_NODELIST: ${SLURM_JOB_NODELIST}"
echo

TT_TIME_START=$(date +%s.%N)

######################
# Run the workflow
######################

set -x
if [ ! -d "${workspace}" ]; then
    mkdir -p "${workspace}"
fi
cd "${workspace}"
bash "${script}" "${id_list_file}" "${reference_file}" 2>&1 | tee "${output}"
set +x

# ######################
# # Show all job states
# ######################
# echo
# echo "Job State Summary:"
# hostname;date;
# sacct -j $SLURM_JOB_ID -o jobid,submit,start,end,state

TT_TIME_END=$(date +%s.%N)
TT_TIME_EXE=$(echo "${TT_TIME_END} - ${TT_TIME_START}" | bc -l)
echo | tee -a "${output}"
echo "TT_TIME_EXE(s): ${TT_TIME_EXE}" | tee -a "${output}"
echo | tee -a "${output}"
