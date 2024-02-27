/*
*  BUSCO module
*/

params.CONTAINER = "ezlabgva-busco_v5.3.2_cv1"
params.OUTPUT = "busco_output"

process busco {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("assembly/results/${sample_id}/3_quality/BUSCO", mode: 'copy')
    tag { sample_id }
    container params.CONTAINER
    containerOptions "-B ${params.busco_files}"

    input:
    tuple val (sample_id), path (fasta)

    output:
    tuple val (sample_id), path ("${sample_id}/*"), emit: busco_all
    tuple val (sample_id), path ("${sample_id}/short_summary.specific.*.txt"), emit: summary_specific
    tuple val (sample_id), path ("${sample_id}/short_summary.generic.*.txt"), optional: true
    path "${sample_id}_busco_version.txt", emit: version

    script:
    """
    busco -m genome -i ${fasta} -o ${sample_id} --auto-lineage --offline --download_path ${params.busco_files}
    busco --version > busco_vers.txt
    echo ${params.CONTAINER} > busco_singularity.txt
    grep "Running BUSCO using lineage dataset" ${sample_id}/logs/busco.log | cut -f2 | cut -d" "  -f6-10 | sed 's/ (prokaryota,//g' | tr ")" " " > busco_lineages_version.txt
    cat busco_vers.txt busco_singularity.txt busco_lineages_version.txt | tr "\n" "\t" > ${sample_id}_busco_version.txt
    """
}


process get_busco_lineages {
    tag { "${params.run_id}" }

    input:
    path (busco_versions)

    output:
    path "busco_version.txt", emit: version

    script:
    """
    for file in ${busco_versions}; do cat \$file >> all_lineages.txt && echo   >> all_lineages.txt; done
    cat all_lineages.txt | cut -f1-4 | head -1 > lineages.txt
    cat all_lineages.txt | cut -f5 | sort | uniq | tr "\n" ";" >> lineages.txt
    tr "\n" "\t" < lineages.txt > busco_version.txt
    """
}


process busco_plot {
    publishDir("${params.run_id}_transfer_result", mode: 'copy')
    tag { "${params.run_id}" }
    container params.CONTAINER

    input:
    path (short_summaries)

    output:
    path "**.png"

    script:
    """
    busco_generate_plot.py -wd \$PWD
    """
}
