/*
*  7 gene MLST module
*/

//params.CONTAINER = "quay.io/biocontainers/mlst:2.22.0--hdfd78af_0"

process mlst {
    publishDir("${params.output_dir_sample}/${sample_id}/5_typing/mlst", mode: 'copy')
    tag { sample_id }

    input:
    tuple val (sample_id), path (fasta)

    output:
    tuple val (sample_id), path ("mlst_output_${sample_id}.tsv"), emit: mlst_output
    path "mlst_version.txt", emit: version

    script:
    """
    #!/bin/bash

    mlst ${fasta} > mlst_output_${sample_id}.tsv
    mlst --version > mlst_version.txt
    """
}