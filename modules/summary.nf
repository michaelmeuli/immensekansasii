/*
*  summary module
*/

params.OUTPUT = "summary"

process summary_sample {
    publishDir("${params.output_dir_sample}/${sample_id}/3_quality/summary", mode: 'copy')
    // execute on the main node (no special software needed so no need to submit a job and use a container)
    tag { sample_id }
    
    input:
    tuple val (sample_id), \
            val (expected_species), \
            val (trimm_out_passed_reads_percentage), \
            val (trimm_out_passed_reads_number), \
            val (coverage_read_depth), \
            val (coverage_read_mean), \
            val (coverage_read_sd), \
            val (coverage_alt_bases), \
            val (insertsize_insert_size),  \
            val (assembly_stats_number_contigs), \
            val (assembly_stats_total_length), \
            val (assembly_stats_n50), \
            val (assembly_stats_gc_percent), \
            val (typ16S_taxa), \
            val (typ16S_aln_length), \
            val (typ16S_aln_identity), \
            val (metaphlan_out_taxa),  \
            val (metaphlan_out_purity), \
            val (rmlst_out_taxa), \
            val (rmlst_out_best_rST), \
            val (rmlst_out_alleles_missing), \
            val (busco_out_complete_busco), \
            val (busco_out_busco_lineage), \
            val (checkm_completeness), \
            val (checkm_contamination), \
            val (checkm_heterogeneity),\
            val (mlst_out_sequence_type), \
            val (mlst_out_alleles), \
            val (gtdb_out_species), \
            val (gtdb_out_ani_ref), \
            val (gtdb_out_ani_ani), \
            val (gtdb_out_ani_af), \
            val (gtdb_out_placement_ref), \
            val (gtdb_out_gtdb_notes), \
            val (qc_size_warning)

    output:
    path ("${sample_id}.tab"), emit: sample_quality

    script:

    """
    #!/bin/bash
    
    # Writing the variables passed as input to the sample specific file
    # These sample-specific summaries are then merged in the merge_summaries process
    echo -e "Sample\\tinitial_species\\tRead_quality\\tPassed_reads\\tRead_depth_median\\tDepth_mean\\tDepth_SD\\tAlternative_bases\\tInsert_size\\tContig_count\\tTotal_length\\tN50\\tGC_percent\\tComplete_BUSCOs\\tBUSCO_Lineage\\tcheckm_completeness\\tcheckm_contamination\\tcheckm_heterogeneity\\tMetaPhlAn4_species\\tMetaPhlAn4_purity\\tgtdb_species\\tgtdb_fastani_reference\\tgtdb_fastani_ani\\tgtdb_fastani_af\\tgtdb_closest_placement_reference\\tgtdbdb_warnings\\trMLST_best_species\\trMLST_best_rST\\tAlleles_missing\\t16S_species\\tAlignment_length\\tAlignment_identity\\tMLST_sequence_type\\tMLST_alleles\\tWorkflow_Notes\\trun_id" > ${sample_id}_tmp.tab
    echo "${sample_id}" >> ${sample_id}_tmp.tab
    # This is an environmental variable in this script, not an input like the others
    echo "${expected_species}" >> ${sample_id}_tmp.tab
    echo "${trimm_out_passed_reads_percentage}" >> ${sample_id}_tmp.tab
    echo "${trimm_out_passed_reads_number}" >> ${sample_id}_tmp.tab
    echo "${coverage_read_depth}" >> ${sample_id}_tmp.tab
    echo "${coverage_read_mean}" >> ${sample_id}_tmp.tab
    echo "${coverage_read_sd}" >> ${sample_id}_tmp.tab
    echo "${coverage_alt_bases}" >> ${sample_id}_tmp.tab
    echo "${insertsize_insert_size}" >> ${sample_id}_tmp.tab
    echo "${assembly_stats_number_contigs}" >> ${sample_id}_tmp.tab
    echo "${assembly_stats_total_length}" >> ${sample_id}_tmp.tab
    echo "${assembly_stats_n50}" >> ${sample_id}_tmp.tab
    echo "${assembly_stats_gc_percent}" >> ${sample_id}_tmp.tab
    
    echo "${busco_out_complete_busco}" >> ${sample_id}_tmp.tab
    echo "${busco_out_busco_lineage}" >> ${sample_id}_tmp.tab
    
    echo "${checkm_completeness}" >> ${sample_id}_tmp.tab
    echo "${checkm_contamination}" >> ${sample_id}_tmp.tab
    echo "${checkm_heterogeneity}" >> ${sample_id}_tmp.tab

    echo "${metaphlan_out_taxa}" >> ${sample_id}_tmp.tab
    echo "${metaphlan_out_purity}" >> ${sample_id}_tmp.tab

    echo "${gtdb_out_species}" >> ${sample_id}_tmp.tab
    echo "${gtdb_out_ani_ref}" >> ${sample_id}_tmp.tab
    echo "${gtdb_out_ani_ani}" >> ${sample_id}_tmp.tab
    echo "${gtdb_out_ani_af}" >> ${sample_id}_tmp.tab
    echo "${gtdb_out_placement_ref}" >> ${sample_id}_tmp.tab
    echo "${gtdb_out_gtdb_notes}" >> ${sample_id}_tmp.tab
    
    echo "${rmlst_out_taxa}" >> ${sample_id}_tmp.tab
    echo "${rmlst_out_best_rST}" >> ${sample_id}_tmp.tab
    echo "${rmlst_out_alleles_missing}" >> ${sample_id}_tmp.tab

    echo "${typ16S_taxa}" >> ${sample_id}_tmp.tab
    echo "${typ16S_aln_length}" >> ${sample_id}_tmp.tab
    echo "${typ16S_aln_identity}" >> ${sample_id}_tmp.tab

    echo "${mlst_out_sequence_type}" >> ${sample_id}_tmp.tab
    echo "${mlst_out_alleles}" >> ${sample_id}_tmp.tab
    
    echo "${qc_size_warning}" >> ${sample_id}_tmp.tab
    echo "${params.run_id}" >> ${sample_id}_tmp.tab

    # Replace newline with tabs
    {
  head -n1 ${sample_id}_tmp.tab
  tail -n +2 ${sample_id}_tmp.tab | paste -sd '\t'
    } > ${sample_id}.tab
    rm ${sample_id}_tmp.tab
    """
}

