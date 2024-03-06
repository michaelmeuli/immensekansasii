/*
*  trimmomatic module
*/

params.CONTAINER = "quay.io/biocontainers/trimmomatic:0.39--hdfd78af_2"
//params.CONTAINER = "https://depot.galaxyproject.org/singularity/trimmomatic:0.39--hdfd78af_2"
params.OUTPUT = "trimmomatic_output"


process trimmomaticPE {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("assembly/results/${sample_id}/0_trimming", mode: 'copy', pattern: "*.quality_read_trimm_info")
    publishDir("assembly/results/${sample_id}/0_trimming", mode: 'copy', pattern: "trimmomatic_version.txt")
    tag { sample_id }
    container params.CONTAINER
    containerOptions "-B ${params.illuminaclip}"

    input:
    tuple val (sample_id), path (fastq)

    output:
    tuple val (sample_id), path ("${sample_id}_r1.fastq.gz"), path ("${sample_id}_r2.fastq.gz"), emit: trimmed_reads
    tuple val (sample_id), path ("${sample_id}.quality_read_trimm_info"), emit: trim_log
    path "trimmomatic_version.txt", emit: version

    script:
    """
    trimmomatic PE \
    -threads ${task.cpus} -phred33 \
    ${fastq} \
    ${sample_id}_r1.fastq.gz \
    ${sample_id}_r1.not-paired.fastq.gz \
    ${sample_id}_r2.fastq.gz \
    ${sample_id}_r2.not-paired.fastq.gz \
    ILLUMINACLIP:${params.illuminaclip}:2:30:10 ${params.trimmomatic_PE_extra} \
    2> ${sample_id}.quality_read_trimm_info

    echo "trimmomatic \$(trimmomatic -version)" > trimmomatic_vers.txt
    echo ${params.CONTAINER} > trimmomatic_singularity.txt
    cat trimmomatic_vers.txt trimmomatic_singularity.txt | tr "\n" "\t" > trimmomatic_version.txt
    """
}


process trimmomaticSE {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("assembly/results/${sample_id}/0_trimming", mode: 'copy', pattern: "*.quality_read_trimm_info")
    publishDir("assembly/results/${sample_id}/0_trimming", mode: 'copy', pattern: "trimmomatic_version.txt")
    tag { sample_id }
    container params.CONTAINER
    containerOptions "-B ${params.illuminaclip}"

    input:
    tuple val (sample_id), path (fastq)

    output:
    tuple val (sample_id), path ("${sample_id}_trimmed.fastq.gz"), emit: trimmed_reads
    tuple val (sample_id), path ("${sample_id}.quality_read_trimm_info"), emit: trim_log
    path "trimmomatic_version.txt", emit: version

    script:
    """
    trimmomatic SE \
    -threads ${task.cpus} -phred33 \
    ${fastq} \
    ${sample_id}_trimmed.fastq.gz \
    ILLUMINACLIP:${params.illuminaclip}:2:30:10 ${params.trimmomatic_SE_extra} \
    2> ${sample_id}.quality_read_trimm_info

    echo "trimmomatic \$(trimmomatic -version)" > trimmomatic_vers.txt
    echo ${params.CONTAINER} > trimmomatic_singularity.txt
    cat trimmomatic_vers.txt trimmomatic_singularity.txt | tr "\n" "\t" > trimmomatic_version.txt
    """
}
