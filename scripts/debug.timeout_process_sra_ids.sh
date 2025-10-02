
set -u

timeout 1800 bash "${SCRIPT_DIR}/task.process_sra_ids.sh"
exit_status=$?
if [ $exit_status -eq 124 ]; then
    echo "ID ${SRA_ID} got TIMEOUT with exit code $exit_status."
elif [ $exit_status -eq 0 ]; then
    echo "ID ${SRA_ID} completed successfully with exit code $exit_status."
else
    echo "ID ${SRA_ID} failed with exit code $exit_status."
fi