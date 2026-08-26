
/*
*  Lissero module
*/

process lissero {
    publishDir("${params.output_dir_sample}/${sample_id}/3_quality/lissero", mode: 'copy')
    tag { sample_id }

    input:
    tuple val (sample_id), path (fasta)

    output:
    path "complete_lissero_version.txt", emit: version
    tuple val (sample_id), path ("${sample_id}_lissero_output.tsv"), emit: summary
    

    script:
    """
    lissero ${fasta} > ${sample_id}_lissero_output.tsv

    # Getting Version information
    lissero --version > lissero_vers.txt
    echo ${task.container} > lissero_singularity.txt
    cat lissero_vers.txt lissero_singularity.txt | tr "\\n" "\\t" > complete_lissero_version.txt

    """
}