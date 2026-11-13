#!/usr/bin/env bash
# Core-SNP tree of the patient isolates of the complex alone (basis of the tree figure):
# snippy-core over their sample dirs of the mkan329 snippy db, then IQ-TREE GTR+G.
#   -> output/immensekansasii/results/iTOL/mkan329_patients171/{patients171.txt,kansasii_patients171_tree.treefile,
#      kansasii_patients171_tree.iqtree,kansasii_patients171_core.txt,MANIFEST_tree.txt}
# The pipeline tree (modules/kansasii_phylo.nf) takes every sample of the db; its non-complex controls leave only
# 875 core columns. Here the controls (LABEL set) and the `excluded` isolates are left out: the list comes from
# 12_generate_itol_ast.py --patient-list, the same rule that script uses to prune the tree.
# Not part of run_downstream.sh (about 45 min). Rerun when the snippy db or the `excluded` column changes, then
# rerun 12_generate_itol_ast.py. Submit: sbatch submit_patients171_tree.sbatch
#SBATCH --job-name=patients171-tree
#SBATCH --cpus-per-task=8
#SBATCH --mem=24G
#SBATCH --time=04:00:00
#SBATCH --output=/shares/sander.imm.uzh/MM/kansasii/output/immensekansasii/logs/%x-%j.log

set -euo pipefail
source "${KANSASII_ROOT:-/shares/sander.imm.uzh/MM/kansasii}/repos/kansasii-docs/templates/kansasii_paths.sh"
REPO=$REPOS/immensekansasii
OUT=$OUT_IMM/results/iTOL/mkan329_patients171
WORK=$RUNS/phylo_patients171            # core.aln (49 MB) stays here, not in output/
DB=$IMMENSE_DB_ROOT/mkan329
LIST=$OUT/patients171.txt
mkdir -p "$OUT" "$WORK"

# 1. sample list (plain python: the script imports Biopython only when it reads a tree)
python3 "$REPO/scripts/12_generate_itol_ast.py" --results "$SCREENING_MAP_RESULTS" --patient-list "$LIST"

# 2. every listed sample needs its snippy result in the db
mapfile -t ids < "$LIST"
dirs=()
for id in "${ids[@]}"; do
  [[ -d $DB/$id ]] || { echo "ERROR: $id is in $LIST but has no directory in $DB" >&2; exit 1; }
  dirs+=("$DB/$id/")
done
echo "${#dirs[@]} sample dirs"

module load apptainer
SNIPPY="apptainer exec -B $ATCC12478_DIR -B $DB -B $WORK $IMMENSE_CONTAINERS/quay.io-biocontainers-snippy-4.6.0--hdfd78af_6.img"
IQ="apptainer exec -B $WORK $IMMENSE_CONTAINERS/quay.io-biocontainers-iqtree-3.1.3--h8471819_0.img"

# 3. core alignment, 4. tree
cd "$WORK"
$SNIPPY snippy-core --ref "$ATCC12478_FASTA" --prefix core "${dirs[@]}" 2> snippy-core.log
rm -f core.full.aln
$IQ iqtree -s core.aln -m GTR+G -nt "${SLURM_CPUS_PER_TASK:-8}" -seed 1 -pre tree_GTR_G -redo > /dev/null

# 5. results under the names 12_generate_itol_ast.py reads
cp tree_GTR_G.treefile "$OUT/kansasii_patients171_tree.treefile"
cp tree_GTR_G.iqtree "$OUT/kansasii_patients171_tree.iqtree"
cp core.txt "$OUT/kansasii_patients171_core.txt"

# provenance (see kansasii-docs/docs/PROVENANCE.md); MANIFEST.txt of this directory belongs to script 12
MANIFEST_NAME=MANIFEST_tree.txt bash "$MANIFEST_SCRIPT" "$OUT" "$REPO" submit_patients171_tree.sbatch \
  "$SCREENING_MAP_RESULTS" "$DB" "$ATCC12478_FASTA"
echo done
