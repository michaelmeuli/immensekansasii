
/*
*  Lissero module
*/

process insilicoseq {
    // publishDir("${params.output_dir_sample}/${sample_id}/", mode: 'copy')
    tag { sample_id }

    input:
    tuple val (sample_id), path (fasta)

    output:
    path "complete_insilicoseq_version.txt", emit: version
    // Output the generated fastq files:
    tuple val (sample_id), path ("${sample_id}_R1.fastq.gz"), path ("${sample_id}_R2.fastq.gz"), emit: artificial_reads

    script:
    """
    iss generate -n 200K --draft ${fasta} --model miseq --output ${sample_id}
    gzip *.fastq
    
    # Getting Version information
    iss --version > insilicoseq_vers.txt
    echo ${task.container} > insilicoseq_singularity.txt
    cat insilicoseq_vers.txt insilicoseq_singularity.txt | tr "\\n" "\\t" > complete_insilicoseq_version.txt

    """
}