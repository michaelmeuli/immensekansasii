/*
*  python functions
*/

params.OUTPUT = ""

process make_one_contig {
    publishDir("${params.output_dir_sample}/${sample_id}/3_quality/remapping", mode: 'copy')
    tag { fasta }

    input:
    tuple val (sample_id), path (fasta)

    output:
    tuple val (sample_id), path ("${sample_id}_concatenated_contigs.fna"), emit: one_contig

    script:
    """
    make_one_contig_updated_P3.py ${fasta} ${sample_id} \
    > ${sample_id}_concatenated_contigs.fna
    """
}