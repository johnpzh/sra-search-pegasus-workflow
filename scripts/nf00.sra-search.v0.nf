

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
params.reference_file_dir = ""
params.datalife_lib_path = ""  /// TODO: use DataLife library
params.python_path = ""

/*
 * Pipeline parameters static
 */

params.datamovement_scripts_dir = ""

/*
 * Parameters for 1KGenome global settings
 */
params.nfs_origin_data_dir = ""
// params.nfs_shared_tmp_dir = ""
// params.WORKSPACE_FOLDER="output.workspace"


/*
 * Parameters for 1KGenome tasks' storage locations
 */
params.bowtie2_build_Storage_Type = "nfs"
params.fasterq_dump_Storage_Type = "nfs"
params.bowtie2_samtools_Storage_Type = "nfs"
params.samtools_Storage_Type = "nfs"
params.tar_compress_Storage_Type = "nfs"

params.bowtie2_build_Actual_Path = ""
params.fasterq_dump_Actual_Path = ""
params.bowtie2_samtools_Actual_Path = ""
params.samtools_Actual_Path = ""
params.tar_compress_Actual_Path = ""

params.bowtie2_build_Copy_To_Path = ""
params.fasterq_dump_Copy_To_Path = ""
params.bowtie2_samtools_Copy_To_Path = ""
params.samtools_Copy_To_Path = ""
params.tar_compress_Copy_To_Path = ""

