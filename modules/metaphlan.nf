/*
*  metaphlan module
*/

params.CONTAINER = "quay.io/biocontainers/metaphlan:3.0.13--pyhb7b1952_0"
//params.CONTAINER = "https://depot.galaxyproject.org/singularity/metaphlan:3.0.13--pyhb7b1952_0"
params.OUTPUT = "metaphlan_output"


process metaphlan3 {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("assembly/results/${sample_id}/3_quality/Metaphlan3", mode: 'copy')
    tag { sample_id }
    container params.CONTAINER
    containerOptions "-B ${params.metaphlan_db}"

    input:
    tuple val (sample_id), path (fastq_r1), path (fastq_r2)

    output:
    tuple val (sample_id), path ("${sample_id}_profiled_metagenome.txt"), emit: profile
    tuple val (sample_id), path ("${sample_id}.error.txt"), emit: error
    path "metaphlan_version.txt", emit: version

    script:
    """
    bowtie2 --sam-no-hd --sam-no-sq --no-unal --very-sensitive  \
            -S ${sample_id}_alignment.sam \
            -x ${params.metaphlan_db}/${params.metaphlan_db_name} \
            -1 ${fastq_r1} -2 ${fastq_r2}

    metaphlan ${sample_id}_alignment.sam --input_type sam --nproc ${task.cpus} \
              --index ${params.metaphlan_db_name} \
              --bowtie2db ${params.metaphlan_db} \
              > ${sample_id}_profiled_metagenome.txt \
              2> ${sample_id}.error.txt

    metaphlan --version > metaphlan_vers.txt
    echo "mpa_v30_CHOCOPhlAn_201901" > metaphlan_db_version.txt
    echo ${params.CONTAINER} > metaphlan_singularity.txt
    cat metaphlan_vers.txt metaphlan_singularity.txt metaphlan_db_version.txt | tr "\n" "\t" > metaphlan_version.txt
    """
}


process metaphlan3SE {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("assembly/results/${sample_id}/3_quality/Metaphlan3", mode: 'copy')
    tag { sample_id }
    container params.CONTAINER
    containerOptions "-B ${params.metaphlan_db}"

    input:
    tuple val (sample_id), path (fastq)

    output:
    tuple val (sample_id), path ("${sample_id}_profiled_metagenome.txt"), emit: profile
    tuple val (sample_id), path ("${sample_id}.error.txt"), emit: error
    path "metaphlan_version.txt", emit: version

    script:
    """
    bowtie2 --sam-no-hd --sam-no-sq --no-unal --very-sensitive  \
            -S ${sample_id}_alignment.sam \
            -x ${params.metaphlan_db}/${params.metaphlan_db_name} \
            -U ${fastq}

    metaphlan ${sample_id}_alignment.sam --input_type sam --nproc ${task.cpus} \
              --index ${params.metaphlan_db_name} \
              --bowtie2db ${params.metaphlan_db} \
              > ${sample_id}_profiled_metagenome.txt \
              2> ${sample_id}.error.txt

    metaphlan --version > metaphlan_vers.txt
    echo ${params.metaphlan_db_name} > metaphlan_db_version.txt
    echo ${params.CONTAINER} > metaphlan_singularity.txt
    cat metaphlan_vers.txt metaphlan_singularity.txt metaphlan_db_version.txt | tr "\n" "\t" > metaphlan_version.txt
    """
}
