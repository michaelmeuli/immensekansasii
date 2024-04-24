/*
*  metaphlan module
*/

// params.CONTAINER = "quay.io/biocontainers/metaphlan:3.0.13--pyhb7b1952_0"
params.CONTAINER = "quay.io/biocontainers/metaphlan:4.1.0--pyhca03a8a_0"

//params.CONTAINER = "https://depot.galaxyproject.org/singularity/metaphlan:3.0.13--pyhb7b1952_0"
params.OUTPUT = "metaphlan_output"


process metaphlan4 {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("assembly/results/${sample_id}/3_quality/Metaphlan4", mode: 'copy')
    tag { sample_id }
    container params.CONTAINER
    // containerOptions "-B ${params.metaphlan_db}"

    input:
    tuple val (sample_id), path (fastq_r1), path (fastq_r2)
    path metaphlan_database

    output:
    tuple val (sample_id), path ("${sample_id}_profiled_metagenome.txt"), emit: profile
    tuple val (sample_id), path ("${sample_id}.error.txt"), emit: error
    path "metaphlan_version.txt", emit: version
    tuple val (sample_id), env(TAXA), emit: taxa
    tuple val (sample_id), env(PURITY), emit: purity

    script:
    """

    metaphlan ${fastq_r1},${fastq_r2} --input_type fastq --nproc ${task.cpus} \
              --index ${params.metaphlan_db_name} \
              --bowtie2db ${metaphlan_database} \
              --bowtie2out ${sample_id}.bowtie2.bz2 \
              -o ${sample_id}_profiled_metagenome.txt \
              > ${sample_id}.error.txt

    metaphlan --version > metaphlan_vers.txt
    echo ${params.metaphlan_db_name} > metaphlan_db_version.txt
    echo ${params.CONTAINER} > metaphlan_singularity.txt
    cat metaphlan_vers.txt metaphlan_singularity.txt metaphlan_db_version.txt | tr "\n" "\t" > metaphlan_version.txt

    TAXA=`grep "s__" ${sample_id}_profiled_metagenome.txt  | grep -v "t__" | awk '{split(\$0,a,"|"); print a[7],"\\t",\$3}'| awk -F __ '{print \$2}' | cut -f1 | head -n 1`
    PURITY=`grep "s__" ${sample_id}_profiled_metagenome.txt  | grep -v "t__" | awk '{split(\$0,a,"|"); print a[7],"\\t",\$3}'| awk -F __ '{print \$2}' | cut -f3 | head -n 1`
    
    """
}


process metaphlan4SE {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("assembly/results/${sample_id}/3_quality/Metaphlan4", mode: 'copy')
    tag { sample_id }
    container params.CONTAINER
    // containerOptions "-B ${params.metaphlan_db}"

    input:
    tuple val (sample_id), path (fastq)
    path metaphlan_database

    output:
    tuple val (sample_id), path ("${sample_id}_profiled_metagenome.txt"), emit: profile
    tuple val (sample_id), path ("${sample_id}.error.txt"), emit: error
    path "metaphlan_version.txt", emit: version
    tuple val (sample_id), env(TAXA), emit: taxa
    tuple val (sample_id), env(PURITY), emit: purity

    script:
    """
    bowtie2 --sam-no-hd --sam-no-sq --no-unal --very-sensitive  \
            -S ${sample_id}_alignment.sam \
            -x ${metaphlan_database}/${params.metaphlan_db_name} \
            -U ${fastq}

    metaphlan ${sample_id}_alignment.sam --input_type sam --nproc ${task.cpus} \
              --index ${params.metaphlan_db_name} \
              --bowtie2db ${metaphlan_database} \
              > ${sample_id}_profiled_metagenome.txt \
              2> ${sample_id}.error.txt

    metaphlan --version > metaphlan_vers.txt
    echo ${params.metaphlan_db_name} > metaphlan_db_version.txt
    echo ${params.CONTAINER} > metaphlan_singularity.txt
    cat metaphlan_vers.txt metaphlan_singularity.txt metaphlan_db_version.txt | tr "\n" "\t" > metaphlan_version.txt
    
    TAXA=`grep "s__" ${sample_id}_profiled_metagenome.txt  | grep -v "t__" | awk '{split(\$0,a,"|"); print a[7],"\\t",\$3}'| awk -F __ '{print \$2}' | cut -f1 | head -n 1`
    PURITY=`grep "s__" ${sample_id}_profiled_metagenome.txt  | grep -v "t__" | awk '{split(\$0,a,"|"); print a[7],"\\t",\$3}'| awk -F __ '{print \$2}' | cut -f3 | head -n 1`
    
    """
}