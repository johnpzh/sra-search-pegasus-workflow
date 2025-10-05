
if [ $# -eq 1 ]; then
    output=$1
else
    output="nextflow.config.params.storage.nf"
fi

if [ ! -v SLURM_JOB_ID ]; then
    SLURM_JOB_ID="111"
fi

if [ ! -v SLURM_JOB_NAME ]; then
    SLURM_JOB_NAME="test"
fi

:> $output

echo "params {" >> $output
echo "    bowtie2_build_index_Storage_Type = 'nfs'" >> $output
echo "    process_sra_ids_Storage_Type = 'nfs'" >> $output
echo "    merge_Storage_Type = 'nfs'" >> $output
echo "    bowtie2_build_index_Actual_Path = '/people/peng599/Projects/Datamesh/qfs/Workflows/sra-search-pegasus-workflow/local_stuff/output.workspace.${SLURM_JOB_NAME}.${SLURM_JOB_ID}.$(date +%FT%T)'" >> $output
echo "    process_sra_ids_Actual_Path = '/people/peng599/Projects/Datamesh/qfs/Workflows/sra-search-pegasus-workflow/local_stuff/output.workspace.${SLURM_JOB_NAME}.${SLURM_JOB_ID}.$(date +%FT%T)'" >> $output
echo "    merge_Actual_Path = '/people/peng599/Projects/Datamesh/qfs/Workflows/sra-search-pegasus-workflow/local_stuff/output.workspace.${SLURM_JOB_NAME}.${SLURM_JOB_ID}.$(date +%FT%T)'" >> $output
echo "}" >> $output