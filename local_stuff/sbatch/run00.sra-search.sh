
folder="output.workspace.$(date +%FT%T)"
script="../../scripts/sh00.sra-search.sh"
#id_list_file="../../tests/1/sra_ids.txt"
#reference_file="../../tests/1/crassphage.fna"
id_list_file="../../tests/10/sra_ids.txt"
reference_file="../../tests/10/crassphage.fna"

output="output.sra-search-test.$(date +%FT%T).log"

TT_TIME_START=$(date +%s.%N)

set -x
mkdir "${folder}"
cd "${folder}"
bash "${script}" "${id_list_file}" "${reference_file}" 2>&1 | tee "${output}"
set +x


TT_TIME_END=$(date +%s.%N)
TT_TIME_EXE=$(echo "${TT_TIME_END} - ${TT_TIME_START}" | bc -l)
echo | tee -a "${output}"
echo "TT_TIME_EXE(s): ${TT_TIME_EXE}" | tee -a "${output}"
echo | tee -a "${output}"
