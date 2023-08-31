/*
*  bcl2fastq module
*/

params.CONTAINER = "jlboat-BioinfoContainers_bcl2fastq"   // shub://jlboat/BioinfoContainers:bcl2fastq
params.OUTPUT = "bcl2fastq_output"

process bcl2fastq {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("demultiplexing", mode: 'copy', pattern: "result/**")
    tag { "${params.run_id}" }
    container params.CONTAINER

    input:
    path (rundir)
    path (samplesheet)

    output:
    path ("result/**fastq.gz"), emit: raw_fastq
    path ("reads/*/*fastq.gz"), emit: fastq
    path "result/SampleSheet.*"
    path "result/Stats"
    path "result/Reports", emit: reports
    path "bcl2fastq_version.txt", emit: version

    script:
    """
    bcl2fastq --no-lane-splitting -p ${task.cpus}  -R "${rundir}" \\
    -o result --sample-sheet "${samplesheet}" \\
    2> SampleSheet.err > SampleSheet.out

    mv SampleSheet.err SampleSheet.out result/

    mkdir reads
    shopt -s extglob
    cp -r result/!(Undetermined*) reads/
    shopt -u extglob

    for sample in reads/*/*R1*.fastq.gz; do mv \$sample \${sample/_*.fastq.gz/_R1.fastq.gz}; done
    for sample in reads/*/*.fastq.gz; do if [[ "\$sample" == *R2* ]]; then mv \$sample \${sample/_*.fastq.gz/_R2.fastq.gz}; fi; done

    bcl2fastq --version &> bcl2fastq_info.txt
    cat bcl2fastq_info.txt | grep bcl2fastq > bcl2fastq_vers.txt
    echo ${params.CONTAINER} > bcl2fastq_singularity.txt
    cat bcl2fastq_vers.txt bcl2fastq_singularity.txt | tr "\n" "\t" > bcl2fastq_version.txt
    """
}