// params.bowtie2_build_Copy_To_Path = ""
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
    echo "bowtie2_build_Storage_Type: ${params.bowtie2_build_Storage_Type}"
    echo "bowtie2_build_Actual_Path: ${params.bowtie2_build_Actual_Path}"
    echo "fasterq_dump_Storage_Type: ${params.fasterq_dump_Storage_Type}"
    echo "fasterq_dump_Actual_Path: ${params.fasterq_dump_Actual_Path}"
    echo "bowtie2_samtools_Storage_Type: ${params.bowtie2_samtools_Storage_Type}"
    echo "bowtie2_samtools_Actual_Path: ${params.bowtie2_samtools_Actual_Path}"
    echo "samtools_Storage_Type: ${params.samtools_Storage_Type}"
    echo "samtools_Actual_Path: ${params.samtools_Actual_Path}"
    echo "tar_compress_Storage_Type: ${params.tar_compress_Storage_Type}"
    echo "tar_compress_Actual_Path: ${params.tar_compress_Actual_Path}"
    """
    // result = "world"  /* Will not work, because the last command in script should be a string. */

}

//-------------------
// Workflow Process
//-------------------

process bowtie2_build {
    input:
    // val workflow_id
    val prev_task_successful

    output:
    val true, emit: is_successful

    script:
    script_path = "${params.script_dir}/task.bowtie2_build.sh"
    storage_type = "${params.bowtie2_build_Storage_Type}"
    storage_path = "${params.bowtie2_build_Actual_Path}"
    copy_to_path = "${params.fasterq_dump_Actual_Path}"
    file_list_input = "${params.datamovement_scripts_dir}/file_list.bowtie2_build.input.sh"
    file_list_output = "${params.datamovement_scripts_dir}/file_list.bowtie2_build.output.sh"
    prepare_data_before_script = "${params.datamovement_scripts_dir}/prepare_data.before.sh"
    prepare_data_after_script = "${params.datamovement_scripts_dir}/prepare_data.after.sh"
    prepare_data_scp_script = "${params.datamovement_scripts_dir}/prepare_data.scp.sh"


    """
    IFS=',' read -ra NODE_LIST <<< "${params.node_list}"
    export NODE_LIST

    ###################################
    # Prepare the data before the task
    ###################################

    export FILE_LIST="${file_list_input}"
    export STORAGE_TYPE="${storage_type}"
    export FROM_PATH="${params.reference_file_dir}"
    export TO_PATH="${storage_path}"

    # test
    set -x
    echo "#### PWD ####"
    echo \$(pwd)
    set +x
    # end test

    #
    # bowtie2_build needs to be done once by one node
    #
    set -x
    srun -w "\${NODE_LIST[0]}" -n1 -N1 --exclusive bash "${prepare_data_before_script}" &
    # bash "${prepare_data_before_script}" &
    set +x
    wait

    # if [ ! -d "${storage_path}" ]; then
    #     mkdir -p "${storage_path}"
    # fi

    #################
    # Run the task
    #################
    cd "${storage_path}"
    echo ""
    echo "#-------------------------------#"
    echo "# Task : bowtie2_build"
    echo "# current_pwd: \$(pwd)"
    echo "#-------------------------------#"
    echo ""

    export REFERENCE="${params.reference_file}"
    export DATALIFE_LIB_PATH="${params.datalife_lib_path}"
    BOWTIE2_BUILD_TIME_START=\$(date +%s.%N)
    set -x
    srun -w "\${NODE_LIST[0]}" -n1 -N1 --exclusive bash "${script_path}" &
    # bash "${script_path}" &
    set +x
    wait
    BOWTIE2_BUILD_TIME_END=\$(date +%s.%N)
    BOWTIE2_BUILD_TIME_EXE=\$(echo "\${BOWTIE2_BUILD_TIME_END} - \${BOWTIE2_BUILD_TIME_START}" | bc -l)
    echo
    echo "BOWTIE2_BUILD_TIME_EXE(s): \${BOWTIE2_BUILD_TIME_EXE}"
    echo

    ########################
    # Move the output files
    ########################
    #
    # If fasterq_dump's storage type is local, NODE_LIST[0] needs to broadcast the reference files to other nodes.
    #

    export FILE_LIST="${file_list_output}"
    export STORAGE_TYPE="${storage_type}"

    if [ "${params.fasterq_dump_Storage_Type}" = "nfs" ] || \
       [ "${params.fasterq_dump_Storage_Type}" = "beegfs" ]; then
        # If fasterq_dump's storage type is shared

        export FROM_PATH="${storage_path}"
        export TO_PATH="${copy_to_path}"
        set -x
        srun -w "\${NODE_LIST[0]}" -n1 -N1 --exclusive bash "${prepare_data_after_script}" &
        # bash "${prepare_data_after_script}" &
        set +x
        wait
    else
        # If fasterq_dump's storage type is local, broadcast the reference files to other nodes

        export FROM_PATH="${storage_path}"
        export TO_PATH="${copy_to_path}"
        for ((node_idx = 1; node_idx < ${params.num_nodes}; node_idx++)); do
            export DEST_NODE="\${NODE_LIST[\$node_idx]}"
            set -x
            srun -w "\${NODE_LIST[0]}" -n1 -N1 --exclusive bash "${prepare_data_scp_script}" &
            # bash "${prepare_data_scp_script}" &
            set +x
        done
        wait
    fi
    """
}

process process_sra_ids {
    input:
    // val workflow_id
    val prev_task_successful

    output:
    val true, emit: is_successful

    script:
    script_path = "${params.script_dir}/task.process_sra_ids.sh"
    storage_type = "${params.fasterq_dump_Storage_Type}"
    storage_path = "${params.fasterq_dump_Actual_Path}"
    copy_to_path = "${params.tar_compress_Actual_Path}"
    file_list_input = "${params.datamovement_scripts_dir}/file_list.fasterq_dump.input.sh"
    file_list_output = "${params.datamovement_scripts_dir}/file_list.process_sra_ids.output.sh"
    prepare_data_before_script = "${params.datamovement_scripts_dir}/prepare_data.before.sh"
    prepare_data_after_script = "${params.datamovement_scripts_dir}/prepare_data.after.sh"


    """
    IFS=',' read -ra NODE_LIST <<< "${params.node_list}"
    export NODE_LIST
    NUM_NODES=${params.num_nodes}
    export NEXTFLOW_ON="on"

    ###################################
    # Prepare the data before the task
    ###################################

    export FILE_LIST="${file_list_input}"
    export STORAGE_TYPE="${storage_type}"
    export FROM_PATH="${params.nfs_origin_data_dir}"
    export TO_PATH="${storage_path}"

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

    for ((id = 0; id < num_ids; id++)); do
        export SRA_ID="\${SRA_IDS[\$id]}"
        node_idx=\$((id % NUM_NODES))
        running_node="\${NODE_LIST[\$node_idx]}"
        set -x
        srun -w "\${running_node}" -n1 -N1 --exclusive bash "${prepare_data_before_script}" &
        # bash "${prepare_data_before_script}" &
        set +x
    done
    wait

    # if [ ! -d "${storage_path}" ]; then
    #     mkdir -p "${storage_path}"
    # fi

    #################
    # Run the task
    #################

    cd "${storage_path}"
    echo ""
    echo "#-----------------------#"
    echo "# Task : process_sra_ids"
    echo "# current_pwd: \$(pwd)"
    echo "#-----------------------#"
    echo ""

    export DATALIFE_LIB_PATH="${params.datalife_lib_path}"
    PROCESS_SRA_TIME_START=\$(date +%s.%N)
    batch_size=\$((NUM_NODES * 8))  # Use batch limit to avoid fasterq-dump to crash
    for ((id = 0; id < num_ids; id++)); do
        export SRA_ID="\${SRA_IDS[\$id]}"
        node_idx=\$((id % NUM_NODES))
        running_node="\${NODE_LIST[\$node_idx]}"
        set -x
        srun -w "\${running_node}" -n1 -N1 --exclusive bash "${script_path}" &
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
        echo "Current open files number: \$(lsof -p \$\$ | wc -l)"
        echo
        # end test
    done
    wait

    PROCESS_SRA_TIME_END=\$(date +%s.%N)
    PROCESS_SRA_TIME_EXE=\$(echo "\${PROCESS_SRA_TIME_END} - \${PROCESS_SRA_TIME_START}" | bc -l)
    echo
    echo "PROCESS_SRA_TIME_EXE(s): \${PROCESS_SRA_TIME_EXE}"
    echo

    ########################
    # Move the output files
    ########################
    #
    # Assume tar_compress's storage type is nfs or beegfs, because
    # 1. `*.bam` and `*.bam.bai` files are generated on multiple nodes. Merging them needs to access all files.
    # 2. Merging phase time is short compared to the whole workflow time.
    #
    export FILE_LIST="${file_list_output}"
    export STORAGE_TYPE="${storage_type}"
    export FROM_PATH="${storage_path}"
    export TO_PATH="${copy_to_path}"

    for ((id = 0; id < num_ids; id++)); do
        export SRA_ID="\${SRA_IDS[\$id]}"
        node_idx=\$((id % NUM_NODES))
        running_node="\${NODE_LIST[\$node_idx]}"
        set -x
        srun -w "\${running_node}" -n1 -N1 --exclusive bash "${prepare_data_after_script}" &
        # bash "${prepare_data_after_script}" &
        set +x
    done
    wait
    """
}


process merge_files {
    input:
    // val workflow_id
    val prev_task_successful

    output:
    val true, emit: is_successful

    script:
    script_path = "${params.script_dir}/task.merge.sh"
    storage_type = "${params.tar_compress_Storage_Type}"
    storage_path = "${params.tar_compress_Actual_Path}"
    copy_to_path = "${params.tar_compress_Copy_To_Path}"
    file_list_input = "${params.datamovement_scripts_dir}/file_list.tar_compress.input.sh"
    file_list_output = "${params.datamovement_scripts_dir}/file_list.tar_compress.output.sh"
    prepare_data_before_script = "${params.datamovement_scripts_dir}/prepare_data.before.sh"
    prepare_data_after_script = "${params.datamovement_scripts_dir}/prepare_data.after.sh"


    """
    IFS=',' read -ra NODE_LIST <<< "${params.node_list}"
    export NODE_LIST
    NUM_NODES=${params.num_nodes}

    ###################################
    # Prepare the data before the task
    ###################################
    #
    # Assume tar_compress's storage type is nfs or beegfs, and no initial inputs, so no need to prepare data.
    #

    # if [ ! -d "${storage_path}" ]; then
    #     mkdir -p "${storage_path}"
    # fi

    #################
    # Run the task
    #################
    cd "${storage_path}"
    echo ""
    echo "#-----------------------#"
    echo "# Task : merge"
    echo "# current_pwd: \$(pwd)"
    echo "#-----------------------#"
    echo ""

    export DATALIFE_LIB_PATH="${params.datalife_lib_path}"
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
            srun -w "\${running_node}" -n1 -N1 --exclusive bash "${script_path}" "\$out_file" "\${chunk[@]}" &
            # bash "${script_path}" "\$out_file" "\${chunk[@]}" &
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

    ########################
    # Move the output files
    ########################
    #
    # tar_compress is the last task, so no need to move the output files.
    #
    """
}

process cleanup {
    input:
    val start1

    output:
    val true, emit: is_successful

    script:
    """
    export BOWTIE2_BUILD_STORAGE_PATH="${params.bowtie2_build_Actual_Path}"
    export FASTERQ_DUMP_STORAGE_PATH="${params.fasterq_dump_Actual_Path}"
    export BOWTIE2_SAMTOOLS_STORAGE_PATH="${params.bowtie2_samtools_Actual_Path}"
    export SAMTOOLS_STORAGE_PATH="${params.samtools_Actual_Path}"
    export TAR_COMPRESS_STORAGE_PATH="${params.tar_compress_Actual_Path}"
    IFS=',' read -ra NODE_LIST <<< "${params.node_list}"
    script="${params.datamovement_scripts_dir}/cleanup_data.sh"

    #################################
    # Clean up the data on each node
    #################################
    bound=\$((${params.num_nodes} - 1))
    for node_idx in \$(seq 0 \${bound}); do
        running_node="\${NODE_LIST[\$node_idx]}"

        set -x
        srun -w "\$running_node" -n1 -N1 --exclusive bash "\${script}" &
        # bash "\${script}" &
        set +x
    done
    wait

    """
}


workflow {
    /* Sanity Test */
    sanity_test()

    /* Fake 1KGenome Workflow */
    bowtie2_build(sanity_test.out.is_successful)
    process_sra_ids(bowtie2_build.out.is_successful)
    merge_files(process_sra_ids.out.is_successful)

    cleanup(merge_files.out.is_successful)

}