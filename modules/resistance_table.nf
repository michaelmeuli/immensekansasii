/*
*  Resistance table module
*/

params.CONTAINER = "ezlabgva-busco_v5.3.2_cv1" // this includes python and pandas library

process generate_resistance_table {
    publishDir("assembly/results/${sample_id}/4_resistance_virulence", mode: 'copy')
    //publishDir("${params.output_dir}/${sample_id}/4_resistance_virulence", mode:'copy')
    tag { "${params.run_id}" }
    container params.CONTAINER

    input:
    val (sample_id)
    path (resistance_file)

    output:
    path ("${sample_id}_resistances.tsv"), emit: output_file

    script:
    """
    #cd ${params.output_dir}/${sample_id}/4_resistance_virulence
    resistance_table.py --sample_id ${sample_id}
    
    mv resistances.tsv ${sample_id}_resistances.tsv
    """
}

// Now we get a summary for each sample, but we need to create 1 more process to summarize all these into the transfer_run folder.


process merge_run_resistances {
    publishDir("${params.run_id}_transfer_result", mode: 'copy')
    tag { "${params.run_id}" }

    input:
    path (resistance_file)

    output:
    path ("${params.run_id}_resistances.tsv"), emit: run_resistances

    script:
    """
    #!/bin/bash
    
    # Filename for the summary file

    run_resistance_fn=${params.run_id}_resistances.tsv

    # Get the header from the first file
    head -n 1 \$(ls -1 ${resistance_file} | head -n 1) > \${run_resistance_fn}
    
    # Concatenate all files ignoring the first line (header) of each
    for file in ${resistance_file}; do
        tail -n +2 \$file >> \${run_resistance_fn}
    done

    """
}
