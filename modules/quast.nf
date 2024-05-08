/*
*  quast module
*/

//params.CONTAINER = "quay.io/biocontainers/quast:5.0.2--py37pl5262h190e900_4"

//params.OUTPUT = "quast_output"

process quast {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("${params.output_dir_sample}/${sample_id}/3_quality", mode: 'copy')
    tag { fasta }

    input:
    tuple val (sample_id), path (fasta)

    output:
    tuple val (sample_id), path ("quast_${sample_id}/transposed_report.tsv"), emit: tsv
    path ("quast_${sample_id}/"), emit: stats
    path "quast_${sample_id}/quast_version.txt", emit: version
    tuple val(sample_id), env(NUM_CONTIG), emit: number_contigs
    tuple val(sample_id), env(TOTAL_LENGTH), emit: total_length
    tuple val(sample_id), env(N50), emit: n50
    tuple val(sample_id), env(GC_PERCENT), emit: gc_percent

    script:
    """
    quast --min-contig 0 -o quast_${sample_id}/ ${fasta}

    quast --version > quast_vers.txt
    echo ${task.container} > quast_singularity.txt
    cat quast_vers.txt quast_singularity.txt | tr "\n" "\t" > quast_${sample_id}/quast_version.txt

    # Extracting key information:
    tail -n 1 quast_${sample_id}/transposed_report.tsv | awk '{print \$14 "\\t" \$16  "\\t" \$18  "\\t" \$17 }' > ${sample_id}_contig_count.txt
    NUM_CONTIG=`tail -n 1 quast_${sample_id}/transposed_report.tsv | awk '{print \$14}'`
    TOTAL_LENGTH=`tail -n 1 quast_${sample_id}/transposed_report.tsv | awk '{print \$16}'`
    N50=`tail -n 1 quast_${sample_id}/transposed_report.tsv | awk '{print \$18}'`
    GC_PERCENT=`tail -n 1 quast_${sample_id}/transposed_report.tsv | awk '{print \$17}'`
    
    """
}
