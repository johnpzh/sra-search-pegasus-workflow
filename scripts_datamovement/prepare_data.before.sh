set -euo pipefail
####################################################
# Note: file FILE_LIST needs to contain FILES array
####################################################

##############################################
# The below variables are passed from outside
# No need to change.
##############################################
echo
echo "Prepare data before the task"
echo "FILE_LIST: ${FILE_LIST}"
echo "STORAGE_TYPE: ${STORAGE_TYPE}"
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
cd "${TO_PATH}"

if [ ! "${STORAGE_TYPE}" = "nfs" ] && [ ! "${STORAGE_TYPE}" = "beegfs" ]; then
    # Copy the data
    for file_name in "${FILES[@]}"; do
        if [ ! -e "${file_name}" ]; then
            src_path=""
            if [ -e "${FROM_PATH}/${file_name}" ]; then
                src_path="${FROM_PATH}/${file_name}"
            else
                echo "Error: File ${file_name} not found in ${FROM_PATH}."
            fi

            if [ -n "${src_path}" ]; then
                cp -r "${src_path}" "." || echo "Skip copying ${file_name} to ${TO_PATH} due to other processors."
                echo "Copied ${src_path} to ${TO_PATH}"
            else
                echo "Error: Source path for ${file_name} is empty, cannot copy to ${TO_PATH}."
            fi
        else
            echo "File ${file_name} already exists in ${TO_PATH}, skipping copy."
        fi
    done
else
    # Make symlinks
    for file_name in "${FILES[@]}"; do
        if [ ! -e "${file_name}" ]; then
            src_path=""
            if [ -e "${FROM_PATH}/${file_name}" ]; then
                src_path="${FROM_PATH}/${file_name}"
            else
                echo "Error: File ${file_name} not found in ${FROM_PATH}."
            fi

            if [ -n "${src_path}" ]; then
                ln -s "${src_path}" "." || echo "Skip linking ${file_name} to ${TO_PATH} due to other processors."
                echo "Linked ${src_path} to ${TO_PATH}"
            fi
        else
            echo "File ${file_name} already exists in ${TO_PATH}, skipping linking."
        fi
    done
fi
