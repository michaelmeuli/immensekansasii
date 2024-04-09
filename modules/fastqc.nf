/*
*  fastqc module
*/

//params.CONTAINER = "quay.io/biocontainers/fastqc:0.11.9--0"
params.CONTAINER = "quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0"

params.OUTPUT = "fastqc_output"

process fastqc_raw_reads {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("assembly/00_fastqc_raw_reads/fastqc", mode: 'copy')
    tag { sample_id }
    container params.CONTAINER

    input:
    tuple val(sample_id), file(fastqs)

    output:
    path("*_fastqc*"), emit: output
    path "fastqc_version.txt", emit: version

    script:
    """
    fastqc -t 2 ${fastqs.join(' ')}

    fastqc --version > fastqc_vers.txt
    echo ${params.CONTAINER} > fastqc_singularity.txt
    cat fastqc_vers.txt fastqc_singularity.txt | tr "\n" "\t" > fastqc_version.txt
    """
}

process fastqc_trimmed_reads {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("assembly/01_fastqc_after_trimming/fastqc", mode: 'copy')
    tag { sample_id }
    container params.CONTAINER

    input:
    tuple val (sample_id), path (read1), path (read2)
    //path (reads)
    //tuple val(batch), file(fastqs)

    output:
    path("*_fastqc*"), emit: output
    path "fastqc_version.txt", emit: version

    script:
    """
    fastqc -t 2 ${read1} ${read2}

    fastqc --version > fastqc_vers.txt
    echo ${params.CONTAINER} > fastqc_singularity.txt
    cat fastqc_vers.txt fastqc_singularity.txt | tr "\n" "\t" > fastqc_version.txt
    """
}
