/*
*  fastqc module
*/

//params.CONTAINER = "quay.io/biocontainers/fastqc:0.11.9--0"
params.CONTAINER = "quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0"

params.OUTPUT = "fastqc_output"

process fastqc {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("demultiplexing/fastqc", mode: 'copy')
    tag { reads }
    container params.CONTAINER

    input:
    path(reads)

    output:
    path("*_fastqc*"), emit: qc
    path "fastqc_version.txt", emit: version

    script:
    """
    fastqc ${reads}

    fastqc --version > fastqc_vers.txt
    echo ${params.CONTAINER} > fastqc_singularity.txt
    cat fastqc_vers.txt fastqc_singularity.txt | tr "\n" "\t" > fastqc_version.txt
    """
}
