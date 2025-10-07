set -euo pipefail
####################################################
# Note: file FILE_LIST needs to contain FILES array
####################################################

##############################################
# The below variables are passed from outside
# No need to change.
##############################################
echo
echo "Copy data after the task"
echo "FILE_LIST: ${FILE_LIST}"
# echo "STORAGE_PATH: ${STORAGE_PATH}"
# echo "NFS_SHARED_TMP_DIR: ${NFS_SHARED_TMP_DIR}"
# echo "ORIGIN_DATA_DIR: ${ORIGIN_DATA_DIR}"
echo "FROM_PATH: ${FROM_PATH}"
echo "TO_PATH: ${TO_PATH}"
echo "Hostname: $(hostname)"

# Import FILES array
source "${FILE_LIST}"

# Create the storage folder
if [ ! -d "${TO_PATH}" ]; then
    mkdir -p "${TO_PATH}"
fi

# Copy the data
if [ ! -d "${FROM_PATH}" ]; then
    echo "Error: Source path ${FROM_PATH} does not exist."
    exit 1
fi

cd "${FROM_PATH}"

for file_name in "${FILES[@]}"; do
    dst_path="${TO_PATH}/${file_name}"
    if [ -e "${file_name}" ]; then
        if [ -e "${dst_path}" ]; then
            echo "File ${file_name} already exists in ${TO_PATH}, skipping copy."
        else
            cp -r "${file_name}" "${TO_PATH}/" || echo "Skip copying ${file_name} to ${TO_PATH} due to other processors."
            echo "Copied ${file_name} to ${TO_PATH}"
        fi
    else
        echo "Error: File ${file_name} does not exist in ${FROM_PATH}, cannot copy to ${TO_PATH}."
    fi
done
