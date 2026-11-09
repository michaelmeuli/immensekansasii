/*
* kansasii_phylo module (branch `kansasii`)
*
* Reference-based core-SNP phylogeny across all samples. GTDB-Tk already
* resolves species-level identity via ANI, but doesn't give strain-level
* relatedness. Three processes in series (called from main.nf, skipped with
* --skip_kansasii_phylo true; independent of GTDB-Tk and --skip_gtdb):
*
*   kansasii_snippy       per sample: snippy of the Unicycler assembly against
*                         ONE shared reference, result copied into the snippy db
*   kansasii_snippy_core  once: snippy-core over the usable sample dirs in the db
*   kansasii_tree         once: IQ-TREE (GTR+G, fixed seed) on the core SNP alignment
*
* Parameters (conf/profiles/*.config, override with run_IMMENSE.sh -x "..."):
*   params.kansasii_ref_dir    dir with GCF_000157895.3_ASM15789v2_genomic.fna
*                              (M. kansasii ATCC 12478). All samples are mapped to
*                              it whatever their GTDB species.
*   params.kansasii_snippy_db  REQUIRED, no global default (main.nf stops without
*                              it). A plain directory that kansasii_snippy fills,
*                              <db>/<sample_id>/ = full snippy output. Must exist
*                              before the run (it is bind-mounted). Use one db per
*                              run set: snippy-core takes every sample dir of the db, so the tree
*                              contains what is in the dir at that moment,
*                              including samples of earlier runs and stale ones.
*   params.kansasii_min_aligned_fraction   (default 0, set in main.nf)
*                              a sample enters snippy-core only if more than 0 and
*                              at least this fraction of the reference is aligned
*                              (A/C/G/T in its snps.aligned.fa). snippy-core keeps
*                              only positions aligned in EVERY sample, so one empty
*                              assembly removes the whole core alignment (seen in
*                              public_PRJNA1078897: SRR28038343 with 0 aligned
*                              bases, "No SNPs were detected", no tree) and a
*                              species outside the complex shrinks it (mkan329:
*                              the six non-complex samples align 0.3-5 % of the
*                              reference and leave a core of 875 columns, where
*                              the 171 clinical complex isolates alone give
*                              287,242; complex members align 56 % or more). The
*                              default 0 only drops empty samples, so trees across
*                              genera still work; pass 0.3 to keep a run to the
*                              complex. The samples left out are listed in
*                              kansasii_complex_core.samples.tsv.
*
* Outputs: <output_dir_run>/kansasii_phylogeny/{kansasii_complex_core.aln,
*   kansasii_complex_core.txt (snippy-core: aligned / unaligned / variant bases per
*   sample), kansasii_complex_core.samples.tsv (sample, aligned_fraction, status),
*   kansasii_complex_tree.treefile, kansasii_complex_tree.iqtree}. main.nf empties
*   this directory when the run starts, so a tree found there always belongs to
*   the last invocation (a failed snippy-core or IQ-TREE leaves no tree instead of
*   the previous one). The tree is unrooted, has no branch support (no -bb/-alrt)
*   and, since the alignment holds SNP columns only and the model has no +ASC,
*   branch lengths are overestimated. Midpoint rooting happens later in
*   scripts/12_generate_itol_ast.py.
*
* Documentation: kansasii-docs/docs/WORKFLOW.md section 2d. The db follows the same accumulate-across-
* runs pattern as the pyMLST cgMLST db, hence the run-level caveat: the tree of the
* last invocation covers every isolate in the db, the run-level tables do not.
*/

// Per sample. --ctgs maps the assembly (not the reads) to the shared reference, so
// SNPs come from contigs and read depth plays no role. The whole snippy_out/ is
// copied into the persistent db; an existing dir of the same sample id is replaced.
// The copy goes to a hidden temporary dir first and is renamed at the end, so the
// db never holds a half-written sample dir (snippy-core's <db>/*/ skips dot dirs).
process kansasii_snippy {
    publishDir("${params.output_dir_sample}/${sample_id}/5_typing/kansasii_snippy", mode: 'link')
    tag { sample_id }
    containerOptions "-B ${params.kansasii_ref_dir} -B ${params.kansasii_snippy_db}"

    input:
    tuple val (sample_id), path (assembly)

    output:
    val (sample_id), emit: done
    path "snippy_out/*"
    path "${sample_id}_kansasii_snippy_version.txt", emit: version

    script:
    """
    ref="${params.kansasii_ref_dir}/GCF_000157895.3_ASM15789v2_genomic.fna"
    db="${params.kansasii_snippy_db}"

    if [ ! -f "\$ref" ]; then
        echo "Shared kansasii complex reference not found at \$ref" >&2
        exit 1
    fi

    snippy --ctgs ${assembly} --ref "\$ref" --outdir snippy_out --cpus ${task.cpus} --force

    # Add/refresh this sample's result in the persistent, complex-wide db.
    # All complex members share the same reference, so the tree is built
    # across every isolate regardless of species.
    tmp="\$db/.tmp_${sample_id}_\$\$"
    rm -rf "\$tmp"
    cp -r snippy_out "\$tmp"
    rm -rf "\$db/${sample_id}"
    mv "\$tmp" "\$db/${sample_id}"

    snippy --version 2>&1 | head -n 1 > snippy_vers.txt
    echo ${task.container} > snippy_singularity.txt
    cat snippy_vers.txt snippy_singularity.txt | tr "\\n" "\\t" > ${sample_id}_kansasii_snippy_version.txt
    """
}

