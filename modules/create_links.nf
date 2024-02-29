/*
* create_links module
*/


process link_reads {

  tag { "${params.run_id}" }
  containerOptions "-B ${params.input}, -B $launchDir"

  input:
  path (demultiplex_ok)

  output:

  script:
  """
  #!/bin/bash

  shopt -s extglob

  mkdir -p $PWD/reads/_raw_reads
  ln -s $PWD/demultiplexing/result/* $PWD/reads/_raw_reads

  for dir in `ls -d $PWD/demultiplexing/result/!(Reports|Stats)/`
  do
      mkdir -p $PWD/reads/\$(basename \$dir) $PWD/${params.run_id}_transfer_result/reads/\$(basename \$dir)
      for sample in $PWD/demultiplexing/result/\$(basename \$dir)/*.fastq.gz; do ln -s \$sample $PWD/reads/\$(basename \$dir)/; done
      cd $PWD/reads/\$(basename \$dir)
      for sample in ./*R1*.fastq.gz; do mv \$sample \${sample/_*.fastq.gz/_R1.fastq.gz}; done
      for sample in ./*.fastq.gz; do if [[ "\$sample" == *R2* ]]; then mv \$sample \${sample/_*.fastq.gz/_R2.fastq.gz}; fi; done
  done

  if [[ -d $PWD/reads/sarscov-2 ]]; then ln -s $PWD/reads/sarscov-2/*.fastq.gz $PWD/${params.run_id}_transfer_result/reads/sarscov-2/; fi

  shopt -u extglob
  """
}


process links_for_transfer {

  tag { sample_id }
  containerOptions "-B ${params.input}, -B $launchDir"

  input:
  tuple val (sample_id), path (one_contig)

  output:

  script:
  """
  #!/bin/bash

  species=\$(find ${params.input} -name ${sample_id}*.fastq.gz | awk -F/ '{print \$(NF-1)}' | uniq)
  mkdir -p $PWD/${params.run_id}_transfer_result/genomes/\$species $PWD/${params.run_id}_transfer_result/genomes_one_contig/\$species $PWD/${params.run_id}_transfer_result/reads/\$species
  ln -sf $PWD/assembly/results/${sample_id}/2_annotation/${sample_id}.fna $PWD/${params.run_id}_transfer_result/genomes/\$species/
  ln -sf $PWD/assembly/results/${sample_id}/3_quality/remapping/${sample_id}_concatenated_contigs.fna $PWD/${params.run_id}_transfer_result/genomes_one_contig/\$species/
  if [[ ${params.input_type} != "fasta" ]]; then if [[ -d $PWD/reads ]]; then ln -sf $PWD/reads/\$species/${sample_id}* $PWD/${params.run_id}_transfer_result/reads/\$species/; else ln -sf ${params.input}/**${sample_id}* $PWD/${params.run_id}_transfer_result/reads/\$species/; fi; fi
  """
}
