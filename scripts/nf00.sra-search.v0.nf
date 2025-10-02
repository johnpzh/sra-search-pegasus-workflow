

// -------------------
// Parameter settings
// -------------------
/*
 * Pipeline parameters got from command line
 */
params.id_list_file = ""
params.reference_file = ""
params.workflow_id = 0
params.num_nodes = 1  /// TODO: use SLURM_JOB_NUM_NODES
params.node_list = [] /// --node_list node1,node2,node3
params.script_dir = ""
params.datalife_lib_path = ""  /// TODO: use DataLife library
params.python_path = ""

/*
 * Pipeline parameters static
 */

params.datamovement_script_dir = ""

/*
 * Parameters for 1KGenome global settings
 */
// params.nfs_origin_1kgenome_dir = ""
// params.nfs_shared_tmp_dir = ""
// params.WORKSPACE_FOLDER="output.workspace"


/*
 * Parameters for 1KGenome tasks' storage locations
 */
params.bowtie2_build_index_Storage_Type = "nfs"
params.process_sra_ids_Storage_Type = "nfs"
params.siftingmerge_Storage_Type_Storage_Type = "nfs"

params.bowtie2_build_index_Actual_Path = ""
params.process_sra_ids_Actual_Path = ""
params.merge_Actual_Path = ""

// params.bowtie2_build_index_Copy_To_Path = ""
// params.process_sra_ids_Copy_To_Path = ""
// params.merge_Copy_To_Path = ""

//-------------------
// Utility Process
//-------------------

process sanity_test {
    publishDir "results", mode: "copy"

    // printf("projectDir: %s\n", projectDir)
    // printf("launchDir: %s\n", launchDir)
    output:
    val true, emit: is_successful

    script:
    result = "hello"
    """
    echo "#-----------------------#"
    echo "# Task : sanity_test.py #"
    echo "#-----------------------#"
    echo "num_nodes: ${params.num_nodes}"
    echo "node_list: ${params.node_list}"
    echo "projectDir: ${projectDir}"
    echo "launchDir: ${launchDir}"
    echo "script_dir: ${params.script_dir}"
    echo "id_list_file: ${params.id_list_file}"
    echo "reference_file: ${params.reference_file}"
    echo "bowtie2_build_index_Storage_Type: ${params.bowtie2_build_index_Storage_Type}"
    echo "bowtie2_build_index_Actual_Path: ${params.bowtie2_build_index_Actual_Path}"
    echo "process_sra_ids_Storage_Type: ${params.process_sra_ids_Storage_Type}"
    echo "process_sra_ids_Actual_Path: ${params.process_sra_ids_Actual_Path}"
    echo "merge_Storage_Type: ${params.merge_Storage_Type}"
    echo "merge_Actual_Path: ${params.merge_Actual_Path}"
    """
    // result = "world"  /* Will not work, because the last command in script should be a string. */

}

//-------------------
// Workflow Process
//-------------------

process bowtie2_build_index {
    input:
    val workflow_id
    val prev_task_successful

    output:
    val true, emit: is_successful

    script:
    storage_type = "${params.bowtie2_build_index_Storage_Type}"
    storage_path = "${params.bowtie2_build_index_Actual_Path}"
    script_path = "${params.script_dir}/task.bowtie2_build_index.sh"

    """
    IFS=',' read -ra NODE_LIST <<< "${params.node_list}"
    export NODE_LIST

    if [ ! -d "${storage_path}" ]; then
        mkdir -p "${storage_path}"
    fi
    cd "${storage_path}"
    echo ""
    echo "#-------------------------------#"
    echo "# Task : bowtie2_build_index"
    echo "# current_pwd: \$(pwd)"
    echo "#-------------------------------#"
    echo ""

    export REFERENCE="${params.reference_file}"
    BOWTIE2_BUILD_INDEX_TIME_START=\$(date +%s.%N)
    set -x
    LD_PRELOAD="${params.datalife_lib_path}" DATALIFE_TASK_NAME="bowtie2_build_index" \
        srun -n1 -N1 --exclusive \
            bash "${script_path}" &
    #bash "${script_path}" &
    set +x
    wait
    BOWTIE2_BUILD_INDEX_TIME_END=\$(date +%s.%N)
    BOWTIE2_BUILD_INDEX_TIME_EXE=\$(echo "\${BOWTIE2_BUILD_INDEX_TIME_END} - \${BOWTIE2_BUILD_INDEX_TIME_START}" | bc -l)
    echo
    echo "BOWTIE2_BUILD_INDEX_TIME_EXE(s): \${BOWTIE2_BUILD_INDEX_TIME_EXE}"
    echo
    """
}

