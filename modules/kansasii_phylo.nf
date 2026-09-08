/*
* kansasii_phylo module
*
* Reference-based SNP phylogeny for the Mycobacterium kansasii complex.
* GTDB-Tk already resolves species-level identity within the complex via
* ANI, but doesn't give strain-level relatedness. These processes map
* every sample's assembly against a single shared reference with Snippy
* (so all complex members land on the same coordinate system), accumulate
* results in a persistent database (mirroring the pyMLST cgMLST pattern),
* and build one core-SNP tree with IQ-TREE across all complex isolates
* seen so far (not just this run).
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
    ref="${params.kansasii_ref_dir}/GCF_000157895.3_ASM15789v2_genomic.fna"

    if [ ! -f "\$ref" ]; then
        echo "Shared kansasii complex reference not found at \$ref" >&2
        exit 1
    fi

    snippy --ctgs ${assembly} --ref "\$ref" --outdir snippy_out --cpus ${task.cpus} --force

    # Add/refresh this sample's result in the persistent, complex-wide db.
    # All complex members share the same reference, so the tree is built
    # across every isolate regardless of species.
    mkdir -p "${params.kansasii_snippy_db}"
    rm -rf "${params.kansasii_snippy_db}/${sample_id}"
    cp -r snippy_out "${params.kansasii_snippy_db}/${sample_id}"

    snippy --version 2>&1 | head -n 1 > snippy_vers.txt
    echo ${task.container} > snippy_singularity.txt
    cat snippy_vers.txt snippy_singularity.txt | tr "\\n" "\\t" > ${sample_id}_kansasii_snippy_version.txt
    """
}

process kansasii_snippy_core {
    publishDir("${params.output_dir_run}/kansasii_phylogeny", mode: 'copy')
    containerOptions "-B ${params.kansasii_ref_dir} -B ${params.kansasii_snippy_db}"

    input:
    val (trigger)

    output:
    path ("*_core.aln"), emit: core_aln

    script:
    """
    ref="${params.kansasii_ref_dir}/GCF_000157895.3_ASM15789v2_genomic.fna"

    # Aggregate across ALL isolates accumulated for the complex so far,
    # not just the ones processed in this run.
    snippy-core --ref "\$ref" --prefix "kansasii_complex_core" "${params.kansasii_snippy_db}"/*/
    """
}

process kansasii_tree {
    publishDir("${params.output_dir_run}/kansasii_phylogeny", mode: 'copy')

    input:
    path (core_aln)

    output:
    path "*.treefile", emit: tree
    path "*.iqtree"
    path "kansasii_tree_version.txt", emit: version

    script:
    """
    iqtree -s ${core_aln} -m GTR+G -nt ${task.cpus} -pre "kansasii_complex_tree"

    iqtree --version 2>&1 | head -n 1 > iqtree_vers.txt
    echo ${task.container} > iqtree_singularity.txt
    cat iqtree_vers.txt iqtree_singularity.txt | tr "\\n" "\\t" > kansasii_tree_version.txt
    """
}
