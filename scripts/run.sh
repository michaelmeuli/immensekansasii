


# By default the output is always written in the current directory
cd /shares/sander.imm.uzh/MM/kansasii/output
bash /shares/sander.imm.uzh/MM/kansasii/immensekansasii/run_IMMENSE.sh -j test_run -t fq_PE -r test_run -i /shares/sander.imm.uzh/MM/kansasii/immensekansasii/data/test_dataset




ssh mimeul@cluster.s3it.uzh.ch "cd /shares/sander.imm.uzh/MM/kansasii/output && tar --exclude='work' -cf /tmp/archive.tar ."
scp mimeul@cluster.s3it.uzh.ch:/tmp/archive.tar "$env:USERPROFILE\kansasii_C\downloads\"
cd "$env:USERPROFILE\kansasii_C\downloads"
tar -xf archive.tar



# ssh mimeul@cluster.s3it.uzh.ch "cd /shares/sander.imm.uzh/MM/kansasii/output && find . -name '*.html' | tar -cf /tmp/htmls.tar -T -"
# scp mimeul@cluster.s3it.uzh.ch:/tmp/htmls.tar "$env:USERPROFILE\kansasii_C\downloads\"
# cd "$env:USERPROFILE\kansasii_C\downloads"
# tar -xf htmls.tar

# ssh mimeul@cluster.s3it.uzh.ch "cd /shares/sander.imm.uzh/MM/kansasii/output && tar --exclude='./*/work' -cf /tmp/archive.tar ."



mkdir -p /shares/sander.imm.uzh/MM/kansasii/output/reference_genomes_gtdb_232
cd /shares/sander.imm.uzh/MM/kansasii/output/reference_genomes_gtdb_232
bash /shares/sander.imm.uzh/MM/kansasii/immensekansasii/run_IMMENSE.sh -j ref_232_run -t fasta -r ref_run -i /shares/sander.imm.uzh/MM/kansasii/data/reference_genomes_gtdb_232/

ssh mimeul@cluster.s3it.uzh.ch "rm -f /shares/sander.imm.uzh/MM/kansasii/output/archive.tar"
ssh mimeul@cluster.s3it.uzh.ch "cd /shares/sander.imm.uzh/MM/kansasii/output/reference_genomes_gtdb_232 && tar --exclude='work' -cf /shares/sander.imm.uzh/MM/kansasii/output/archive.tar ."
New-Item -ItemType Directory -Path "$env:USERPROFILE\kansasii_C\downloads\reference_genomes_gtdb_232\" -Force
scp mimeul@cluster.s3it.uzh.ch:/shares/sander.imm.uzh/MM/kansasii/output/archive.tar "$env:USERPROFILE\kansasii_C\downloads\reference_genomes_gtdb_232\"
cd "$env:USERPROFILE\kansasii_C\downloads\reference_genomes_gtdb_232\"
tar -xf archive.tar




# -i only takes a single directory (the pipeline recurses through it with
# **/*.{fasta,fna}), so it can't be handed a glob of per-genome dirs -- only
# the first match would ever be used. Build a flat directory of symlinks,
# one per accession listed in mycobacterium_representative_type_strain_accessions.txt,
# and point -i at that instead.
ACCESSIONS_FILE="/shares/sander.imm.uzh/MM/kansasii/lit/gtdb/gtdb232/mycobacterium_representative_type_strain_accessions.txt"
GENOME_DATA_DIR="/shares/sander.imm.uzh/MM/kansasii/data/gtdb_genomes/Mycobacteriaceae/ncbi_dataset/data"
SELECTED_DIR="/shares/sander.imm.uzh/MM/kansasii/data/gtdb_genomes/Mycobacteriaceae/selected_type_strains"

mkdir -p "$SELECTED_DIR"
while read -r acc; do
  [ -z "$acc" ] && continue
  acc=$(echo "$acc" | cut -c4-)  # strip RS_/GB_ source-flag prefix
  src=$(find "$GENOME_DATA_DIR/$acc" -maxdepth 1 \( -name '*.fna' -o -name '*.fasta' \) | head -1)
  if [ -z "$src" ]; then
    echo "WARNING: no fasta/fna found for $acc" >&2
    continue
  fi
  ln -sf "$src" "$SELECTED_DIR/$acc.fasta"
done < "$ACCESSIONS_FILE"

