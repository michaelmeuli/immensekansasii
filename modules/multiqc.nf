/*
*  multiqc module
*/

//params.CONTAINER = "quay.io/biocontainers/multiqc:1.11--pyhdfd78af_0"
//params.CONTAINER = "https://depot.galaxyproject.org/singularity/multiqc:1.11--pyhdfd78af_0"
params.OUTPUT = "multiqc_output"


process multiqc_bcl {
    // multiQC report of the bcl2fastq process
    publishDir("demultiplexing/multiqc", mode: 'copy')
    publishDir("${params.output_dir_run}", pattern: '*_multiqc_bcl.html', mode: 'copy')
    tag { "${params.run_id}" }
    

    input:
    path (reports)

    output:
    path "${params.run_id}_multiqc_bcl.html", emit: multiqc_bcl_report
    path "${params.run_id}_multiqc_bcl_data/*"
    path "${params.run_id}_multiqc_bcl_data/multiqc_version.txt", emit: version

    script:
    """
    multiqc ${reports} -n ${params.run_id}_multiqc_bcl

    multiqc --version > multiqc_vers.txt
    echo ${task.container} > multiqc_singularity.txt
    cat multiqc_vers.txt multiqc_singularity.txt | tr "\\n" "\\t" > ${params.run_id}_multiqc_bcl_data/multiqc_version.txt
    """
}


process multiqc_raw_fastqc {
    // multiQC report of the raw fastq files
    publishDir("${params.output_dir_run}/00_QC/00_fastqc_raw_reads", mode: 'copy')
    publishDir("${params.output_dir_run}/00_QC", pattern: '*_multiqc_fastq.html', mode: 'copy')
    tag { "${params.run_id}" }
    

    input:
    path (fastqcs)
    

    output:
    path "${params.run_id}_multiqc_fastq.html", emit: multiqc_report
    path "${params.run_id}_multiqc_fastq_data/*"
    path "${params.run_id}_multiqc_fastq_data/multiqc_version.txt", emit: version

    script:
    """
    multiqc -m fastqc ${fastqcs} -n ${params.run_id}_multiqc_fastq

    multiqc --version > multiqc_vers.txt
    echo ${task.container} > multiqc_singularity.txt
    cat multiqc_vers.txt multiqc_singularity.txt | tr "\\n" "\\t" > ${params.run_id}_multiqc_fastq_data/multiqc_version.txt
    """
}

process multiqc_trimmed_fastqc {
    // multiQC report of the trimmed fastq files
    publishDir("${params.output_dir_run}/00_QC/01_fastqc_after_trimming", mode: 'copy')
    publishDir("${params.output_dir_run}/00_QC", pattern: '*_multiqc_trimmed.html', mode: 'copy')
    tag { "${params.run_id}" }
    

    input:
    path (fastqcs)
    path (trim_logs) // Trim logs will be added to the multiqc of fastqc after trimming

    output:
    path "${params.run_id}_multiqc_trimmed.html", emit: multiqc_report
    path "${params.run_id}_multiqc_trimmed_data/*"
    path "${params.run_id}_multiqc_trimmed_data/multiqc_version.txt", emit: version

    script:
    """
    multiqc -m fastqc -m trimmomatic ${fastqcs} ${trim_logs} -n ${params.run_id}_multiqc_trimmed

    multiqc --version > multiqc_vers.txt
    echo ${task.container} > multiqc_singularity.txt
    cat multiqc_vers.txt multiqc_singularity.txt | tr "\\n" "\\t" > ${params.run_id}_multiqc_trimmed_data/multiqc_version.txt
    """
}

process multiqc_assembly {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("${params.output_dir_run}/00_QC/02_multiqc_assembly", mode: 'copy')
    publishDir("${params.output_dir_run}", pattern: '*_multiqc_assembly.html', mode: 'copy')
    tag { "${params.run_id}" }
    

    input:
    path (quast_stats)
    path (bakta_output)
    path (busco_summaries)
    path (metaphlan_profile)

    output:
    path "${params.run_id}_multiqc_assembly.html", emit: multiqc_report
    path "${params.run_id}_multiqc_assembly_data/*"
    path "${params.run_id}_multiqc_assembly_data/multiqc_version.txt", emit: version

    script:
    """
    # Put all metaphlan results into a subdirectory and remove the _profiled_metagenome part of name so that multiqc recognizes the sample names
    mkdir metaphlan
    for metaphlan_file in *_profiled_metagenome.txt; do
        # Check if the file is a symlink
        # Extract the new filename by removing "_profiled_metagenome" part
        new_name=\$(echo "\$metaphlan_file" | sed 's/_profiled_metagenome//')
        
        # Move the symlink to the subdirectory with the new name
        mv "\$metaphlan_file" "metaphlan/\$new_name"
    done
    
    multiqc . -n ${params.run_id}_multiqc_assembly

    multiqc --version > multiqc_vers.txt
    echo ${task.container} > multiqc_singularity.txt
    cat multiqc_vers.txt multiqc_singularity.txt | tr "\\n" "\\t" > ${params.run_id}_multiqc_assembly_data/multiqc_version.txt
    """
}
