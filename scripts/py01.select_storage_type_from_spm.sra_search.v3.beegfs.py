import argparse
import sys
import os
import json
import pprint
import datetime
from typing import Dict, List, Tuple, Any
import networkx as nx
import pandas as pd


#-----------------
# Special version for SRA Search
#-----------------

def remove_invalid_data(spm_results: pd.DataFrame):
    valid_rows = []

    for _, row in spm_results.iterrows():
        producer_storage_type = row["producerStorageType"]
        consumer_storage_type = row["consumerStorageType"]
        # # test
        # print(f"row: {row}")
        # print(f"producer_storage_type: {producer_storage_type} consumer_storage_type: {consumer_storage_type}")
        # # end test
        if '-' in producer_storage_type:
            # compound type : single type
            src, dst = producer_storage_type.split('-')
            if dst == consumer_storage_type:
                valid_rows.append(row)
        elif '-' in consumer_storage_type:
            # single type : compound type
            src, dst = consumer_storage_type.split('-')
            if producer_storage_type == src:
                valid_rows.append(row)
        else:
            # single type : single type
            if producer_storage_type == consumer_storage_type:
                valid_rows.append(row)

    valid_df = pd.DataFrame(valid_rows)
    valid_df.reset_index(drop=True, inplace=True)

    return valid_df


# def create_core_dag(spm_results: pd.DataFrame) -> nx.DiGraph:

#     # Remove "stage_in-TASK" or "stage_out-TASK"
#     filtered_results = \
#         spm_results[~(spm_results['producer'].str.startswith('stage_in-') |
#                       spm_results['consumer'].str.startswith('stage_out-'))]

#     # Extract unique pairs
#     unique_results = filtered_results[['producer', 'consumer']].drop_duplicates()

#     # # test
#     # print(unique_results)
#     # # end test

#     # Create the core DAG
#     core_dag = nx.DiGraph()
#     for producer, consumer in unique_results.to_numpy():
#         core_dag.add_edge(producer, consumer)

#     # test
#     print(f"core_dag: num_nodes: {core_dag.number_of_nodes()} num_edges: {core_dag.number_of_edges()}")
#     for src, dst in core_dag.edges():
#         print(f"{src}->{dst}")
#     # end test

#     return core_dag

def create_core_dag_of_sra_search() -> nx.DiGraph:
    """
    TODO: the current SPM results for SRA Search is not complete, so creating the core DAG from the results is not feasible.
    Here we manually create the core DAG for SRA Search workflow.
    """
    core_dag = nx.DiGraph()
    core_dag.add_edge("bowtie2-build", "bowtie2-samtools")
    core_dag.add_edge("fasterq-dump", "bowtie2-samtools")
    core_dag.add_edge("bowtie2-samtools", "samtools")
    core_dag.add_edge("bowtie2-samtools", "tar-compress")
    core_dag.add_edge("samtools", "tar-compress")

    # test
    print(f"core_dag: num_nodes: {core_dag.number_of_nodes()} num_edges: {core_dag.number_of_edges()}")
    for src, dst in core_dag.edges():
        print(f"{src}->{dst}")
    # end test

    return core_dag


def do_algorithm_baseline_0(core_dag: nx.DiGraph,
                            spm_results: pd.DataFrame) -> dict:

    # Topological traverse
    storage_type_selections = {}
    for node in nx.topological_sort(core_dag):
        producer = node
        for consumer in core_dag.successors(producer):
            filtered_results = spm_results[(spm_results['producer'] == producer) & (spm_results['consumer'] == consumer)]
            idx_for_min_spm = filtered_results['SPM'].idxmin()
            min_spm_row = filtered_results.loc[idx_for_min_spm]
            producer_storage_type = min_spm_row['producerStorageType']
            consumer_storage_type = min_spm_row['consumerStorageType']
            spm_value = min_spm_row['SPM']

            if producer not in storage_type_selections:
                storage_type_selections[producer] = {'storage_type': producer_storage_type, 'SPM': spm_value}
            elif spm_value < storage_type_selections[producer]['SPM']:
                storage_type_selections[producer] = {'storage_type': producer_storage_type, 'SPM': spm_value}

            if consumer not in storage_type_selections:
                storage_type_selections[consumer] = {'storage_type': consumer_storage_type, 'SPM': spm_value}
            elif spm_value < storage_type_selections[consumer]['SPM']:
                storage_type_selections[consumer] = {'storage_type': consumer_storage_type, 'SPM': spm_value}

    # test
    print("storage_type_selections:")
    pprint.pprint(storage_type_selections)
    # end test
    return storage_type_selections


