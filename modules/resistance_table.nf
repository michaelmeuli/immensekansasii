/*
*  Resistance table module
*/

process generate_resistance_table {
    publishDir("${params.output_dir_sample}/${sample_id}/4_resistance_virulence/01_Abricate", mode: 'copy')
    tag { "${params.run_id}" }
    

    input:
    tuple val(sample_id), path(resistance_file)

    output:
    path ("${sample_id}_resistances_summary.tsv"), emit: output_file

    script:
    """
    resistance_table.py --sample_id ${sample_id}
    
    mv resistances.tsv ${sample_id}_resistances_summary.tsv
    """
}

// Now we get a summary for each sample, but we need to create 1 more process to summarize all these into the transfer_run folder.


process merge_run_resistances {
    publishDir("${params.output_dir_run}", mode: 'copy')
    tag { "${params.run_id}" }
    
    input:
    path(resistance_file)

    output:
    path ("${params.run_id}_abricate_resistances.tsv"), emit: run_resistances

    script:
    """
    #!/bin/bash
    
    # Filename for the summary file

    run_resistance_fn=${params.run_id}.tsv

    # Get the header from the first file
    head -n 1 \$(ls -1 ${resistance_file} | head -n 1) > \${run_resistance_fn}
    
    # Concatenate all files ignoring the first line (header) of each
    for file in ${resistance_file}; do
        tail -n +2 \$file >> \${run_resistance_fn}
    done

    # Sort the resistance file and rename to _abricate_resistances.tsv to the file
    (head -n 1 \${run_resistance_fn} && tail -n +2 \${run_resistance_fn} | sort) > \${run_resistance_fn%.*}_abricate_resistances.tsv


    """
}
