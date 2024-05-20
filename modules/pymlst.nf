/*
*  pyMLST module
*/

// params.CONTAINER = "quay.io/biocontainers/pymlst:2.1.6--pyhdfd78af_0"
//params.OUTPUT = "pyMLST_output"

process pymlst_add_strain {
    publishDir("${params.output_dir_sample}/${sample_id}/5_typing/pyMLST", mode: 'copy')
    tag { sample_id }
    containerOptions "-B ${params.pymlst_cgmlst_db}"

    input:
    tuple val (sample_id), path (rmlst), path (fasta)

    output:
    tuple val (sample_id), path ("*"), emit: pymlst_all
    path "${sample_id}_pymlst_version.txt", emit: version
    tuple val (sample_id), file ("pymlst_output.tsv"), emit: summary_specific, optional: true
    path "no_cgMLST_found.txt", optional: true
    
    script:
    """
    species=\$(cat ${rmlst} | cut -f 1 | sed 's/_/ /g')
    
    # Check if the database directory exists, otherwise try creating it:
    if [ -d "${params.pymlst_cgmlst_db}" ]; then
        echo "pyMLST database directory exists"
    else
        echo "The pyMLST directory as specifed in parameters does not exist, please create it: ${params.pymlst_cgmlst_db}" >&2
        echo "Trying to create it with: mkdir -p ${params.pymlst_cgmlst_db}"  >&2
        mkdir -p ${params.pymlst_cgmlst_db} # Try creating the directory in case it doesn't exist yet
    fi

    # Check if pyMLST species profiles exists, if not try downloading it:
    if [ -f "${params.pymlst_cgmlst_db}/\$species" ]; then
        echo "\$species cgMLST Database exists, skipping download"
    else
        wgMLST import "${params.pymlst_cgmlst_db}/\$species" \$species || echo "Download failed, Unable to do cgMLST for this species."
    fi

    # If the Species profile doesn't exist now, then this species doesn't have 
    # a cgMLST profile and this analysis is skipped.
    # If it exists, remove the specific strain and add it again.
    if [ -f "${params.pymlst_cgmlst_db}/\$species" ]; then
        wgMLST remove --strains "${params.pymlst_cgmlst_db}/\$species" \$(basename ${fasta})
        wgMLST add "${params.pymlst_cgmlst_db}/\$species" ${fasta} -s \$(basename ${fasta}) -i ${params.pymlst_identity} -c ${params.pymlst_coverage} > pymlst_output.tsv
    else
        echo "cgMLST Profile doesn't exist for \$species"
        echo "No cgMLST Profile found for Species: \$species" > no_cgMLST_found.txt
    fi

    echo "pyMLST" \$(wgMLST -v | grep "Version") > pymlst_vers.txt
    echo ${task.container} > pymlst_singularity.txt
    cat pymlst_vers.txt pymlst_singularity.txt | tr "\\n" "\\t" > ${sample_id}_pymlst_version.txt
    """
}

process pymlst_distance {
    // Multiple processes with the same species will overwrite each other
    // In the end, the latest will have the most genomes in the analysis
    publishDir("${params.output_dir_run}/cgMLST", mode: 'copy')
    tag { sample_id }
    containerOptions "-B ${params.pymlst_cgmlst_db}"

    input:
    tuple val (sample_id), file (pymlst_output), path (rmlst)

    output:
    tuple val (sample_id), path ("*_pymlst_distance.tsv"), emit: pymlst_distance


    script:
    """
    species=\$(cat ${rmlst} | cut -f 1 | sed 's/_/ /g')
    wgMLST distance "${params.pymlst_cgmlst_db}/\$species" > "\${species}_pymlst_distance.tsv"
    """
}

process pymlst_subgraph {
    publishDir("${params.output_dir_run}/cgMLST", mode: 'copy')
    tag { sample_id }
    containerOptions "-B ${params.pymlst_cgmlst_db}"

    input:
    // tuple val (sample_id), path (rmlst)
    // tuple val (sample_id), path (distance)
    tuple val (sample_id), file (pymlst_output), path (rmlst), path (distance)

    output:
    tuple val (sample_id), path ("*_pymlst_subgraph.tsv"), emit: pymlst_subgraph


    script:
    """
    species=\$(cat ${rmlst} | cut -f 1 | sed 's/_/ /g')
    wgMLST subgraph ${distance} -t ${params.pymlst_nb_alleles} -e group -o "\${species}_pymlst_subgraph.tsv"
    """
}