// Once per invocation (maxForks 1 in the profile: one reader of the db at a time).
// The input is the db dir itself, i.e. ALL samples accumulated so far; `db_state`
// (sample dir names + modification times, built in main.nf once every
// kansasii_snippy task is done) only makes -resume rerun this step when the db
// changed, e.g. after a sample dir was deleted by hand.
// Sample dirs without a complete snippy result, or with less than
// kansasii_min_aligned_fraction of the reference aligned, are left out (see header).
process kansasii_snippy_core {
    publishDir("${params.output_dir_run}/kansasii_phylogeny", mode: 'link')
    containerOptions "-B ${params.kansasii_ref_dir} -B ${params.kansasii_snippy_db}"

    input:
    val (db_state)

    output:
    path ("kansasii_complex_core.aln"), emit: core_aln
    path ("kansasii_complex_core.txt")
    path ("kansasii_complex_core.samples.tsv")

    script:
    """
    ref="${params.kansasii_ref_dir}/GCF_000157895.3_ASM15789v2_genomic.fna"
    db="${params.kansasii_snippy_db}"
    min="${params.kansasii_min_aligned_fraction}"

    # Aggregate across ALL isolates accumulated for the complex so far,
    # not just the ones processed in this run.
    printf 'sample\\taligned_fraction\\tstatus\\n' > kansasii_complex_core.samples.tsv
    keep=()
    for d in "\$db"/*/; do
        [ -d "\$d" ] || continue
        s=\$(basename "\$d")
        if [ ! -s "\$d/snps.aligned.fa" ] || [ ! -s "\$d/snps.vcf" ] || [ ! -e "\$d/snps.tab" ]; then
            printf '%s\\tNA\\texcluded_incomplete_snippy_dir\\n' "\$s" >> kansasii_complex_core.samples.tsv
            continue
        fi
        total=\$(grep -v '^>' "\$d/snps.aligned.fa" | tr -d '\\n' | wc -c)
        aligned=\$(grep -v '^>' "\$d/snps.aligned.fa" | tr -cd 'ACGT' | wc -c)
        frac=\$(awk -v a="\$aligned" -v t="\$total" 'BEGIN { printf "%.4f", (t > 0 ? a / t : 0) }')
        if awk -v f="\$frac" -v m="\$min" 'BEGIN { exit !(f >= m && f > 0) }'; then
            keep+=("\$d")
            printf '%s\\t%s\\tincluded\\n' "\$s" "\$frac" >> kansasii_complex_core.samples.tsv
        else
            printf '%s\\t%s\\texcluded_low_aligned_fraction\\n' "\$s" "\$frac" >> kansasii_complex_core.samples.tsv
        fi
    done

    n_excluded=\$(grep -c 'excluded_' kansasii_complex_core.samples.tsv || true)
    echo "snippy-core: \${#keep[@]} sample dirs included, \$n_excluded left out (min aligned fraction \$min)" >&2
    grep 'excluded_' kansasii_complex_core.samples.tsv >&2 || true
    if [ "\${#keep[@]}" -lt 2 ]; then
        echo "Fewer than 2 usable samples in \$db: no core alignment (IQ-TREE needs 3 sequences incl. Reference)" >&2
        exit 1
    fi

    snippy-core --ref "\$ref" --prefix "kansasii_complex_core" "\${keep[@]}"
    """
}

// IQ-TREE on the core SNP alignment. GTR+G (reported as GTR+F+G4), single run, no
// bootstrap, no +ASC, fixed seed (the same alignment gives the same tree). Output
// is unrooted; "Reference" is one of the tips.
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
    iqtree -s ${core_aln} -m GTR+G -nt ${task.cpus} -seed 1 -pre "kansasii_complex_tree"

    iqtree --version 2>&1 | head -n 1 > iqtree_vers.txt
    echo ${task.container} > iqtree_singularity.txt
    cat iqtree_vers.txt iqtree_singularity.txt | tr "\\n" "\\t" > kansasii_tree_version.txt
    """
}
