/*
*  abricate module
*/

//params.CONTAINER = "quay.io/biocontainers/abricate:1.0.1--ha8f3691_2"
params.OUTPUT = "abricate_output"

process abricate {
    publishDir("${params.output_dir_sample}/${sample_id}/4_resistance_virulence", mode: 'copy')
    tag { fasta }

    input:
    tuple val (sample_id), path (fasta)

    output:
    path ("${sample_id}_resistance.tab"), emit: resistance
    path ("${sample_id}_virulence.tab"), emit: virulence
    path "abricate_version.txt", emit: version
    val ("${sample_id}"), emit:sample_id

    script:
    """
    abricate --quiet --nopath --db ncbi ${fasta} > ${sample_id}_resistance.tab
    abricate --quiet --nopath --db vfdb ${fasta} > ${sample_id}_virulence.tab

    abricate --version > abricate_vers.txt
    abricate --list | grep ncbi | cut -f1,4 | sed 's/\t/ version /g' > abricate_ncbi_version.txt
    abricate --list | grep vfdb | cut -f1,4 | sed 's/\t/ version /g' > abricate_vfdb_version.txt
    echo ${task.container} > abricate_singularity.txt
    cat abricate_vers.txt abricate_singularity.txt abricate_ncbi_version.txt abricate_vfdb_version.txt | tr "\n" "\t" > abricate_version.txt
    """
}
