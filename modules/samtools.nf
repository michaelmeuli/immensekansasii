/*
*  samtools module
*/

//params.CONTAINER = "quay.io/biocontainers/samtools:1.19.2--h50ea8bc_1"

params.OUTPUT = ""

process samtools {
    tag { sample_id }

    input:
    tuple val (sample_id), path(sam)

    output:
    tuple val (sample_id), path("*.removed_duplicates.bam"), emit: bam
    tuple val (sample_id), path("*.removed_duplicates.bam.bai"), emit: bai
    path "samtools_version.txt", emit: version

    script:
    """
    samtools sort -@ ${task.cpus} -T ${sample_id} -o ${sample_id}_alingnment.bam ${sam}
    # samtools rmdup was retired and should be replaced
    # samtools rmdup ${sample_id}_alingnment.bam ${sample_id}_alingnment.removed_duplicates.bam
    # Sort by name
    samtools sort -n -@ ${task.cpus} -o ${sample_id}_alingnment_sorted.bam ${sample_id}_alingnment.bam
    # Fix paired reads
    samtools fixmate -m -@ ${task.cpus} ${sample_id}_alingnment_sorted.bam ${sample_id}_alingnment_fixed.bam
    # Sort by coordinate again as expected by markdup
    samtools sort -@ ${task.cpus} -o ${sample_id}_alingnment_fixed_coord.bam ${sample_id}_alingnment_fixed.bam
    # Remove duplicates
    samtools markdup -r -@ ${task.cpus} ${sample_id}_alingnment_fixed_coord.bam ${sample_id}_alingnment.removed_duplicates.bam
    # Index the bam file for pilon
    samtools index -@ ${task.cpus} ${sample_id}_alingnment.removed_duplicates.bam

    samtools --version | head -1 > samtools_vers.txt
    echo ${task.container} > samtools_singularity.txt
    cat samtools_vers.txt samtools_singularity.txt | tr "\\n" "\\t" > samtools_version.txt
    """
}
