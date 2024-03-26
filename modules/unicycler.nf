/*
*  unicycler module
*/

params.CONTAINER = "quay.io/biocontainers/unicycler:0.4.8--py39h98c8e45_5"

params.OUTPUT = "unicycler_output"

process unicycler {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("assembly/results/${sample_id}/1_unicycler", mode: 'copy')
    tag { sample_id }
    container params.CONTAINER

    input:
    tuple val (sample_id), path (fastq_r1), path (fastq_r2)

    output:
    tuple val (sample_id), path ("${sample_id}_assembly.fasta"), emit: assembly
    tuple val (sample_id), path ("${sample_id}_unicyler.log"), emit: log
    path "unicycler_version.txt", emit: version

    script:
    """
    unicycler -t ${task.cpus} \
    -1 ${fastq_r1} -2 ${fastq_r2} \
    -o ./

    mv assembly.fasta ${sample_id}_assembly.fasta
    mv unicycler.log ${sample_id}_unicyler.log

    unicycler --version > unicycler_vers.txt
    echo ${params.CONTAINER} > unicycler_singularity.txt
    cat unicycler_vers.txt unicycler_singularity.txt | tr "\n" "\t" > unicycler_version.txt
    """
}


process unicyclerSE {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("assembly/results/${sample_id}/1_unicycler", mode: 'copy')
    tag { sample_id }
    container params.CONTAINER

    input:
    tuple val (sample_id), path (fastq)

    output:
    tuple val (sample_id), path ("${sample_id}_assembly.fasta"), emit: assembly
    tuple val (sample_id), path ("${sample_id}_unicyler.log"), emit: log
    path "unicycler_version.txt", emit: version

    script:
    """
    unicycler -t ${task.cpus} -s ${fastq} -o ./

    mv assembly.fasta ${sample_id}_assembly.fasta
    mv unicycler.log ${sample_id}_unicyler.log

    unicycler --version > unicycler_vers.txt
    echo ${params.CONTAINER} > unicycler_singularity.txt
    cat unicycler_vers.txt unicycler_singularity.txt | tr "\n" "\t" > unicycler_version.txt
    """
}