mkdir -p /shares/sander.imm.uzh/MM/kansasii/output/tree_run
cd /shares/sander.imm.uzh/MM/kansasii/output/tree_run
bash /shares/sander.imm.uzh/MM/kansasii/immensekansasii/run_IMMENSE.sh -j job_tree_run -t fasta -r tree_run -i "$SELECTED_DIR"



ssh mimeul@cluster.s3it.uzh.ch "rm -f /shares/sander.imm.uzh/MM/kansasii/output/archive.tar"
ssh mimeul@cluster.s3it.uzh.ch "cd /shares/sander.imm.uzh/MM/kansasii/output/tree_run && tar --exclude='work' -cf /shares/sander.imm.uzh/MM/kansasii/output/archive.tar ."
New-Item -ItemType Directory -Path "$env:USERPROFILE\kansasii_C\downloads\tree_run\" -Force
scp mimeul@cluster.s3it.uzh.ch:/shares/sander.imm.uzh/MM/kansasii/output/archive.tar "$env:USERPROFILE\kansasii_C\downloads\tree_run\"
cd "$env:USERPROFILE\kansasii_C\downloads\tree_run\"
tar -xf archive.tar




mkdir -p /shares/sander.imm.uzh/MM/kansasii/output/ref_tree_run_test
cd /shares/sander.imm.uzh/MM/kansasii/output/ref_tree_run_test
bash /shares/sander.imm.uzh/MM/kansasii/immensekansasii/run_IMMENSE.sh -j job_ref_tree_run_test -t fasta -r ref_tree_run_test -i /shares/sander.imm.uzh/MM/kansasii/data/reference_genomes_gtdb_232


ssh mimeul@cluster.s3it.uzh.ch "rm -f /shares/sander.imm.uzh/MM/kansasii/output/archive.tar"
ssh mimeul@cluster.s3it.uzh.ch "cd /shares/sander.imm.uzh/MM/kansasii/output/ref_tree_run_test && tar --exclude='work' -cf /shares/sander.imm.uzh/MM/kansasii/output/archive.tar ."
New-Item -ItemType Directory -Path "$env:USERPROFILE\kansasii_C\downloads\ref_tree_run_test\" -Force
scp mimeul@cluster.s3it.uzh.ch:/shares/sander.imm.uzh/MM/kansasii/output/archive.tar "$env:USERPROFILE\kansasii_C\downloads\ref_tree_run_test\"
cd "$env:USERPROFILE\kansasii_C\downloads\ref_tree_run_test\"
tar -xf archive.tar




# Same idea as the selected_type_strains block above, but for the broader
# "relevant species" set (kansasii complex + MTBC + MAC + simiae) in
# mycobacterium_relevant_species_representative_accessions.txt. That file
# is already stripped of the RS_/GB_ source-flag prefix (unlike
# mycobacterium_representative_type_strain_accessions.txt above), so no
# `cut -c4-` is needed here.
#
# Every one of these accessions is itself a GTDB-Tk reference genome, so
# gtdbtk_classify_wf rejects them outright as query input ("You have N
# genomes with the same id as GTDB-Tk reference genomes, please rename
# them."). mycobacterium_relevant_species_representative_accessions_renamed.txt
# (built in gtdb_mycobacteria_genomes.sh) pairs each accession with a
# "_query"-suffixed id; symlink under the renamed id so the destination
# filename -- which is what gtdbtk/Channel.fromFilePairs key tips off --
# no longer collides.
#
# Feeding this SELECTED_DIR into run_IMMENSE.sh with -t fasta runs
# kansasii_phylo.nf and produces a tree (kansasii_complex_tree.treefile)
# with tip labels = renamed ids (accession + "_query") -- see
# scripts/generate_itol_species_labels.sh for turning those into iTOL
# species-name annotations after upload (that script will need updating to
# match on the renamed ids too).
ACCESSIONS_FILE="/shares/sander.imm.uzh/MM/kansasii/lit/gtdb/gtdb232/mycobacterium_relevant_species_representative_accessions_renamed.txt"
GENOME_DATA_DIR="/shares/sander.imm.uzh/MM/kansasii/data/gtdb_genomes/Mycobacteriaceae/ncbi_dataset/data"
SELECTED_DIR="/shares/sander.imm.uzh/MM/kansasii/data/gtdb_genomes/Mycobacteriaceae/selected_relevant_species"

