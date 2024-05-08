/*
*  trimmomatic module
*/

//params.CONTAINER = "quay.io/biocontainers/trimmomatic:0.39--hdfd78af_2"
//params.OUTPUT = "trimmomatic_output"


process trimmomaticPE {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("${params.output_dir_sample}/${sample_id}/0_trimming", mode: 'copy', pattern: "*.quality_read_trimm_info")
    publishDir("${params.output_dir_sample}/${sample_id}/0_trimming", mode: 'copy', pattern: "trimmomatic_version.txt")
    tag { sample_id }
    

    input:
    tuple val (sample_id), path (fastq)

    output:
    tuple val (sample_id), path ("${sample_id}_r1.fastq.gz"), path ("${sample_id}_r2.fastq.gz"), emit: trimmed_reads
    tuple val (sample_id), path ("${sample_id}.quality_read_trimm_info"), emit: trim_log
    path "trimmomatic_version.txt", emit: version
    tuple val(sample_id), env(PASSED_PERC), emit: passed_reads_percentage
    tuple val(sample_id), env(PASSED_READS), emit: passed_reads_number


    script:
    """
    illuminaclip_path=/usr/local/share/trimmomatic-*/adapters/NexteraPE-PE.fa # defined in trimmomatic container

    trimmomatic PE \
    -threads ${task.cpus} -phred33 \
    ${fastq} \
    ${sample_id}_r1.fastq.gz \
    ${sample_id}_r1.not-paired.fastq.gz \
    ${sample_id}_r2.fastq.gz \
    ${sample_id}_r2.not-paired.fastq.gz \
    ILLUMINACLIP:\$illuminaclip_path:2:30:10 ${params.trimmomatic_PE_extra} \
    2> ${sample_id}.quality_read_trimm_info

    echo "trimmomatic \$(trimmomatic -version)" > trimmomatic_vers.txt
    echo ${task.container} > trimmomatic_singularity.txt
    cat trimmomatic_vers.txt trimmomatic_singularity.txt | tr "\n" "\t" > trimmomatic_version.txt
    
    # Extracting passed-reads percentage info for summary
    PASSED_PERC=`grep "Both Surviving" ${sample_id}.quality_read_trimm_info | awk '{print \$8}' | tr -d '()%'`
    PASSED_READS=`grep "Both Surviving" ${sample_id}.quality_read_trimm_info | awk '{print \$7}'`
    """


}


process trimmomaticSE {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("${params.output_dir_sample}/${sample_id}/0_trimming", mode: 'copy', pattern: "*.quality_read_trimm_info")
    publishDir("${params.output_dir_sample}/${sample_id}/0_trimming", mode: 'copy', pattern: "trimmomatic_version.txt")
    tag { sample_id }
    // containerOptions "-B ${params.illuminaclip}"

    input:
    tuple val (sample_id), path (fastq)
    path illuminaclip_path

    output:
    tuple val (sample_id), path ("${sample_id}_trimmed.fastq.gz"), emit: trimmed_reads
    tuple val (sample_id), path ("${sample_id}.quality_read_trimm_info"), emit: trim_log
    path "trimmomatic_version.txt", emit: version
    tuple val(sample_id), env(PASSED_PERC), emit: passed_reads_percentage


    script:
    """
    trimmomatic SE \
    -threads ${task.cpus} -phred33 \
    ${fastq} \
    ${sample_id}_trimmed.fastq.gz \
    ILLUMINACLIP:${illuminaclip_path}:2:30:10 ${params.trimmomatic_SE_extra} \
    2> ${sample_id}.quality_read_trimm_info

    echo "trimmomatic \$(trimmomatic -version)" > trimmomatic_vers.txt
    echo ${task.container} > trimmomatic_singularity.txt
    cat trimmomatic_vers.txt trimmomatic_singularity.txt | tr "\n" "\t" > trimmomatic_version.txt

    # Extracting passed-reads percentage info for summary
    PASSED_PERC=`grep "Both Surviving" ${sample_id}.quality_read_trimm_info | awk '{print \$8}' | tr -d '()%'`
    """
}
