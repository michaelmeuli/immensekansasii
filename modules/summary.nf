/*
*  summary module
*/

params.OUTPUT = "summary"

process summary_sample {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("assembly/results/${sample_id}/3_quality/summary", mode: 'copy')
    tag { sample_id }
    containerOptions "-B ${params.input}"

    input:
    tuple val (sample_id), path (trim_log), path (coverage), path (insertions), path (quast_tsv), path (blast16S), path (metaphlan), path (rmlst), path (busco), path (gtdbtk)

    output:
    path ("*.txt"), emit: summary_files
    path ("${sample_id}.tab"), emit: sample_quality

    script:

    """
    #!/bin/bash
    awk '/Input Read/{print \$6,\$7,\$8}' ${trim_log} | awk -F '%'  '{print \$1}' | awk -F '('  '{print \$2}' > ${sample_id}_1.txt
    awk '/read_depth/{print \$3}' ${coverage} | sort -n  | awk ' { a[i++]=\$1; } END { print a[int(i/2)]; }' > ${sample_id}_2.txt
    grep -c alternative_base ${coverage} > ${sample_id}_3.txt
    grep -v Insert_size ${insertions} | sort -n  | awk ' { a[i++]=\$1; } END { print a[int(i/2)]; }' > ${sample_id}_4.txt
    tail -n 1 ${quast_tsv} | awk '{print \$14 "\\t" \$16  "\\t" \$18  "\\t" \$17 }' > ${sample_id}_5.txt
    grep "C:" ${busco} | sed 's/,D/;D/g' | tr "," "\t" | cut -f2,5 > ${sample_id}_6.txt
    head -n 1 ${blast16S} | awk -F "\\t" '{print \$3 "\\t" \$6  "\\t" \$7}' > ${sample_id}_7.txt
    grep "s__" ${metaphlan}  | grep -v "t__" | awk '{split(\$0,a,"|"); print a[7],"\\t",\$3}'| awk -F __ '{print \$2}' | cut -f1,3 | head -n 1 > ${sample_id}_8.txt
    cat ${rmlst} > ${sample_id}_9.txt
    cat ${gtdbtk} | tail -1 | cut -f2,3,6-8,20 | awk 'BEGIN{FS=OFS="__"} { if (NF > 1) \$1=\$8; else \$1=\$1; print \$1}' > ${sample_id}_10.txt
    if [[ -d $PWD/reads ]]; then find $PWD/reads -name ${sample_id}*.fastq.gz | awk -F/ '{print \$(NF-1)}' | uniq > ${sample_id}_11.txt; else find ${params.input} -name ${sample_id}*.fastq.gz | awk -F/ '{print \$(NF-1)}' | uniq > ${sample_id}_11.txt; fi

    if [[ ! -s ${sample_id}_1.txt ]]; then echo -e "NA" >> "${sample_id}_1.txt"; fi
    if [[ ! -s ${sample_id}_2.txt ]]; then echo -e "NA" >> "${sample_id}_2.txt"; fi
    if [[ ! -s ${sample_id}_3.txt ]]; then echo -e "NA" >> "${sample_id}_3.txt"; fi
    if [[ ! -s ${sample_id}_4.txt ]]; then echo -e "NA" >> "${sample_id}_4.txt"; fi
    if [[ ! -s ${sample_id}_5.txt ]]; then echo -e "NA\\tNA\\tNA\\tNA" >> "${sample_id}_5.txt"; fi
    if [[ ! -s ${sample_id}_6.txt ]]; then echo -e "NA\\tNA" >> "${sample_id}_6.txt"; fi
    if [[ ! -s ${sample_id}_7.txt ]]; then echo -e "NA\\tNA" >> "${sample_id}_7.txt"; fi
    if [[ ! -s ${sample_id}_8.txt ]]; then echo -e "NA\\tNA" >> "${sample_id}_8.txt"; fi
    if [[ ! -s ${sample_id}_9.txt ]]; then echo -e "NA\\tNA\\tNA" >> "${sample_id}_9.txt"; fi
    if [[ ! -s ${sample_id}_10.txt ]]; then echo -e "NA\\tNA\\tNA\\tNA\\tNA\\tNA" >> "${sample_id}_10.txt"; fi

    cat <(echo ${sample_id}) ${sample_id}_11.txt ${sample_id}_?.txt ${sample_id}_10.txt <(echo ${params.run_id}) | tr "\n" "\t" > ${sample_id}.tab
    """
}


process merge_summaries {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("${params.run_id}_transfer_result", mode: 'copy')
    tag { "${params.run_id}" }

    input:
    path (sample_quality)

    output:
    path ("${params.run_id}_quality.*"), emit: quality

    script:
    """
    #!/bin/bash

    echo -e "Sample\\tinitial_species\\tRead_quality\\tRead_depth\\tAlternative_bases\\tInsert_size\\tContig_count\\tTotal_length\\tN50\\tGC_percent\\tComplete_BUSCOs\\tBUSCO_groups_searched\\t16S_species\\tAlignment_length\\tAlignment_identity\\tMetaPhlAn4_species\\tMetaPhlAn4_purity\\trMLST_best_species\\trMLST_best_rST\\tAlleles_missing\\tgtdb_species\\tgtdb_fastani_reference\\tgtdb_fastani_ani\\tgtdb_fastani_af\\tgtdb_closest_placement_reference\\tgtdbdb_warnings\\trun_id" > quality_temp.tab
    for sample in ${sample_quality}; do cat \$sample >> quality_temp.tab; printf "\n" >> quality_temp.tab; done
    (head -n 1 quality_temp.tab && tail -n +2 quality_temp.tab | sort) > ${params.run_id}_quality.tab
    let sample_count=\$(grep -c "" ${params.run_id}_quality.tab)-1
    echo "analysed_samples: \$sample_count" >> ${params.run_id}_quality.tab

    sed 's/,/;/' ${params.run_id}_quality.tab | sed 's/\t/,/g' > ${params.run_id}_quality.csv
    """
}
