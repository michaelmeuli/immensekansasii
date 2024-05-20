/*
*  BUSCO module
*/

//params.CONTAINER = "ezlabgva-busco_v5.3.2_cv1"

process busco {
    publishDir("${params.output_dir_sample}/${sample_id}/3_quality/BUSCO", mode: 'copy')
    tag { sample_id }
    // containerOptions "-B ${params.busco_files}"

    input:
    tuple val (sample_id), path (fasta)
    path busco_lineages_path

    output:
    tuple val (sample_id), path ("${sample_id}/*"), emit: busco_all
    tuple val (sample_id), path ("${sample_id}/short_summary.specific*.txt"), emit: summary_specific // for assembly multiQC (sending specific)
    //tuple val (sample_id), path ("${sample_id}/short_summary.specific*"), emit: summary_specific_folder // for plotting BUSCO results per sample
    //tuple val (sample_id), path ("results/short_summary.generic.*.txt"), optional: true
    path "${sample_id}_busco_version.txt", emit: version
    tuple val (sample_id), path ("${sample_id}/short_summary.generic.eukaryota*.txt"), emit: eukaryota, optional: true // This tells whether sample is eukaryote (ie. Fungi). If yes, checkM is not run.
    tuple val (sample_id), env(COMPLETE_BUSCO), emit: complete_busco
    tuple val (sample_id), env(BUSCO_GROUPS), emit: busco_groups
    tuple val (sample_id), env(BUSCO_LINEAGE), emit: busco_lineage

    script:
    """
    busco -f -m genome -i ${fasta} -o ${sample_id} --auto-lineage --offline --download_path ${busco_lineages_path}
    busco --version > busco_vers.txt
    echo ${task.container} > busco_singularity.txt
    grep "Running BUSCO using lineage dataset" ${sample_id}/logs/busco.log | cut -f2 | cut -d" "  -f6-10 | sed 's/ (prokaryota,//g' | tr ")" " " > busco_lineages_version.txt
    cat busco_vers.txt busco_singularity.txt busco_lineages_version.txt | tr "\\n" "\\t" > ${sample_id}_busco_version.txt

    # Extract key information:
    # grep "C:" ${sample_id}/short_summary.specific.*.txt | sed 's/,D/;D/g' | tr "," "\\t" | cut -f2,5 > ${sample_id}_busco_classification.txt
    COMPLETE_BUSCO=`grep "C:" ${sample_id}/short_summary.specific.*.txt | sed 's/,D/;D/g' | tr "," "\\t" | cut -f2`
    BUSCO_GROUPS=`grep "C:" ${sample_id}/short_summary.specific.*.txt | sed 's/,D/;D/g' | tr "," "\\t" | cut -f5`
    BUSCO_LINEAGE=`grep "lineage dataset is:" ${sample_id}/short_summary.specific.*.txt | awk '{print \$6}'`

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
    // Currently this creates one plot of all assemblies at the same time and publishes in run directory
    publishDir("${params.output_dir_sample}/${sample_id}/3_quality/BUSCO", mode: 'copy')
    tag { sample_id }

    input:
    //path (short_summaries)
    tuple val (sample_id), path (short_summaries_dir)


    output:
    path "**.png", optional: true

    script:
    """
    busco_generate_plot.py -wd \$PWD
    """
}