def do_algorithm_baseline_1(core_dag: nx.DiGraph,
                            spm_results: pd.DataFrame) -> dict:

    # Get sources
    source_nodes = [node for node in core_dag.nodes() if core_dag.in_degree(node) == 0]
    # test
    print(f"source_nodes: {source_nodes}")
    # end test

    # Topological traverse
    storage_type_selections = {}
    for node in nx.topological_sort(core_dag):
        producer = node
        for consumer in core_dag.successors(producer):
            # test
            print(f"Processing edge: {producer} -> {consumer}")
            # end test
            if producer in source_nodes:
                # Process the source node and its successors
                # Find producer-consumer's rank 1 in spm results
                filtered_results = spm_results[(spm_results['producer'] == producer) & (spm_results['consumer'] == consumer)]
                if not filtered_results.empty:
                    idx_for_min_spm = filtered_results['SPM'].idxmin()
                    # # test
                    # print(f"producer: {producer} consumer: {consumer} idxmin: {idx_for_min_spm}")
                    # print(f"{filtered_results.loc[idx_for_min_spm]}")
                    # # end test
                    min_spm_row = filtered_results.loc[idx_for_min_spm]
                    producer_storage_type = min_spm_row['producerStorageType']
                    consumer_storage_type = min_spm_row['consumerStorageType']
                    spm_value = min_spm_row['SPM']
                    storage_type_selections[producer] = {'storage_type': producer_storage_type, 'SPM': spm_value}
                    storage_type_selections[consumer] = {'storage_type': consumer_storage_type, 'SPM': spm_value}
                else:
                    storage_type = "tmpfs"
                    spm_value = 999
                    storage_type_selections[producer] = {'storage_type': storage_type, 'SPM': spm_value}
                    storage_type_selections[consumer] = {'storage_type': storage_type, 'SPM': spm_value}
            else:
                # The producer's storage type is known. Now find the best consumer's storage type.
                # Find the suitable storage type for consumer
                # consumerStorageType: {producer_type}-XXX
                producer_storage_type = storage_type_selections[producer]['storage_type']

                # Get all transition cost options
                transition_cost_table = spm_results[(spm_results['producer'] == f"stage_in-{consumer}") &
                                                    (spm_results['consumer'] == consumer)]
                transition_cost_options = {}
                if not transition_cost_table.empty:
                    for _, row in transition_cost_table.iterrows():
                        tct_producerStorageType = row['producerStorageType']
                        if '-' not in tct_producerStorageType:
                            continue
                        src, dst = tct_producerStorageType.split('-')
                        if src != producer_storage_type:
                            continue
                        spm_value = row['SPM']
                        transition_cost_options[dst] = {'storage_type': dst, 'SPM': spm_value}
                else:
                    dst = "tmpfs"
                    spm_value = 999
                    transition_cost_options[dst] = {'storage_type': dst, 'SPM': spm_value}


                # Get all read cost options
                read_cost_table = spm_results[(spm_results['producer'] == producer) &
                                              (spm_results['consumer'] == consumer)]
                read_cost_options = {}
                if not read_cost_table.empty:
                    for _, row in read_cost_table.iterrows():
                        rco_consumerStorageType = row['consumerStorageType']
                        spm_value = row['SPM']
                        read_cost_options[rco_consumerStorageType] = {'storage_type': rco_consumerStorageType,
                                                                      'SPM': spm_value}
                else:
                    rco_consumerStorageType = "tmpfs"
                    spm_value = 999
                    read_cost_options[rco_consumerStorageType] = {'storage_type': rco_consumerStorageType,
                                                                  'SPM': spm_value}

                # test
                print()
                print(f"producer: {producer}, consumer: {consumer}")
                print("transition_cost_options:")
                pprint.pprint(transition_cost_options)
                print("read_cost_options:")
                pprint.pprint(read_cost_options)
                # end test

                # Get the option with minimum SPM value
                min_storage_type = ""
                min_spm_value = float("inf")
                for type, value in transition_cost_options.items():
                    if type not in read_cost_options:
                        continue
                    spm_value = transition_cost_options[type]['SPM'] + \
                                read_cost_options[type]['SPM']
                    if spm_value < min_spm_value:
                        min_spm_value = spm_value
                        min_storage_type = type

                # Check and update the current record
                if consumer not in storage_type_selections:
                    storage_type_selections[consumer] = {'storage_type': min_storage_type, 'SPM': min_spm_value}
                elif min_spm_value < storage_type_selections[consumer]['SPM']:
                    storage_type_selections[consumer] = {'storage_type': min_storage_type, 'SPM': min_spm_value}

    # test
    print("storage_type_selections:")
    pprint.pprint(storage_type_selections)
    # end test
    return storage_type_selections