mkdir -p "$SELECTED_DIR"
while read -r acc renamed; do
  [ -z "$acc" ] && continue
  src=$(find "$GENOME_DATA_DIR/$acc" -maxdepth 1 \( -name '*.fna' -o -name '*.fasta' \) | head -1)
  if [ -z "$src" ]; then
    echo "WARNING: no fasta/fna found for $acc" >&2
    continue
  fi
  ln -sf "$src" "$SELECTED_DIR/$renamed.fasta"
done < "$ACCESSIONS_FILE"

mkdir -p /shares/sander.imm.uzh/MM/kansasii/output/relevant_species_tree_run
cd /shares/sander.imm.uzh/MM/kansasii/output/relevant_species_tree_run
bash /shares/sander.imm.uzh/MM/kansasii/immensekansasii/run_IMMENSE.sh -j job_relevant_species_tree_run -t fasta -r relevant_species_tree_run -i "$SELECTED_DIR"


ssh mimeul@cluster.s3it.uzh.ch "rm -f /shares/sander.imm.uzh/MM/kansasii/output/archive.tar"
ssh mimeul@cluster.s3it.uzh.ch "cd /shares/sander.imm.uzh/MM/kansasii/output/relevant_species_tree_run && tar --exclude='work' -cf /shares/sander.imm.uzh/MM/kansasii/output/archive.tar ."
New-Item -ItemType Directory -Path "$env:USERPROFILE\kansasii_C\downloads\relevant_species_tree_run\" -Force
scp mimeul@cluster.s3it.uzh.ch:/shares/sander.imm.uzh/MM/kansasii/output/archive.tar "$env:USERPROFILE\kansasii_C\downloads\relevant_species_tree_run\"
cd "$env:USERPROFILE\kansasii_C\downloads\relevant_species_tree_run\"
tar -xf archive.tar




# Sanity check ahead of a merge request against
# https://gitlab.uzh.ch/appliedmicrobiologyresearch/immense.git: kansasii is
# 48 commits ahead of upstream/master (their common ancestor), including
# c2ad8c452e489550 ("fix sample_ids_ch for .fasta"), which is NOT on master.
#
# Confirmed by actually running this: on master, `workflow {}` gates all
# read-based processing behind `if (params.input_type != "fasta") { ... }`,
# and reads_for_trimming is only ever assigned inside that block. The later
# top-level statement `def sample_ids_ch = reads_for_trimming.other...` is
# unconditional, so for -t fasta it throws "No such variable:
# reads_for_trimming" while Nextflow is still evaluating the workflow script
# -- before any channel is subscribed to or any process is submitted. Result:
# zero tasks ever run (empty trace file) and there is no output whatsoever,
# not a partial/incomplete one. -t fasta is non-functional on master.
# Re-run the exact same relevant-species input (selected_relevant_species/,
# unchanged) against master in an isolated worktree to reproduce this before
# proposing the merge.
git -C /shares/sander.imm.uzh/MM/kansasii/immensekansasii worktree add /shares/sander.imm.uzh/MM/kansasii/immensekansasii-master-test master

mkdir -p /shares/sander.imm.uzh/MM/kansasii/output/relevant_species_tree_run_master_test
cd /shares/sander.imm.uzh/MM/kansasii/output/relevant_species_tree_run_master_test
bash /shares/sander.imm.uzh/MM/kansasii/immensekansasii-master-test/run_IMMENSE.sh -j job_relevant_species_tree_run_master_test -t fasta -r relevant_species_tree_run_master_test -i /shares/sander.imm.uzh/MM/kansasii/data/gtdb_genomes/Mycobacteriaceae/selected_relevant_species

# Confirmed: the job finishes in ~1 minute with an empty trace file (zero
# tasks ever submitted) and no *_transfer_result directory at all -- nothing
# to archive/download here. See slurm-<jobid>.out / .nextflow.log in
# relevant_species_tree_run_master_test/ directly on the cluster for the
# stack trace ("No such variable: reads_for_trimming" at main.nf:484)
# supporting the merge request.


# master had since moved: origin/master picked up d78b6df ("fixed
# sample_ids_ch when running on .fasta files", a colleague's fix merged via
# upstream/sample_ids_ch-fix) after the run above. It replaces the
# unconditional `reads_for_trimming` reference with a ternary:
#   def sample_ids_ch = (params.input_type == "fasta")
#       ? genome.map { sample_id, fasta -> sample_id }.distinct()
#       : reads_for_trimming.other.map { sample_id, reads -> sample_id }.distinct()
# Update master and re-test the exact same input against it to see whether
# that actually resolves things.
git -C /shares/sander.imm.uzh/MM/kansasii/immensekansasii-master-test merge --ff-only origin/master

