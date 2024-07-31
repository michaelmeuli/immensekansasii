
/*
*  checkM module
*/

// params.CONTAINER = "quay.io/biocontainers/checkm-genome:1.2.2--pyhdfd78af_1"
//params.OUTPUT = "checkm_output"

process checkm {
    publishDir("${params.output_dir_sample}/${sample_id}/3_quality/checkM", mode: 'copy')
    tag { sample_id }

    input:
    tuple val (sample_id), path (fasta)

    output:
    tuple val (sample_id), path ("results/*"), emit: checkm_all
    path "${sample_id}_checkm_version.txt", emit: version
    tuple val (sample_id), path ("checkm_output.tsv"), emit: summary_specific
    // Output the values to be included in the summary file:
    tuple val (sample_id), env(CHECKM_COMPLETENESS), emit: checkm_completeness
    tuple val (sample_id), env(CHECKM_CONTAMINATION), emit: checkm_contamination
    tuple val (sample_id), env(CHECKM_HETEROGENEITY), emit: checkm_heterogeneity

    script:
    """
    checkm lineage_wf --reduced_tree -x fasta \$PWD "results/" > checkm_output.tsv

    echo "checkM" \$(checkm -h | grep '...:::' | grep -oE 'v[0-9]+\\.[0-9]+\\.[0-9]+') > checkm_vers.txt
    echo ${task.container} > checkm_singularity.txt
    cat checkm_vers.txt checkm_singularity.txt | tr "\\n" "\\t" > ${sample_id}_checkm_version.txt

    # Extracting the important results for the quality summary file
    #This was the original string manipulation to get the results:
    #CHECKM_RES=`cat checkm_output.tsv | grep ${sample_id} | awk '{print \$(NF-2), \$(NF-1), \$(NF)}'`
    
    CHECKM_COMPLETENESS=`cat checkm_output.tsv | grep ${sample_id}_assembly | awk '{print \$(NF-2)}'`
    CHECKM_CONTAMINATION=`cat checkm_output.tsv | grep ${sample_id}_assembly | awk '{print \$(NF-1)}'`
    CHECKM_HETEROGENEITY=`cat checkm_output.tsv | grep ${sample_id}_assembly | awk '{print \$(NF)}'`

    # Remove larg temp files that are not needed:
    rm -R results/bins
    """
}