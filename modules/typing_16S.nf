/*
*  16S module
*/

process typing_16S {
    publishDir("${params.output_dir_sample}/${sample_id}/3_quality/16S", mode: 'copy')
    tag { sample_id }
    containerOptions "-B ${params.db_16s}"

    input:
    tuple val (sample_id), path (one_contig)

    output:
    tuple val (sample_id), path ("${sample_id}_16S_blast.tab"), emit: blast_tab
    path "blastn_16S_version.txt", emit: version
    tuple val (sample_id), env(TAXA), emit: taxa
    tuple val (sample_id), env(ALN_LENGTH), emit: aln_length
    tuple val (sample_id), env(ALN_ID), emit: aln_identity

    script:
    """
    #!/bin/bash

    DB=`find -L ${params.db_16s} -name "*.nhr" | sed 's/.nhr//'`
    blastn -query ${one_contig} \
        -db \$DB -num_threads ${task.cpus} -max_target_seqs 1 -max_hsps 1 \
        -out ${sample_id}_16S_blast.tab \
        -outfmt "6 qseqid sseqid stitle qlen slen length pident nident mismatch gaps evalue bitscore"
    echo -e NA'\t'NA'\t'NA'\t'NA'\t'NA'\t'NA'\t'NA >> ${sample_id}_16S_blast.tab

    echo "16S \$(blastn -version | head -1)" > blastn_16S_vers.txt
    if [[ ${params.db_16s} == *16S_* ]]; then basename ${params.db_16s} > db_version_16S.txt; else echo "database as of 20171115" > db_version_16S.txt; fi
    echo ${task.container} > blastn_16S_singularity.txt
    cat blastn_16S_vers.txt blastn_16S_singularity.txt db_version_16S.txt | tr "\\n" "\\t" > blastn_16S_version.txt

    # Extracting key information:
    TAXA=`head -n 1 ${sample_id}_16S_blast.tab | awk -F "\\t" '{print \$3}'`
    ALN_LENGTH=`head -n 1 ${sample_id}_16S_blast.tab | awk -F "\\t" '{print \$6}'`
    ALN_ID=`head -n 1 ${sample_id}_16S_blast.tab | awk -F "\\t" '{print \$7}'`
    """
}
