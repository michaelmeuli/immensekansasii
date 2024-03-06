/*
*  16S module
*/

params.CONTAINER = "quay.io/biocontainers/blast:2.12.0--pl5262h3289130_0"
//params.CONTAINER = "https://depot.galaxyproject.org/singularity/blast:2.12.0--pl5262h3289130_0"
params.OUTPUT = "typing16s_output"

process typing_16S {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("assembly/results/${sample_id}/3_quality/16S", mode: 'copy')
    tag { sample_id }
    container params.CONTAINER
    containerOptions "-B ${params.db_16s}"

    input:
    tuple val (sample_id), path (one_contig)

    output:
    tuple val (sample_id), path ("${sample_id}_16S_blast.tab"), emit: blast_tab
    path "blastn_16S_version.txt", emit: version

    script:
    """
    #!/bin/bash

    DB=`find -L ${params.db_16s} -name "*.nhr" | sed 's/.nhr//'`
    blastn -db \$DB  -num_threads ${task.cpus} -max_target_seqs 1 -max_hsps 1 \
           -query ${one_contig} -out ${sample_id}_16S_blast.tab \
           -outfmt "6 qseqid sseqid stitle qlen slen length pident nident mismatch gaps evalue bitscore"
    echo -e NA'\t'NA'\t'NA'\t'NA'\t'NA'\t'NA'\t'NA >> ${sample_id}_16S_blast.tab

    echo "16S \$(blastn -version | head -1)" > blastn_16S_vers.txt
    if [[ ${params.db_16s} == *16S_* ]]; then basename ${params.db_16s} > db_version_16S.txt; else echo "database as of 20171115" > db_version_16S.txt; fi
    echo ${params.CONTAINER} > blastn_16S_singularity.txt
    cat blastn_16S_vers.txt blastn_16S_singularity.txt db_version_16S.txt | tr "\n" "\t" > blastn_16S_version.txt
    """
}
