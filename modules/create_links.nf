/*
* create_links module
*/

process link_reads {
  // Move all fastq.gz file into a nicely organized 'reads' directory
  tag { "${params.run_id}" }
  //containerOptions "-B ${params.input}, -B $launchDir"

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
      mkdir -p $PWD/reads/\$(basename \$dir) $PWD/${params.output_dir_run}/reads/\$(basename \$dir)
      for sample in $PWD/demultiplexing/result/\$(basename \$dir)/*.fastq.gz; do ln -s \$sample $PWD/reads/\$(basename \$dir)/; done
      cd $PWD/reads/\$(basename \$dir)
      for sample in ./*R1*.fastq.gz; do mv \$sample \${sample/_*.fastq.gz/_R1.fastq.gz}; done
      for sample in ./*.fastq.gz; do if [[ "\$sample" == *R2* ]]; then mv \$sample \${sample/_*.fastq.gz/_R2.fastq.gz}; fi; done
  done

  if [[ -d $PWD/reads/sarscov-2 ]]; then ln -s $PWD/reads/sarscov-2/*.fastq.gz $PWD/${params.output_dir_run}/reads/sarscov-2/; fi

  shopt -u extglob
  """
}


process links_for_transfer {
  tag { sample_id }
  //containerOptions "-B ${params.input}, -B $launchDir"

  input:
  tuple val (sample_id), path (one_contig)

  output:

  script:
  """
  #!/bin/bash
  # To find species name: search for the input reads, the parent folder of the reads will be the species name
    
  species=\$(find ${params.input_absolutePath} -name ${sample_id}*.fastq.gz | awk -F/ '{print \$(NF-1)}' | uniq)
  mkdir -p $PWD/${params.output_dir_run}/genomes/\$species $PWD/${params.output_dir_run}/reads/\$species
  ln -sf $PWD/assembly/results/${sample_id}/2_annotation/${sample_id}.fna $PWD/${params.output_dir_run}/genomes/\$species/
  if [[ ${params.input_type} != "fasta" ]]; 
	  then if [[ -d $PWD/reads ]]; 
      then ln -sf $PWD/reads/\$species/${sample_id}* $PWD/${params.output_dir_run}/reads/\$species/; 
      else 
        shopt -s globstar; 
        ln -sf ${params.input_absolutePath}/**/*${sample_id}* $PWD/${params.output_dir_run}/reads/\$species/; 
        shopt -u globstar;
    fi; 
  fi
  """
}