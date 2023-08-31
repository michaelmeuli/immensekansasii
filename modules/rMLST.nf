/*
*  rMLST module
*/

params.CONTAINER = "quay.io/biocontainers/blast:2.12.0--pl5262h3289130_0"
//params.CONTAINER = "https://depot.galaxyproject.org/singularity/blast:2.12.0--pl5262h3289130_0"
params.OUTPUT = "rmlst_output"

process rMLST {
    // publishDir(params.OUTPUT, mode: 'copy')
    // publishDir("results/${fasta.getBaseName()}/3_quality/rMLST", mode: 'copy')
    tag { fasta }
    container params.CONTAINER

    input:
    tuple val (sample_id), path (fasta)
    path (db_rMLST)

    output:
    tuple val (sample_id), path ("rMLST_blast_*.tab"), emit: blast_tabs
    path "blastn_rMLST_version.txt", emit: version

    script:
    """
    #!/bin/bash

    for gene in ${db_rMLST}/*.fas
    do
    let counter=counter+1
    blastn -num_threads ${task.cpus} -db "\$gene" -query ${fasta} -max_target_seqs 100 -max_hsps 1 \
    -outfmt "6 qseqid sseqid stitle qlen slen length pident nident mismatch gaps evalue bitscore" \
    > rMLST_blast_"\$counter".tab
    done

    echo "rMLST \$(blastn -version | head -1)" > blastn_rMLST_vers.txt
    echo ${db_rMLST} > db_version_rMLST.txt
    echo ${params.CONTAINER} > blastn_rMLST_singularity.txt
    cat blastn_rMLST_vers.txt blastn_rMLST_singularity.txt db_version_rMLST.txt | tr "\n" "\t" > blastn_rMLST_version.txt
    """
}

process call_rMLST {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("assembly/results/${sample_id}/3_quality/rMLST", mode: 'copy')
    tag { sample_id }

    input:
    tuple val (sample_id), path (blast_tabs)
    path (bigsdb_rMLST)

    output:
    tuple val (sample_id), path ("${sample_id}_rMLST.tab"), emit: rmlst

    script:
    """
    call_rMLST_updated_P3.py ${bigsdb_rMLST} \
    ${blast_tabs} > ${sample_id}_rMLST.tab
    """
}
