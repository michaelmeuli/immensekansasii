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
 
  script:
  """
  # Run AMRfinderplus
  
  amrfinder \\
        --nucleotide ${fasta} \\
        --plus \\
        --database ${params.amrfinderplus_db} \\
        --threads $task.cpus > ${sample_id}.tsv

  """
}
