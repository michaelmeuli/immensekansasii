/*
* gtdbtk module
*/

//params.CONTAINER = "quay.io/biocontainers/gtdbtk:2.3.2--pyhdfd78af_0"
params.OUTPUT = "gtdb_output"

process gtdbtk_classify_wf {
  publishDir("${params.output_dir_sample}/${sample_id}/3_quality/GTDB", mode: 'copy')
  tag { sample_id }
  
  //containerOptions "-B ${params.gtdb_db}"

  input:
  tuple val (sample_id), path (fasta)
  path gtdb_database

  output:
  tuple val (sample_id), path ("${sample_id}/*.summary.tsv"), emit: summary
  tuple val (sample_id), path ("${sample_id}/*.log")
  path "gtdb_version.txt", emit: version
  tuple val (sample_id), env(SPECIES), emit: species
  tuple val (sample_id), env(ANI_REF), emit: ani_ref
  tuple val (sample_id), env(ANI), emit: ani_ani
  tuple val (sample_id), env(AF), emit: ani_af
  tuple val (sample_id), env(PLACEMENT_REF), emit: placement_ref
  tuple val (sample_id), env(GTDB_NOTES), emit: gtdb_notes

  script:
  """
  export GTDBTK_DATA_PATH=${gtdb_database}

  gtdbtk classify_wf --genome_dir . --out_dir ${sample_id} --prefix ${sample_id} --cpus ${task.cpus} --skip_ani_screen

  # Collecting Versions
  echo \$(basename ${gtdb_database}) > db_version_gtdb.txt
  echo ${task.container} > gtdb_singularity.txt
  gtdbtk -v | cut -d\\  -f1-3 >> gtdb_vers.txt
  cat gtdb_vers.txt gtdb_singularity.txt db_version_gtdb.txt | tr "\\n" "\\t" > gtdb_version.txt

  # Extracting key information for summary quality.csv
  SPECIES=`cat ${sample_id}/*.summary.tsv | tail -1 | cut -f2,3,6-8,20 | awk 'BEGIN{FS=OFS="__"} { if (NF > 1) \$1=\$8; else \$1=\$1; print \$1}' | cut -f1`
  ANI_REF=`cat ${sample_id}/*.summary.tsv | tail -1 | cut -f2,3,6-8,20 | awk 'BEGIN{FS=OFS="__"} { if (NF > 1) \$1=\$8; else \$1=\$1; print \$1}' | cut -f2`
  ANI=`cat ${sample_id}/*.summary.tsv | tail -1 | cut -f2,3,6-8,20 | awk 'BEGIN{FS=OFS="__"} { if (NF > 1) \$1=\$8; else \$1=\$1; print \$1}' | cut -f3`
  AF=`cat ${sample_id}/*.summary.tsv | tail -1 | cut -f2,3,6-8,20 | awk 'BEGIN{FS=OFS="__"} { if (NF > 1) \$1=\$8; else \$1=\$1; print \$1}' | cut -f4`
  PLACEMENT_REF=`cat ${sample_id}/*.summary.tsv | tail -1 | cut -f2,3,6-8,20 | awk 'BEGIN{FS=OFS="__"} { if (NF > 1) \$1=\$8; else \$1=\$1; print \$1}' | cut -f5`
  GTDB_NOTES=`cat ${sample_id}/*.summary.tsv | tail -1 | cut -f2,3,6-8,20 | awk 'BEGIN{FS=OFS="__"} { if (NF > 1) \$1=\$8; else \$1=\$1; print \$1}' | cut -f6`
  """
}
