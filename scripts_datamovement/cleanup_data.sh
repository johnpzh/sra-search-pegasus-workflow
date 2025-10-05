set -euo pipefail

echo
echo "Hostname: $(hostname)"
echo "Clean up data"
for dir in "${BOWTIE2_BUILD_STORAGE_PATH}" \
           "${FASTERQ_DUMP_STORAGE_PATH}" \
           "${BOWTIE2_SAMTOOLS_STORAGE_PATH}" \
           "${SAMTOOLS_STORAGE_PATH}" \
           "${TAR_COMPRESS_STORAGE_PATH}"; do
    if [ -d "${dir}" ]; then
        rm -rf "${dir}"
        echo "Removed directory: ${dir}"
    else
        echo "Directory ${dir} does not exist, skipping."
    fi
done
