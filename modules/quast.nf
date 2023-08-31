/*
*  quast module
*/

params.CONTAINER = "quay.io/biocontainers/quast:5.0.2--py37pl5262h190e900_4"
//params.CONTAINER = "https://depot.galaxyproject.org/singularity/quast:5.0.2--py37pl5262h190e900_4"
params.OUTPUT = "quast_output"

process quast {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("assembly/results/${sample_id}/3_quality", mode: 'copy')
    tag { fasta }
    container params.CONTAINER

    input:
    tuple val (sample_id), path (fasta)

    output:
    tuple val (sample_id), path ("quast_${sample_id}/transposed_report.tsv"), emit: tsv
    path ("quast_${sample_id}/"), emit: stats
    path "quast_${sample_id}/quast_version.txt", emit: version

    script:
    """
    quast --min-contig 0 -o quast_${sample_id}/ ${fasta}

    quast --version > quast_vers.txt
    echo ${params.CONTAINER} > quast_singularity.txt
    cat quast_vers.txt quast_singularity.txt | tr "\n" "\t" > quast_${sample_id}/quast_version.txt
    """
}
