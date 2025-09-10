set -euo pipefail

# echo
# echo "pwd: $(pwd)"
# echo

tar_folder="results.$(hostname).L${LEVEL}.J${JOB_COUNT}"

echo "#-----------------"
echo "# Script: $0"
echo "# Hostname: $(hostname)"
echo "# LEVEL: ${LEVEL}"
echo "# JOB_COUNT: ${JOB_COUNT}"
echo "#-----------------"

if [ -d "${tar_folder}" ]; then
    echo "${tar_folder} exists at node $(hostname). Removing it."
    rm -rf "${tar_folder}"
else
    echo "${tar_folder} does not exist at node $(hostname). Creating it."
    mkdir -p "${tar_folder}"
fi

# target file is the first one in the arguments
TARGET=$1
shift

# everything else is an input (could be mix of tar and bams)
for FILE in "$@"; do
    if (echo $FILE | grep tar.gz) >/dev/null 2>&1; then
        set -x
        tar -xzf $FILE -C "${tar_folder}"
        set +x
    else
        set -x
        mv $FILE "${tar_folder}/"
        set +x
    fi
done

set -x
tar -czf $TARGET "${tar_folder}"
set +x


