/*
*  prokka module
*/

 // "bioconda::prokka=1.14.6"
//params.CONTAINER = "quay.io/biocontainers/prokka:1.14.6--pl5262hdfd78af_1"
//params.CONTAINER = "https://depot.galaxyproject.org/singularity/prokka:1.14.6--pl5262hdfd78af_1"
//params.OUTPUT = "prokka_output"

process prokka {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("${params.output_dir_sample}/${sample_id}", pattern: "2_annotation/*", mode: 'copy')
    tag { sample_id }

    input:
    tuple val (sample_id), path (fasta)

    output:
    tuple val(sample_id), path ("*/${sample_id}.fna"), emit: fna
    path ("2_annotation/*"), emit: annot_all
    path "prokka_version.txt", emit: version

    script:
    """
    prokka \\
      --addgenes --mincontiglen 200 --genus Genus \\
      --species species --prefix ${sample_id} --rfam --locustag ${sample_id} \\
      --strain ${sample_id} --force --outdir 2_annotation --cpus ${task.cpus} ${fasta}

    echo \$(prokka --version 2>&1) > prokka_vers.txt
    echo ${task.container} > prokka_singularity.txt
    cat prokka_vers.txt prokka_singularity.txt | tr "\\n" "\\t" > prokka_version.txt
    """
}