process process_sra_ids {
    input:
    val workflow_id
    val prev_task_successful

    output:
    val true, emit: is_successful

    script:
    storage_type = "${params.process_sra_ids_Storage_Type}"
    storage_path = "${params.process_sra_ids_Actual_Path}"
    script_path = "${params.script_dir}/task.process_sra_ids.sh"

    """
    IFS=',' read -ra NODE_LIST <<< "${params.node_list}"
    export NODE_LIST
    NUM_NODES=${params.num_nodes}

    if [ ! -d "${storage_path}" ]; then
        mkdir -p "${storage_path}"
    fi
    cd "${storage_path}"
    echo ""
    echo "#-----------------------#"
    echo "# Task : process_sra_ids"
    echo "# current_pwd: \$(pwd)"
    echo "#-----------------------#"
    echo ""

    # Read SRA IDs, skipping short/empty lines
    set -x
    mapfile -t SRA_IDS < <(grep '^SRR' "${params.id_list_file}" || true)
    set +x

    if [ \${#SRA_IDS[@]} -eq 0 ]; then
        echo "No valid SRA IDs found in ${params.id_list_file}"
        exit 1
    fi


    # Run in parallel
    num_ids=\${#SRA_IDS[@]}
    echo
    echo "num_ids: \${num_ids}"
    echo
    PROCESS_SRA_TIME_START=\$(date +%s.%N)
    batch_size=\$((NUM_NODES * 8))
    for ((id = 0; id < num_ids; id++)); do
        export SRA_ID="\${SRA_IDS[\$id]}"
        node_idx=\$((id % NUM_NODES))
        running_node="\${NODE_LIST[\$node_idx]}"
        set -x
        LD_PRELOAD="${params.datalife_lib_path}" DATALIFE_TASK_NAME="process_sra_ids" \
            srun -w "\${running_node}" -n1 -N1 --exclusive \
                bash "${script_path}" &
        # bash "${script_path}" &
        set +x

        # test
        while [ \$(jobs -r | wc -l) -ge \${batch_size} ]; do
            echo "Waiting for \${batch_size} jobs to finish..."
            sleep 1
        done

        echo
        echo "Current job count: \$((id + 1))"
        echo "Current running jobs number: \$(jobs -r | wc -l) / \${batch_size}"
        echo "Current open files number: \$(lsof -p $$ | wc -l)"
        echo
        # end test
    done
    wait

    PROCESS_SRA_TIME_END=\$(date +%s.%N)
    PROCESS_SRA_TIME_EXE=\$(echo "\${PROCESS_SRA_TIME_END} - \${PROCESS_SRA_TIME_START}" | bc -l)
    echo
    echo "PROCESS_SRA_TIME_EXE(s): \${PROCESS_SRA_TIME_EXE}"
    echo
    """
}

process merge_files {
    input:
    val workflow_id
    val prev_task_successful

    output:
    val true, emit: is_successful

    script:
    storage_type = "${params.merge_Storage_Type}"
    storage_path = "${params.merge_Actual_Path}"
    script_path = "${params.script_dir}/task.merge.sh"

    """
    IFS=',' read -ra NODE_LIST <<< "${params.node_list}"
    export NODE_LIST
    NUM_NODES=${params.num_nodes}

    if [ ! -d "${storage_path}" ]; then
        mkdir -p "${storage_path}"
    fi
    cd "${storage_path}"
    echo ""
    echo "#-----------------------#"
    echo "# Task : merge"
    echo "# current_pwd: \$(pwd)"
    echo "#-----------------------#"
    echo ""

    MERGE_TIME_START=\$(date +%s.%N)

    BAM_FILES=(*.bam *.bam.bai)
    parents=("\${BAM_FILES[@]}")
    max_parents=50
    level=1

    while [ \${#parents[@]} -gt 1 ]; do
        children=()
        job_count=0

        echo "#--------------------------------------------"
        echo "# Level: \$level with \${#parents[@]} parents"
        echo "# Parents: \${parents[@]}"
        echo "#--------------------------------------------"

        for ((i=0; i<\${#parents[@]}; i+=max_parents)); do
            chunk=("\${parents[@]:i:max_parents}")
            job_count=\$((job_count + 1))

            out_file="results-l\${level}-j\${job_count}.tar.gz"
            if [ \${#parents[@]} -le \$max_parents ]; then
                out_file="results.tar.gz"
            fi

            echo "#--------------------------------------------"
            echo "# Merging chunk \${chunk[@]} into \$out_file..."
            echo "#--------------------------------------------"
            export LEVEL="\${level}"
            export JOB_COUNT="\${job_count}"
            node_idx=\$((job_count % NUM_NODES))
            running_node="\${NODE_LIST[\$node_idx]}"
            set -x
            LD_PRELOAD="${params.datalife_lib_path}" DATALIFE_TASK_NAME="merge_files"
                srun -w "\${running_node}" -n1 -N1 --exclusive \
                    bash "${script_path}" "\$out_file" "\${chunk[@]}" &
            #bash "${script_path}" "\$out_file" "\${chunk[@]}" &
            set +x
            children+=("\$out_file")
        done
        wait

        level=\$((level + 1))
        parents=("\${children[@]}")
    done

    MERGE_TIME_END=\$(date +%s.%N)
    MERGE_TIME_EXE=\$(echo "\${MERGE_TIME_END} - \${MERGE_TIME_START}" | bc -l)
    echo
    echo "MERGE_TIME_EXE(s): \${MERGE_TIME_EXE}"
    echo
    """
}

workflow {
    /* Sanity Test */
    sanity_test()

    /* Fake 1KGenome Workflow */
    bowtie2_build_index(params.workflow_id, sanity_test.out.is_successful)
    process_sra_ids(params.workflow_id, bowtie2_build_index.out.is_successful)
    merge_files(params.workflow_id, process_sra_ids.out.is_successful)

    // cleanup(mutation_overlap.out.is_successful, frequency.out.is_successful)

}