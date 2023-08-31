/*
* gtdbtk module
*/

params.CONTAINER = "mleemann-usbacto-gtdbtk_2.1.0_with_ps"
params.OUTPUT = "gtdb_output"

process gtdbtk_classify_wf {
  publishDir("assembly/results/${sample_id}/3_quality/GTDB", mode: 'copy')
  tag { sample_id }
  container params.CONTAINER
  containerOptions "-B ${params.gtdb_db}"

  input:
  tuple val (sample_id), path (fasta)

  output:
  tuple val (sample_id), path ("${sample_id}/*.summary.tsv"), emit: summary
  tuple val (sample_id), path ("${sample_id}/*.log")
  path "gtdb_version.txt", emit: version

  script:
  """
  export GTDBTK_DATA_PATH=/scicore/home/egliadr/GROUP/Software/databases/gtdbtk_r207_v2_data

  gtdbtk classify_wf --genome_dir . --out_dir ${sample_id} --prefix ${sample_id} --cpus ${task.cpus}

  echo \$(basename ${params.gtdb_db}) > db_version_gtdb.txt
  echo ${params.CONTAINER} > gtdb_singularity.txt
  gtdbtk -v | cut -d\\  -f1-3 >> gtdb_vers.txt
  cat gtdb_vers.txt gtdb_singularity.txt db_version_gtdb.txt | tr "\n" "\t" > gtdb_version.txt
  """
}
