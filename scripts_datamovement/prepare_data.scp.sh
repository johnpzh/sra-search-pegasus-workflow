# set -euo pipefail
set -u

####################################################
# Note: file FILE_LIST needs to contain FILES array
####################################################

##############################################
# The below variables are passed from outside
# No need to change.
##############################################
echo
echo "Copy file through ssh (scp)"
echo "FILE_LIST: ${FILE_LIST}"
# echo "STORAGE_TYPE: ${STORAGE_TYPE}"
echo "FROM_PATH: ${FROM_PATH}"
echo "TO_PATH: ${TO_PATH}"
echo "DEST_NODE: ${DEST_NODE}"
echo "Hostname: $(hostname)"
ssh_options="-o StrictHostKeyChecking=no" # Ref: https://askubuntu.com/questions/87449/how-to-disable-strict-host-key-checking-in-ssh

# Import FILES array
source "${FILE_LIST}"

# Create the storage folder
if ssh "${ssh_options}" ${DEST_NODE} test ! -d "${TO_PATH}"; then
    set -x
    ssh "${ssh_options}" "${DEST_NODE}" "mkdir -p ${TO_PATH}"
    set +x
    echo "Created path ${TO_PATH} on node ${DEST_NODE}."
else
    echo "Node ${DEST_NODE} already has path ${TO_PATH}, skip mkdir."
fi

# Copy the data
cd "${FROM_PATH}"

for file_name in "${FILES[@]}"; do
    dst_path="${TO_PATH}/${file_name}"
    if [ -e "${file_name}" ]; then
        if ssh "${ssh_options}" ${DEST_NODE} test -e "${dst_path}"; then
            echo "File ${file_name} already exists on node ${DEST_NODE} under ${TO_PATH}, skipping copy."
        else
            set -x
            scp "${ssh_options}" -r "${file_name}" ${DEST_NODE}:"${TO_PATH}"
            set +x
            echo "Copied ${file_name} to node ${DEST_NODE}:${TO_PATH}"
        fi
    else
        echo "Error: File ${file_name} does not exist in ${FROM_PATH}, cannot copy to ${TO_PATH}."
    fi
done
