/*
*  multiqc module
*/

params.CONTAINER = "quay.io/biocontainers/multiqc:1.11--pyhdfd78af_0"
//params.CONTAINER = "https://depot.galaxyproject.org/singularity/multiqc:1.11--pyhdfd78af_0"
params.OUTPUT = "multiqc_output"

process multiqc {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("assembly/preprocessing/multiqc", mode: 'copy')
    tag { "${params.run_id}" }
    container params.CONTAINER

    input:
    path (inputfiles)

    output:
    path "multiqc_report.html", emit: multiqc_report
    path "multiqc_data/*"
    path "multiqc_version.txt", emit: version

    script:
    """
    multiqc .

    multiqc --version > multiqc_vers.txt
    echo ${params.CONTAINER} > multiqc_singularity.txt
    cat multiqc_vers.txt multiqc_singularity.txt | tr "\n" "\t" > multiqc_version.txt
    """
}


process multiqc_reads {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("demultiplexing/multiqc", mode: 'copy')
    publishDir("${params.run_id}_transfer_result", pattern: '*_multiqc_reads.html', mode: 'copy')
    tag { "${params.run_id}" }
    container params.CONTAINER

    input:
    path (reports)
    path (fastqcs)
    path (trim_logs)

    output:
    path "${params.run_id}_multiqc_reads.html", emit: multiqc_report
    path "${params.run_id}_multiqc_reads_data/*"
    path "multiqc_version.txt", emit: version

    script:
    """
    multiqc -m fastqc -m trimmomatic ${reports} ${fastqcs} ${trim_logs} -n ${params.run_id}_multiqc_reads

    multiqc --version > multiqc_vers.txt
    echo ${params.CONTAINER} > multiqc_singularity.txt
    cat multiqc_vers.txt multiqc_singularity.txt | tr "\n" "\t" > multiqc_version.txt
    """
}


process multiqc_assembly {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("assembly/multiqc", mode: 'copy')
    publishDir("${params.run_id}_transfer_result", pattern: '*_multiqc_assembly_report.html', mode: 'copy')
    tag { "${params.run_id}" }
    container params.CONTAINER

    input:
    path (trim_logs)
    path (quast_stats)
    path (prokka_output)
    path (busco_summaries)

    output:
    path "${params.run_id}_multiqc_assembly.html", emit: multiqc_report
    path "${params.run_id}_multiqc_assembly_data/*"
    path "multiqc_version.txt", emit: version

    script:
    """
    multiqc -m quast -m prokka -m busco ${trim_logs} ${prokka_output} ${quast_stats} ${busco_summaries} -n ${params.run_id}_multiqc_assembly

    multiqc --version > multiqc_vers.txt
    echo ${params.CONTAINER} > multiqc_singularity.txt
    cat multiqc_vers.txt multiqc_singularity.txt | tr "\n" "\t" > multiqc_version.txt
    """
}
