/*
*  tbprofiler module
*/

//params.CONTAINER = "quay.io/biocontainers/tb-profiler:6.3.0--pyhdfd78af_0"

process tbprofiler {
    publishDir("${params.output_dir_sample}/${sample_id}/3_quality/tb-profiler", mode: 'copy')
    tag { sample_id }

    input:
    tuple val (sample_id), path (fastq1), path(fastq2)

    output:
    path "complete_tb-profiler_version.txt", emit: version
    tuple val (sample_id), path ("results/${sample_id}.results.csv"), emit: tbprofiler

    script:
    """
    tb-profiler profile \
    -1 ${fastq1} \
    -2 ${fastq2} \
    -t ${task.cpus} \
    -p ${sample_id} \
    --docx \
    --csv \
    --no_trim

    # rm -r bam/
    # rm -r vcf/

    # Getting Version information
    tb-profiler --version > tb-profiler_vers.txt
    echo ${task.container} > tb-profiler_singularity.txt
    cat tb-profiler_vers.txt tb-profiler_singularity.txt | tr "\\n" "\\t" > complete_tb-profiler_version.txt

    """



}