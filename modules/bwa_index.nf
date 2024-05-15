/*
*  bwa index module
*/

//params.CONTAINER = "quay.io/biocontainers/bwa:0.7.17--h5bf99c6_8"

params.OUTPUT = ""

process bwaIndex {
    tag { sample_id }

    input:
    tuple val (sample_id), path(assembly)

    output:
    tuple val (sample_id), path("${assembly}.*"), emit: index
    path "bwa_index_version.txt", emit: version

    script:
    """
    bwa index ${assembly} 2> bwa_index.err

    echo "bwa index \$(bwa 2>&1 | grep Version | cut -f2 -d " ")" > bwa_index_vers.txt
    echo ${task.container} > bwa_index_singularity.txt
    cat bwa_index_vers.txt bwa_index_singularity.txt | tr "\\n" "\\t" > bwa_index_version.txt
    """
}
