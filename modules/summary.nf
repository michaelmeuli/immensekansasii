/*
*  summary module
*/

params.OUTPUT = "summary"

process summary_sample {
    publishDir("assembly/results/${sample_id}/3_quality/summary", mode: 'copy')
    // execute on the main node (no special software needed so no need to submit a job and use a container)
    tag { sample_id }
    //containerOptions "-B ${params.input}"
    

    input:
    tuple val (sample_id), val (trimm_out_passed_reads_percentage), val (trimm_out_passed_reads_number), val (coverage_read_depth), val (coverage_alt_bases), val (insertsize_insert_size),  val (assembly_stats_number_contigs), val (assembly_stats_total_length), val (assembly_stats_n50), val (assembly_stats_gc_percent), val (typ16S_taxa), val (typ16S_aln_length), val (typ16S_aln_identity), val (metaphlan_out_taxa),  val (metaphlan_out_purity), val (rmlst_out_taxa), val (rmlst_out_best_rST), val (rmlst_out_alleles_missing), val (busco_out_complete_busco), val (busco_out_busco_groups), val (busco_out_busco_lineage), val (gtdb_out_species), val (gtdb_out_ani_ref), val (gtdb_out_ani_ani), val (gtdb_out_ani_af), val (gtdb_out_placement_ref), val (gtdb_out_gtdb_notes), val (qc_size_warning)

    output:
    path ("*.txt"), emit: summary_files
    path ("${sample_id}.tab"), emit: sample_quality

    script:

    """
    #!/bin/bash
    
    # Get the predicted species name from the parent directory of the fastq files.
    if [[ -d $PWD/reads ]]; then find $PWD/reads -name ${sample_id}*.fastq.gz | awk -F/ '{print \$(NF-1)}' | uniq > ${sample_id}_expected_species.txt; else find ${params.input} -name ${sample_id}*.fastq.gz | awk -F/ '{print \$(NF-1)}' | uniq > ${sample_id}_expected_species.txt; fi
    EXPECTED_SPECIES=`cat ${sample_id}_expected_species.txt`

    # Writing the variables passed as input to the sample specific file
    # These sample-specific summaries are then merged in the merge_summaries process
    
    echo "${sample_id}" > ${sample_id}_tmp.tab
    # This is an environmental variable in this script, not an input like the others
    echo "\${EXPECTED_SPECIES}" >> ${sample_id}_tmp.tab
    echo "${trimm_out_passed_reads_percentage}" >> ${sample_id}_tmp.tab
    echo "${trimm_out_passed_reads_number}" >> ${sample_id}_tmp.tab
    echo "${coverage_read_depth}" >> ${sample_id}_tmp.tab
    echo "${coverage_alt_bases}" >> ${sample_id}_tmp.tab
    echo "${insertsize_insert_size}" >> ${sample_id}_tmp.tab
    echo "${assembly_stats_number_contigs}" >> ${sample_id}_tmp.tab
    echo "${assembly_stats_total_length}" >> ${sample_id}_tmp.tab
    echo "${assembly_stats_n50}" >> ${sample_id}_tmp.tab
    echo "${assembly_stats_gc_percent}" >> ${sample_id}_tmp.tab
    echo "${busco_out_complete_busco}" >> ${sample_id}_tmp.tab
    echo "${busco_out_busco_groups}" >> ${sample_id}_tmp.tab
    echo "${busco_out_busco_lineage}" >> ${sample_id}_tmp.tab
    echo "${typ16S_taxa}" >> ${sample_id}_tmp.tab
    echo "${typ16S_aln_length}" >> ${sample_id}_tmp.tab
    echo "${typ16S_aln_identity}" >> ${sample_id}_tmp.tab
    echo "${metaphlan_out_taxa}" >> ${sample_id}_tmp.tab
    echo "${metaphlan_out_purity}" >> ${sample_id}_tmp.tab
    echo "${rmlst_out_taxa}" >> ${sample_id}_tmp.tab
    echo "${rmlst_out_best_rST}" >> ${sample_id}_tmp.tab
    echo "${rmlst_out_alleles_missing}" >> ${sample_id}_tmp.tab
    echo "${gtdb_out_species}" >> ${sample_id}_tmp.tab
    echo "${gtdb_out_ani_ref}" >> ${sample_id}_tmp.tab
    echo "${gtdb_out_ani_ani}" >> ${sample_id}_tmp.tab
    echo "${gtdb_out_ani_af}" >> ${sample_id}_tmp.tab
    echo "${gtdb_out_placement_ref}" >> ${sample_id}_tmp.tab
    echo "${gtdb_out_gtdb_notes}" >> ${sample_id}_tmp.tab
    echo "${qc_size_warning}" >> ${sample_id}_tmp.tab
    echo "${params.run_id}" >> ${sample_id}_tmp.tab

    # Replace newline with tabs
    cat ${sample_id}_tmp.tab | tr "\\n" "\\t" > ${sample_id}.tab

    """
}



process merge_summaries {
    publishDir("${params.run_id}_transfer_result", mode: 'copy')
    tag { "${params.run_id}" }
    // execute on the main node (no special software needed so no need to submit a job and use a container)

    input:
    path (sample_quality)

    output:
    path ("${params.run_id}_quality.*"), emit: quality

    script:
    """
    #!/bin/bash

    echo -e "Sample\\tinitial_species\\tRead_quality\\tPassed_reads\\tRead_depth\\tAlternative_bases\\tInsert_size\\tContig_count\\tTotal_length\\tN50\\tGC_percent\\tComplete_BUSCOs\\tBUSCO_groups_searched\\tBUSCO_Lineage\\t16S_species\\tAlignment_length\\tAlignment_identity\\tMetaPhlAn4_species\\tMetaPhlAn4_purity\\trMLST_best_species\\trMLST_best_rST\\tAlleles_missing\\tgtdb_species\\tgtdb_fastani_reference\\tgtdb_fastani_ani\\tgtdb_fastani_af\\tgtdb_closest_placement_reference\\tgtdbdb_warnings\\tQC_Warnings\\trun_id" > quality_temp.tab
    for sample in ${sample_quality}; do cat \$sample >> quality_temp.tab; printf "\n" >> quality_temp.tab; done
    (head -n 1 quality_temp.tab && tail -n +2 quality_temp.tab | sort) > ${params.run_id}_quality.tsv
    let sample_count=\$(grep -c "" ${params.run_id}_quality.tsv)-1
    echo "analysed_samples: \$sample_count" >> ${params.run_id}_quality.tsv

    sed 's/,/;/' ${params.run_id}_quality.tsv | sed 's/\t/,/g' > ${params.run_id}_quality.csv
    """
}
