/*
* AMRfinderplus module
*/



process amrfinderplus {
  publishDir("${params.output_dir_sample}/${sample_id}/4_resistance_virulence/02_AMRfinderplus", mode: 'copy')
  containerOptions "-B ${params.amrfinderplus_db}"
  tag { sample_id }
  
  input:
  tuple val (sample_id), path (fasta)
  path amrfinderplus_database

  output:
  path("${sample_id}.tsv")          , emit: report
  path("${sample_id}-mutations.tsv"), emit: mutation_report, optional: true
  path "amrfinder_version_all.txt", emit: version

  script:
  """
  # Run AMRfinderplus
  
  amrfinder \\
        --nucleotide ${fasta} \\
        --plus \\
        --database ${params.amrfinderplus_db} \\
        --threads $task.cpus > ${sample_id}.tsv

  amrfinder --version > amrfinder_version.txt
  amrfinder --database_version --database ${params.amrfinderplus_db} | grep "Database version" > db_version.txt
  echo ${task.container} > amrfinder_singularity.txt

  cat amrfinder_version.txt db_version.txt amrfinder_singularity.txt  | tr "\\n" "\\t" > amrfinder_version_all.txt
  """
}
