/*
*  bcl2fastq module
*/

// Make sure this container is installed
//params.CONTAINER = "quay.io/biocontainers/bcl2fastq-nextseq:1.3.0--pyh5e36f6f_0" // bioconda version but not compatible with current code

params.OUTPUT = "bcl2fastq_output"

process bcl2fastq {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("demultiplexing", mode: 'copy', pattern: "reads/**")
    tag { "${params.run_id}" }

    input:
    path (rundir)
    path (samplesheet)

    output:
    path ("reads/*/*fastq.gz"), emit: fastq
    path "reads/SampleSheet.*"
    path "reads/Stats", emit: reports
    path "reads/Reports"
    path "bcl2fastq_version.txt", emit: version
    path "bcl2fastq_version.txt", emit: finished

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

    #TODO: Handle the situation when no sample project is given in samplesheet
    # If the fastq.gz files are directly in reads folder then no sample_project was specified
    # Move them all to a directory names `no_project`:
    #if ls reads/*.fastq.gz 1> /dev/null 2>&1; then
    #    # If .fastq.gz files are found, then move them to 'no_project' directory
    #    mkdir reads/No_Project
    #    mv reads/*.fastq.gz reads/No_Project/
    #fi
    
    # Rename the fastq.gz files to remove the unnecessary illumina ending
    for sample in reads/*/*R1*.fastq.gz; do mv \$sample \${sample/_*.fastq.gz/_R1.fastq.gz}; done
    for sample in reads/*/*.fastq.gz; do if [[ "\$sample" == *R2* ]]; then mv \$sample \${sample/_*.fastq.gz/_R2.fastq.gz}; fi; done

    # Remove the result folder because its not needed, everything is in `reads`
    rm -R result

    bcl2fastq --version &> bcl2fastq_info.txt
    cat bcl2fastq_info.txt | grep bcl2fastq > bcl2fastq_vers.txt
    echo ${task.container} > bcl2fastq_singularity.txt
    cat bcl2fastq_vers.txt bcl2fastq_singularity.txt | tr "\\n" "\\t" > bcl2fastq_version.txt
    """
}