def analyze_spm_results(filename: str) -> Tuple[dict, nx.DiGraph]:
    spm_results = pd.read_csv(filename)
    spm_results = remove_invalid_data(spm_results=spm_results)
    """
    Create the core DAG
    """
    print()
    print("Creating core DAG")
    # core_dag = create_core_dag(spm_results=spm_results)
    core_dag = create_core_dag_of_sra_search()

    # for nodes in nx.topological_generations(core_dag):
    #     for node in nodes

    # for node in nx.topological_sort(core_dag):
    #     # test
    #     print(node)
    #     # end test
    # storage_type_selections = do_algorithm_baseline_0(core_dag=core_dag,
    #                                                  spm_results=spm_results)
    storage_type_selections = do_algorithm_baseline_1(core_dag=core_dag,
                                                      spm_results=spm_results)
    storage_type_dict = {}
    for key, value in storage_type_selections.items():
        storage_type_dict[key] = value['storage_type']

    return storage_type_dict, core_dag


def map_type_to_path(storage_type_dict: dict, local_dir_config: str) -> dict:
    df = pd.read_csv(local_dir_config)
    storage_path_dict = {}
    # for task, storage_type in storage_type_dict.items():
    #     if not df[df['Type'] == storage_type].empty:
    #         path = df[df['Type'] == storage_type]['Actual_Path'].iloc[0]
    #     elif not df[df['Type'] == 'tmpfs'].empty:
    #         path = df[df['Type'] == 'tmpfs']['Actual_Path'].iloc[0]
    #         storage_type_dict[task] = 'tmpfs'
    #     elif not df[df['Type'] == 'nfs'].empty:
    #         path = df[df['Type'] == 'nfs']['Actual_Path'].iloc[0]
    #         storage_type_dict[task] = 'nfs'
    #     else:
    #         assert False, f"Error: cannot find the cooresponding path for the given storage type {storage_type}."
    #     storage_path_dict[task] = path

    for task, storage_type in storage_type_dict.items():
        if not df[df['Type'] == 'beegfs'].empty:
            path = df[df['Type'] == 'beegfs']['Actual_Path'].iloc[0]
            storage_type_dict[task] = 'beegfs'
        else:
            assert False, f"Error: cannot find the cooresponding path for the given storage type {storage_type}."
        storage_path_dict[task] = path

    # test
    print("storage_type_dict")
    pprint.pprint(storage_type_dict)
    print("storage_path_dict")
    pprint.pprint(storage_path_dict)
    # end test

    return storage_path_dict


# def generate_nextflow_config_params(core_dag: nx.DiGraph,
#                                     storage_type_dict: dict,
#                                     storage_path_dict: dict,
#                                     output_storage_config: str):
#     """
#     Generate the Nextflow config file to pass parameters of paths

#     params {
#       alpha = 'default config value'
#     }
#     """
#     with open(output_storage_config, 'w') as fout:
#         # add a tailing directory "output.workspace.2025-08-14T09:58:04"
#         workspace_folder = "output.workspace." + datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
#         fout.write("params {\n")
#         for key, value in storage_type_dict.items():
#             name = f"{key}_Storage_Type"
#             type = value
#             fout.write(f"  {name} = '{type}'\n")
#         for key, value in storage_path_dict.items():
#             name = f"{key}_Actual_Path"
#             path = os.path.join(value, workspace_folder)
#             fout.write(f"  {name} = '{path}'\n")
#         for src in core_dag.nodes():
#             src_type = storage_type_dict[src]
#             path_list = []
#             for dst in core_dag.successors(src):
#                 dst_type = storage_type_dict[dst]
#                 # # test
#                 # print(f"src: {src} src_type: {src_type} dst: {dst} dst_type: {dst_type}")
#                 # # end test
#                 if dst_type != src_type:
#                     dst_path = os.path.join(storage_path_dict[dst], workspace_folder)
#                     path_list.append(dst_path)
#             setting_str = ",".join(path_list)
#             name = f"{src}_Copy_To_Path"
#             fout.write(f"  {name} = '{setting_str}'\n")


