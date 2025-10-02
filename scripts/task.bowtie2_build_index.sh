set -euo pipefail
# set -u

LD_PRELOAD="${DATALIFE_LIB_PATH}" DATALIFE_TASK_NAME="bowtie2-build" \
    bowtie2-build "$REFERENCE" reference