mkdir -p /shares/sander.imm.uzh/MM/kansasii/output/relevant_species_tree_run_master_test2
cd /shares/sander.imm.uzh/MM/kansasii/output/relevant_species_tree_run_master_test2
bash /shares/sander.imm.uzh/MM/kansasii/immensekansasii-master-test/run_IMMENSE.sh -j job_relevant_species_tree_run_master_test2 -t fasta -r relevant_species_tree_run_master_test2 -i /shares/sander.imm.uzh/MM/kansasii/data/gtdb_genomes/Mycobacteriaceae/selected_relevant_species

# Confirmed: it doesn't. This fails even harder -- a Nextflow DSL2 SCRIPT
# COMPILATION error, before the run reaches the point the previous version
# crashed at:
#   ERROR ~ Script compilation error
#   - cause: Variable `genome` already defined in the process scope @ line
#     485, column 7.
# The ternary's two branches reference channels from different conditional
# scopes (`genome` from the `input_type == "fasta"` block, `reads_for_trimming`
# from the `!= "fasta"` block), which DSL2 rejects outright when written as a
# ternary -- explaining why kansasii's c2ad8c452e489550 rewrites this as
# if/else instead (main.nf:504-508 on kansasii), which does compile and run.
# So both the pre- and post-d78b6df states of master fail on -t fasta with
# zero output; only kansasii's if/else version actually works.


# Does cherry-picking just c2ad8c452e489550 onto master make it produce the
# same output as kansasii? Test on a dedicated branch (not master itself),
# via its own worktree so it can run without disturbing this checkout.
git branch master-fasta-fix-test master
git checkout master-fasta-fix-test
git cherry-pick c2ad8c452e489550
git checkout kansasii
git worktree add /shares/sander.imm.uzh/MM/kansasii/immensekansasii-fasta-fix-test master-fasta-fix-test

mkdir -p /shares/sander.imm.uzh/MM/kansasii/output/relevant_species_tree_run_master_fasta_fix_test
cd /shares/sander.imm.uzh/MM/kansasii/output/relevant_species_tree_run_master_fasta_fix_test
bash /shares/sander.imm.uzh/MM/kansasii/immensekansasii-fasta-fix-test/run_IMMENSE.sh -j job_relevant_species_tree_run_master_fasta_fix_test -t fasta -r relevant_species_tree_run_master_fasta_fix_test -i /shares/sander.imm.uzh/MM/kansasii/data/gtdb_genomes/Mycobacteriaceae/selected_relevant_species

# Confirmed: the cherry-pick alone is not enough. The run actually executes
# now (compiles, all 20 samples processed, 39min), but genomes/<species>/ in
# the published transfer_result comes out completely empty -- all 20
# assembly links missing -- because modules/create_links.nf's
# links_for_transfer process on master builds its `ln -srf` destination from
# bare relative paths without ever cd-ing to the launch/run directory first,
# so it runs against the task's own (unrelated) work dir and fails with
# "No such file or directory" on every single sample. It even computes the
# correct relative path via a `relpath` helper into $rel_genome, then never
# uses it -- dead code. kansasii fixes this independently in dea5850 ("Fix
# busco lineage, gtdbtk data path, and links_for_transfer symlink bug"),
# swapping the broken hardcoded line for `ln -srf "$rel_genome"
# "$dest_genome_dir/$(basename "$src_genome")"`. Every other output
# (cgMLST, quality QC row counts, trimmed_reads -- empty on both sides for
# fasta input, as expected) matched between the two runs.
#
# Conclusion for the merge request: master needs BOTH c2ad8c452e489550 and
# dea5850 (at minimum) before -t fasta produces complete output; neither fix
# alone is sufficient, and kansasii is the only branch that has both plus
# the whole phylogeny feature.

# cleanup once done inspecting
cd /shares/sander.imm.uzh/MM/kansasii/immensekansasii
git worktree remove immensekansasii-fasta-fix-test
rm -rf /shares/sander.imm.uzh/MM/kansasii/output/relevant_species_tree_run_master_fasta_fix_test
# master-fasta-fix-test branch kept and pushed to origin as MR-supporting evidence


