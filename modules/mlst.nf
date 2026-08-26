/*
*  7 gene MLST module
*/

process mlst {
    publishDir("${params.output_dir_sample}/${sample_id}/5_typing/mlst", mode: 'copy')
    tag { sample_id }

    input:
    tuple val (sample_id), path (fasta)

    output:
    tuple val (sample_id), path ("mlst_output_${sample_id}.tsv"), emit: mlst_output
    tuple val (sample_id), env(ST), emit: sequence_type
    tuple val (sample_id), env(ALLELES), emit: alleles
    path "mlst_version.txt", emit: version

    script:
    """
    #!/bin/bash

    # Run MLST depending on whether params.mlst_db is set
    if [ -z "${params.mlst_db}" ] || [ ! -d "${params.mlst_db}" ]; then
        mlst ${fasta} | \
        awk -F'\t' 'BEGIN { print "File\tSchema\tSequence Type\tAlleles" } {
            file=\$1;
            schema=\$2;
            seq_type=\$3;
            alleles=\$4;
            for(i=5; i<=NF; i++) {
                alleles = alleles ", " \$i;
            }
            print file "\t" schema "\t" seq_type "\t" alleles;
        }' > mlst_output_${sample_id}.tsv
    else
        mlst --blastdb ${params.mlst_db}/blast/mlst.fa --datadir ${params.mlst_db}/pubmlst ${fasta} | \
        awk -F'\t' 'BEGIN { print "File\tSchema\tSequence Type\tAlleles" } {
            file=\$1;
            schema=\$2;
            seq_type=\$3;
            alleles=\$4;
            for(i=5; i<=NF; i++) {
                alleles = alleles ", " \$i;
            }
            print file "\t" schema "\t" seq_type "\t" alleles;
        }' > mlst_output_${sample_id}.tsv
    fi

    # Extract key values
    export ST=`tail -n +2 mlst_output_${sample_id}.tsv | cut -f3`
    export ALLELES=`tail -n +2 mlst_output_${sample_id}.tsv | cut -f4`

    # Version info
    echo ${task.container} > mlst_singularity.txt
    mlst --version > mlst_vers.txt
    paste mlst_vers.txt mlst_singularity.txt > mlst_version.txt
    """
}