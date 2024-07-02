/*
* gtdbtk module
*/

//params.CONTAINER = "quay.io/biocontainers/gtdbtk:2.3.2--pyhdfd78af_0"
// For efficiency, multiple genomes are processed at the same time in GTDB and 
// then results are separated per assembly afterwards
process gtdbtk_classify_wf {
  tag { "Batch: ${batch_number}" }
  
  input:
  //tuple val (sample_id), path (fasta)
  tuple val(batch_number), path(assemblies)
  path gtdb_database

  output:
  path("results_per_sample/*.tsv"), emit: summary_files
  path "gtdb_version.txt", emit: version

  script:
  """
  export GTDBTK_DATA_PATH=${gtdb_database}
  
  # For troubleshooting, print all the input filenames
  echo ${assemblies.name}
  
  # Process all input files through gtdbtk at the same time:
  gtdbtk classify_wf --genome_dir . --out_dir gtdbtk_output --prefix gtdbtk_output --cpus ${task.cpus} --skip_ani_screen --extension fasta
  
  # Make logfiles of each batch unique (prevent overwriting)
  mv gtdbtk_output/gtdbtk.log gtdbtk_output/batch${batch_number}_gtdbtk.log
  mv gtdbtk_output/gtdbtk.warnings.log gtdbtk_output/batch${batch_number}_gtdbtk.warnings.log

  # Split the summary output file into 1 file per sample:
  mkdir results_per_sample
  while read -r line
  do
    # Extract the first column as filename and the rest of the line as content
    filename=\$(echo "\${line}" | cut -f1)
    content=\$(echo "\${line}")

    # If it's the header line, save it to a variable
    if [ "\${filename}" == "user_genome" ]; then
        headers="\${line}"
    else
        # Create the file and write the headers and content
        echo -e "\${headers}\n\${content}" > "results_per_sample/\${filename}.tsv"
    fi
  done < gtdbtk_output/*.summary.tsv

  # Get versions information:
  echo \$(basename ${gtdb_database}) > db_version_gtdb.txt
  echo ${task.container} > gtdb_singularity.txt
  gtdbtk -v | cut -d\\  -f1-3 | head -n 1 > gtdb_vers.txt
  cat gtdb_vers.txt gtdb_singularity.txt db_version_gtdb.txt | tr "\\n" "\\t" > gtdb_version.txt

  """
}


// This process will get a GTDB summary file with only 1 sample result and then 
// extract the parameters we are interested in
process extract_gtdb_output {
  publishDir("${params.output_dir_sample}/${sample_id}/3_quality/GTDB", mode: 'copy')
  tag { sample_id }
  
  input:
  tuple val (sample_id), path (gtdb_summary)

  output:
  path("${gtdb_summary}_gtdb_summary.tsv"), emit: gtdb_species_summary
  tuple val(sample_id), env(SPECIES), emit: species
  tuple val(sample_id), env(ANI_REF), emit: ani_ref
  tuple val(sample_id), env(ANI), emit: ani_ani
  tuple val(sample_id), env(AF), emit: ani_af
  tuple val(sample_id), env(PLACEMENT_REF), emit: placement_ref
  tuple val(sample_id), env(GTDB_NOTES), emit: gtdb_notes

  script:

  """
  
  # Extracting key information for summary quality.csv
  SPECIES=`cat ${gtdb_summary} | tail -1 | cut -f2,3,6-8,20 | awk 'BEGIN{FS=OFS="__"} { if (NF > 1) \$1=\$8; else \$1=\$1; print \$1}' | cut -f1`
  ANI_REF=`cat ${gtdb_summary} | tail -1 | cut -f2,3,6-8,20 | awk 'BEGIN{FS=OFS="__"} { if (NF > 1) \$1=\$8; else \$1=\$1; print \$1}' | cut -f2`
  ANI=`cat ${gtdb_summary} | tail -1 | cut -f2,3,6-8,20 | awk 'BEGIN{FS=OFS="__"} { if (NF > 1) \$1=\$8; else \$1=\$1; print \$1}' | cut -f3`
  AF=`cat ${gtdb_summary} | tail -1 | cut -f2,3,6-8,20 | awk 'BEGIN{FS=OFS="__"} { if (NF > 1) \$1=\$8; else \$1=\$1; print \$1}' | cut -f4`
  PLACEMENT_REF=`cat ${gtdb_summary} | tail -1 | cut -f2,3,6-8,20 | awk 'BEGIN{FS=OFS="__"} { if (NF > 1) \$1=\$8; else \$1=\$1; print \$1}' | cut -f5`
  GTDB_NOTES=`cat ${gtdb_summary} | tail -1 | cut -f2,3,6-8,20 | awk 'BEGIN{FS=OFS="__"} { if (NF > 1) \$1=\$8; else \$1=\$1; print \$1}' | cut -f6`

  mv ${gtdb_summary} ${gtdb_summary}_gtdb_summary.tsv
  """
}
