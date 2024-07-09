/*
*  rMLST module
*/
// Using prokka container because it contains blast & python
//params.CONTAINER = "quay.io/biocontainers/prokka:1.14.6--pl5262hdfd78af_1"

process rMLST {
    tag { fasta }
    containerOptions "-B ${params.db_rMLST}"


    input:
    tuple val (sample_id), path (fasta)

    output:
    tuple val (sample_id), path ("rMLST_blast_*.tab"), emit: blast_tabs
    path "blastn_rMLST_version.txt", emit: version

    script:
    """
    #!/bin/bash

    for gene in ${params.db_rMLST}/*.fas
    do
    let counter=counter+1
    blastn -num_threads ${task.cpus} -db "\$gene" -query ${fasta} -max_target_seqs 100 -max_hsps 1 \
    -outfmt "6 qseqid sseqid stitle qlen slen length pident nident mismatch gaps evalue bitscore" \
    > rMLST_blast_"\$counter".tab
    done

    echo "rMLST \$(blastn -version | head -1)" > blastn_rMLST_vers.txt
    echo ${params.db_rMLST} > db_version_rMLST.txt
    echo ${task.container} > blastn_rMLST_singularity.txt
    cat blastn_rMLST_vers.txt blastn_rMLST_singularity.txt db_version_rMLST.txt | tr "\\n" "\\t" > blastn_rMLST_version.txt
    """
}

process rMLST_call {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("${params.output_dir_sample}/${sample_id}/3_quality/rMLST", mode: 'copy')
    tag { sample_id }
    containerOptions "-B ${params.bigsdb_rMLST}"
    

    input:
    tuple val (sample_id), path (blast_tabs)

    output:
    tuple val (sample_id), path ("${sample_id}_rMLST.tab"), emit: rmlst
    tuple val (sample_id), env(TAXA), emit: taxa
    tuple val (sample_id), env(BEST_rST), emit: best_rST
    tuple val (sample_id), env(ALLELES_MISSING), emit: alleles_missing

    script:
    """
    call_rMLST_updated_P3.py ${params.bigsdb_rMLST} \
    ${blast_tabs} > ${sample_id}_rMLST.tab

    # Extracting key information
    TAXA=`cut -f1 -d\$'\t' ${sample_id}_rMLST.tab`
    BEST_rST=`cut -f2 -d\$'\t' ${sample_id}_rMLST.tab`
    ALLELES_MISSING=`cut -f3 -d\$'\t' ${sample_id}_rMLST.tab`
    """
}