process merge_summaries {
    publishDir("${params.output_dir_run}", mode: 'copy')
    tag { "${params.run_id}" }
    // execute on the main node (no special software needed so no need to submit a job and use a container)
    containerOptions "-B ${params.quality_rules}"

    input:
    path (sample_quality)

    output:
    path ("${params.run_id}_quality*"), emit: quality

    script:
    """
    #!/bin/bash

    # Loop through each sample in the sample_quality input list and append its content to the tab-separated file
    # After adding the content of the sample, a newline is added at the end
    for sample in ${sample_quality}; do cat \$sample >> quality_temp.tab; printf "\n" >> quality_temp.tab; done

    # Remove empty lines and duplicate lines (keeping only the first occurrence) before sorting
    awk 'NF > 0' quality_temp.tab | awk '!seen[\$0]++' > quality_temp_no_duplicates.tab

    # Sort the content of the quality_temp.tab file and write it into the final quality file
    # The first line (header) is kept intact, while the rest is sorted alphabetically and written to the final file
    (head -n 1 quality_temp_no_duplicates.tab && tail -n +2 quality_temp_no_duplicates.tab | sort) > ${params.run_id}_quality.tsv

    # Count the number of samples and subtract 1 (since the header is included)
    let sample_count=\$(grep -c "" ${params.run_id}_quality.tsv)-1

    # Append the number of analyzed samples to the quality file
    echo "analysed_samples: \$sample_count" >> ${params.run_id}_quality.tsv

    # Finally, run the evaluate_QC.py script on the generated quality file, using the rules file
    evaluate_QC.py --qcfile ${params.run_id}_quality.tsv --rulesfile ${params.quality_rules}


    """
}