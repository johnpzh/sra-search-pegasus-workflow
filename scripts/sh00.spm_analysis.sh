set -u

echo "SPM_ANALYSIS_DIR: ${SPM_ANALYSIS_DIR}"
echo "WORKFLOW_NAME: ${WORKFLOW_NAME}"
echo "SPM_INPUT_DATA_DIR: ${SPM_INPUT_DATA_DIR}"
echo "DATALIFE_FILES_DIR: ${DATALIFE_FILES_DIR}"

SPM_RESULTS_FOLD="workflow_spm_results"

PREV_DIR=$(readlink -f .)
if [ ! -d "${SPM_RESULTS_FOLD}" ]; then
    mkdir -p "${SPM_RESULTS_FOLD}"
fi

SPM_ANALYSIS_TIME_START=$(date +%s.%N)

###############
# Prepare data
###############

linked_name="linked_$(date +%FT%T)_t1"


cd "${SPM_INPUT_DATA_DIR}"

set -x
ln -s "${DATALIFE_FILES_DIR}" "${linked_name}"
set +x

cd -

##########
# Run SPM
##########

cd "${SPM_ANALYSIS_DIR}"

set -x
python workflow_data_loader.py --workflow "${WORKFLOW_NAME}"

python workflow_analyzer.py "analysis_data/${WORKFLOW_NAME}_workflow_data.csv"

cp "${SPM_RESULTS_FOLD}/${WORKFLOW_NAME}_filtered_spm_results.csv" "${PREV_DIR}/${SPM_RESULTS_FOLD}/" || true
set +x

echo
echo "Copied SPM results ${SPM_RESULTS_FOLD}/${WORKFLOW_NAME}_filtered_spm_results.csv to folder ${PREV_DIR}/${SPM_RESULTS_FOLD}/"
echo

cd -

################
# Turn off Data
################

cd "${SPM_INPUT_DATA_DIR}"
set -x
mv "${linked_name}" "${linked_name}_turn-off"
rm "${linked_name}_turn-off"
set +x
cd -


SPM_ANALYSIS_TIME_END=$(date +%s.%N)
SPM_ANALYSIS_TIME_EXE=$(echo "${SPM_ANALYSIS_TIME_END} - ${SPM_ANALYSIS_TIME_START}" | bc -l)
echo
echo "SPM_ANALYSIS_TIME_EXE(s): ${SPM_ANALYSIS_TIME_EXE}"
echo