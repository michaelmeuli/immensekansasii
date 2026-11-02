/*
* kansasii_phylo module (branch `kansasii`)
*
* Reference-based core-SNP phylogeny across all samples. GTDB-Tk already
* resolves species-level identity via ANI, but doesn't give strain-level
* relatedness. Three processes in series (called from main.nf, skipped with
* --skip_kansasii_phylo true):
*
*   kansasii_snippy       per sample: snippy of the Unicycler assembly against
*                         ONE shared reference, result copied into the snippy db
*   kansasii_snippy_core  once: snippy-core over ALL sample dirs in the db
*   kansasii_tree         once: IQ-TREE (GTR+G) on the core SNP alignment
*
* Parameters (conf/profiles/*.config, override with run_IMMENSE.sh -x "..."):
*   params.kansasii_ref_dir    dir with GCF_000157895.3_ASM15789v2_genomic.fna
*                              (M. kansasii ATCC 12478). All samples are mapped to
*                              it whatever their GTDB species.
*   params.kansasii_snippy_db  REQUIRED, no global default (main.nf stops without
*                              it). A plain directory that kansasii_snippy fills,
*                              <db>/<sample_id>/ = full snippy output. Must exist
*                              before the run (it is bind-mounted). Use one db per
*                              run set: snippy-core globs <db>/*/, so the tree
*                              contains exactly what is in the dir at that moment,
*                              including samples of earlier runs and stale ones.
*
* Outputs: <output_dir_run>/kansasii_phylogeny/{kansasii_complex_core.aln,
*   kansasii_complex_tree.treefile, kansasii_complex_tree.iqtree}. The tree is
*   unrooted, has no branch support (no -bb/-alrt) and, since the alignment holds
*   SNP columns only and the model has no +ASC, branch lengths are overestimated.
*   Midpoint rooting happens later in scripts/12_generate_itol_ast.py.
*
* Documentation: WORKFLOW.md section 2d. The db follows the same accumulate-across-
* runs pattern as the pyMLST cgMLST db, hence the run-level caveat: the tree of the
* last invocation covers every isolate in the db, the run-level tables do not.
*/

// Per sample. --ctgs maps the assembly (not the reads) to the shared reference, so
// SNPs come from contigs and read depth plays no role. The whole snippy_out/ is
// copied into the persistent db; an existing dir of the same sample id is replaced.
process kansasii_snippy {
    publishDir("${params.output_dir_sample}/${sample_id}/5_typing/kansasii_snippy", mode: 'link')
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

// Once per invocation (maxForks 1 in the profile: one reader of the db at a time).
// Takes only a trigger from kansasii_snippy; the input is the db dir itself, i.e.
// ALL samples accumulated so far. Only *_core.aln (core SNPs) is published; the
// other snippy-core files (.full.aln, .tab, .txt with per-sample core fractions)
// stay in work/.
process kansasii_snippy_core {
    publishDir("${params.output_dir_run}/kansasii_phylogeny", mode: 'link')
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

// IQ-TREE on the core SNP alignment. GTR+G (reported as GTR+F+G4), single run, no
// bootstrap, no +ASC. Output is unrooted; "Reference" is one of the tips.
process kansasii_tree {
    publishDir("${params.output_dir_run}/kansasii_phylogeny", mode: 'link')

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
