/*
*  pilon module
*/

//params.CONTAINER = "quay.io/biocontainers/pilon:1.24--hdfd78af_0"
//params.CONTAINER = "https://depot.galaxyproject.org/singularity/pilon:1.24--hdfd78af_0"
params.OUTPUT = ""

process pilon_remapping {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("assembly/results/${sample_id}/3_quality/remapping/pilon", mode: 'copy')
    tag { sample_id }
    

    input:
    tuple val (sample_id), path(bam), path(assembly)

    output:
    tuple val (sample_id), path("${sample_id}.fasta"), emit: assembly
    tuple val (sample_id), path("${sample_id}.vcf"), emit: vcf
    path "pilon_version.txt", emit: version

    script:
    """
    export _JAVA_OPTIONS="-Xmx10g"
    pilon --threads ${task.cpus} --genome ${assembly} --frags ${bam} \
    --changes --vcf --fix snps --outdir ./ --output ${sample_id}

    pilon --version | cut -d\\  -f1-3 > pilon_vers.txt
    echo ${task.container} > pilon_singularity.txt
    cat pilon_vers.txt pilon_singularity.txt | tr "\\n" "\\t" > pilon_version.txt
    """
}


process pilon_remappingSE {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("${params.output_dir_sample}/${sample_id}/3_quality/remapping/pilon", mode: 'copy')
    tag { sample_id }
    

    input:
    tuple val (sample_id), path(bam), path(assembly)

    output:
    tuple val (sample_id), path("${sample_id}.fasta"), emit: assembly
    tuple val (sample_id), path("${sample_id}.vcf"), emit: vcf
    path "pilon_version.txt", emit: version

    script:
    """
    export _JAVA_OPTIONS="-Xmx10g"
    pilon --threads ${task.cpus} --genome ${assembly} --unpaired ${bam} \
    --changes --vcf --fix snps --outdir ./ --output ${sample_id}

    pilon --version | cut -d\\  -f1-3 > pilon_vers.txt
    echo ${task.container} > pilon_singularity.txt
    cat pilon_vers.txt pilon_singularity.txt | tr "\\n" "\\t" > pilon_version.txt
    """
}
