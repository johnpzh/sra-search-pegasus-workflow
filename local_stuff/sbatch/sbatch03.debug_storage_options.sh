TT_TIME_START=$(date +%s.%N)

#####################################################################################
# 1. Run SPM Linux storage explorer (only need running once), get all storage paths.
#####################################################################################
local_dir_config="local_dir_config.csv"

###############################
# 2. run SPM, dump the ranking
###############################
spm_results_file="workflow_spm_results/sra_search_filtered_spm_results.v0.4n_999ids.csv"

##############################################################################
# 3. Run Storage Selection Algorithm, output the storage selections for tasks.
##############################################################################
storage_config_file="nextflow.config.params.storage.nf"
python ../scripts/py01.select_storage_type_from_spm.sra_search.v1.py \
    -s "${spm_results_file}" \
    -l "${local_dir_config}" \
    -o "${storage_config_file}"


TT_TIME_END=$(date +%s.%N)
TT_TIME_EXE=$(echo "${TT_TIME_END} - ${TT_TIME_START}" | bc -l)
echo
echo "TT_TIME_EXE(s): ${TT_TIME_EXE}"
echo