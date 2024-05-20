/*
*  assign_quality module
*/


process assign_quality {
    publishDir("${params.output_dir_run}/", mode: 'copy')
    tag { "${params.run_id}" }

    input:
    tuple val (sample_id), path (fasta)

    output:
    tuple val (sample_id), path ("${sample_id}_concatenated_contigs.fna"), emit: one_contig

    script:
    """
    assign_quality.py ${fasta} ${sample_id} \ 
    """
}

//THOUGHTS

// in the python file, define mapping between rules.csv headers and quality.tab headers. Then look for all_species criteria, override with genus criteria, override with species criteria. Output same summary file with additional columns??
//     > ${sample_id}_concatenated_contigs.fna
