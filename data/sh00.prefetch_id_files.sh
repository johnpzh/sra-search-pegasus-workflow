set -u
SRA_LIST="../tests/1000/sra_ids.txt"
mapfile -t SRA_IDS < <(grep -E '^SRR' "$SRA_LIST" || true)
num_ids=${#SRA_IDS[@]}
echo
echo "num_ids: ${num_ids}"
echo

for sra_id in "${SRA_IDS[@]}"; do
    set -x
    prefetch "$sra_id" --max-size u
    set +x
done

prefetch SRR3403832 --max-size u