#         fout.write("}\n")

def generate_nextflow_config_params_for_sra_search(core_dag: nx.DiGraph,
                                                   storage_type_dict: dict,
                                                   storage_path_dict: dict,
                                                   output_storage_config: str):
    """
    Generate the Nextflow config file to pass parameters of paths

    params {
      alpha = 'default config value'
    }
    """
    with open(output_storage_config, 'w') as fout:
        # add a tailing directory "output.workspace.2025-08-14T09:58:04"
        workspace_folder = "output.workspace." + datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
        fout.write("params {\n")
        for key, value in storage_type_dict.items():
            name = f"{key}_Storage_Type".replace('-', '_')
            type = value
            fout.write(f"  {name} = '{type}'\n")
        for key, value in storage_path_dict.items():
            name = f"{key}_Actual_Path".replace('-', '_')
            path = os.path.join(value, workspace_folder)
            fout.write(f"  {name} = '{path}'\n")
        for src in core_dag.nodes():
            src_type = storage_type_dict[src]
            path_list = []
            for dst in core_dag.successors(src):
                dst_type = storage_type_dict[dst]
                # # test
                # print(f"src: {src} src_type: {src_type} dst: {dst} dst_type: {dst_type}")
                # # end test
                if dst_type != src_type:
                    dst_path = os.path.join(storage_path_dict[dst], workspace_folder)
                    path_list.append(dst_path)
            setting_str = ",".join(path_list)
            name = f"{src}_Copy_To_Path".replace('-', '_')
            fout.write(f"  {name} = '{setting_str}'\n")


        fout.write("}\n")


def modify_tar_compress_storage_type(storage_type_dict: dict,
                                     local_dir_config: str):
    """
    Special handling for tar-compress task
    If its storage type is not a shared type, change it to shared type
    """
    # Get the best shared storage type
    # If beegfs is available, use beegfs, otherwise use nfs
    shared_type = None
    df = pd.read_csv(local_dir_config)
    if not df[df['Type'] == 'beegfs'].empty:
        shared_type = 'beegfs'
    elif not df[df['Type'] == 'nfs'].empty:
        shared_type = 'nfs'
    else:
        assert False, f"Error: cannot find the shared storage type."

    if 'tar-compress' in storage_type_dict:
        if storage_type_dict['tar-compress'] != shared_type:
            print(f"Modifying tar-compress's storage type from {storage_type_dict['tar-compress']} to {shared_type}")
            storage_type_dict['tar-compress'] = shared_type


#---------------
# Main function
#---------------
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--spm_results_file", "-s", type=str, default="output.spm_results.1kg.json",
                        help="SPM results file (JSON)")
    parser.add_argument("--output_storage_config", "-o", type=str, default="nextflow.config.params.storage.nf",
                        help="(output) Nextflow config file containing storage types for each task")
    parser.add_argument("--local_dir_config", "-l", type=str, default="local_dir_config.csv",
                        help="Storage options provided by Linux Resource Detector")
    args = parser.parse_args()

    if len(sys.argv) == 1:
        parser.print_help(sys.stderr)
        sys.exit(-1)
    spm_results_file = args.spm_results_file
    output_storage_config = args.output_storage_config
    local_dir_config = args.local_dir_config

    # Analyze SPM results
    print(f"Reading SPM results file: {spm_results_file}")
    storage_type_dict, core_dag = analyze_spm_results(spm_results_file)
    modify_tar_compress_storage_type(storage_type_dict=storage_type_dict, local_dir_config=local_dir_config)

    # Map the storage type to each particular path
    storage_path_dict = map_type_to_path(storage_type_dict=storage_type_dict, local_dir_config=local_dir_config)

    # Generate the Nextflow config file
    generate_nextflow_config_params_for_sra_search(core_dag=core_dag,
                                    storage_type_dict=storage_type_dict,
                                    storage_path_dict=storage_path_dict,
                                    output_storage_config=output_storage_config)
    print(f"Saved nextflow config file for storage types to {output_storage_config}")