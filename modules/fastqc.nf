/*
*  fastqc module
*/

//params.CONTAINER = "quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0"

params.OUTPUT = "fastqc_output"

process fastqc_raw_reads {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("${params.output_dir_run}/00_QC/00_fastqc_raw_reads/fastqc", mode: 'copy')
    tag { sample_id }

    input:
    tuple val(sample_id), file(fastqs)

    output:
    path("*_fastqc*"), emit: output, optional: true
    path "fastqc_version.txt", emit: version

    script:
    """
    # fastqc -t 2 ${fastqs.join(' ')}
    # Below we try to run fastqc but if it doesn't work (ie file corrupted), write failed into log. Trimmomatic might still work
    fastqc -t 2 ${fastqs.join(' ')} && echo "Success" || echo "Failed to run fastqc completely" > fastqc_error.log
    fastqc --version > fastqc_vers.txt
    echo ${task.container} > fastqc_singularity.txt
    cat fastqc_vers.txt fastqc_singularity.txt | tr "\\n" "\\t" > fastqc_version.txt
    """
}

process fastqc_trimmed_reads {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("${params.output_dir_run}/00_QC/01_fastqc_after_trimming/fastqc", mode: 'copy')
    tag { sample_id }

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
    echo ${task.container} > fastqc_singularity.txt
    cat fastqc_vers.txt fastqc_singularity.txt | tr "\\n" "\\t" > fastqc_version.txt
    """
}
