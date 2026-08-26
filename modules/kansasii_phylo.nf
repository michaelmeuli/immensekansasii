/*
* kansasii_phylo module
*
* Reference-based SNP phylogeny for the Mycobacterium kansasii complex.
* GTDB-Tk already resolves species-level identity within the complex via
* ANI, but doesn't give strain-level relatedness. These processes map
* each sample's assembly against a curated, species-specific reference
* with Snippy, accumulate results in a persistent per-species directory
* (mirroring the pyMLST cgMLST pattern), and build a core-SNP tree with
* IQ-TREE across all isolates of that species seen so far (not just this
* run).
*/

process kansasii_snippy {
    publishDir("${params.output_dir_sample}/${sample_id}/5_typing/kansasii_snippy", mode: 'copy')
    tag { sample_id }
    containerOptions "-B ${params.kansasii_ref_dir} -B ${params.kansasii_snippy_db}"

    input:
    tuple val (sample_id), path (assembly), val (species)

    output:
    tuple val (sample_id), val (species), emit: done
    path "snippy_out/*"
    path "${sample_id}_kansasii_snippy_version.txt", emit: version

    script:
    """
    species_key=\$(echo "${species}" | tr ' ' '_')
    ref="${params.kansasii_ref_dir}/\${species_key}.fasta"

    if [ ! -f "\$ref" ]; then
        echo "No curated reference found for \${species_key} at \$ref" >&2
        exit 1
    fi

    snippy --ctgs ${assembly} --ref "\$ref" --outdir snippy_out --cpus ${task.cpus} --force

    # Add/refresh this sample's result in the persistent, species-keyed db
    mkdir -p "${params.kansasii_snippy_db}/\${species_key}"
    rm -rf "${params.kansasii_snippy_db}/\${species_key}/${sample_id}"
    cp -r snippy_out "${params.kansasii_snippy_db}/\${species_key}/${sample_id}"

    snippy --version 2>&1 | head -n 1 > snippy_vers.txt
    echo ${task.container} > snippy_singularity.txt
    cat snippy_vers.txt snippy_singularity.txt | tr "\\n" "\\t" > ${sample_id}_kansasii_snippy_version.txt
    """
}

process kansasii_snippy_core {
    publishDir("${params.output_dir_run}/kansasii_phylogeny", mode: 'copy')
    tag { species }
    containerOptions "-B ${params.kansasii_ref_dir} -B ${params.kansasii_snippy_db}"

    input:
    val (species)

    output:
    tuple val (species), path ("*_core.aln"), emit: core_aln

    script:
    """
    species_key=\$(echo "${species}" | tr ' ' '_')
    ref="${params.kansasii_ref_dir}/\${species_key}.fasta"

    # Aggregate across ALL isolates accumulated for this species so far,
    # not just the ones processed in this run.
    snippy-core --ref "\$ref" --prefix "\${species_key}_core" "${params.kansasii_snippy_db}/\${species_key}"/*/
    """
}

process kansasii_tree {
    publishDir("${params.output_dir_run}/kansasii_phylogeny", mode: 'copy')
    tag { species }

    input:
    tuple val (species), path (core_aln)

    output:
    tuple val (species), path ("*.treefile"), emit: tree
    path "*.iqtree"
    path "kansasii_tree_version.txt", emit: version

    script:
    """
    species_key=\$(echo "${species}" | tr ' ' '_')
    iqtree -s ${core_aln} -m GTR+G -nt ${task.cpus} -pre "\${species_key}_tree"

    iqtree --version 2>&1 | head -n 1 > iqtree_vers.txt
    echo ${task.container} > iqtree_singularity.txt
    cat iqtree_vers.txt iqtree_singularity.txt | tr "\\n" "\\t" > kansasii_tree_version.txt
    """
}
