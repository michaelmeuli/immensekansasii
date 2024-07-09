/*
*  Bakta module
*/

process bakta {
    publishDir("${params.output_dir_sample}/${sample_id}", pattern: "2_annotation/*", mode: 'copy')
    tag { sample_id }
    containerOptions "-B ${params.bakta_db}"

    input:
    tuple val (sample_id), path (fasta)

    output:
    tuple val(sample_id), path ("2_annotation/${sample_id}.fna"), emit: fna
    path ("2_annotation/*"), emit: annot_all
    path "bakta_version_all.txt", emit: version

    script:
    """
    # Troubleshooting:
    ls -lh
    
    echo "Running bakta on: ${fasta}"

    bakta \\
        --db ${params.bakta_db} \\
        --threads ${task.cpus} \\
        --prefix ${sample_id} \\
        --output 2_annotation \\
        --strain ${sample_id} \\
        ${fasta}
    
    bakta --version > bakta_version.txt 2>&1
    
    DB_VERSION=`cat ${params.bakta_db}/version.json | grep "doi" | awk -F '"' '{print \$4}'`
    DB_DATE=`cat ${params.bakta_db}/version.json | grep "date" | awk -F '"' '{print \$4}'`
    echo "Database DOI: \${DB_VERSION} Date: \${DB_DATE}" > database_version.txt
    echo ${task.container} > bakta_singularity.txt
    cat bakta_version.txt database_version.txt bakta_singularity.txt | tr "\\n" "\\t" > bakta_version_all.txt
    """
}
