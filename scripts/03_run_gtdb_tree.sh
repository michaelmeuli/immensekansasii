#!/usr/bin/env bash
# 03_run_gtdb_tree.sh - reference tree of the 7 kansasii-complex GTDB representatives.
#
# Symlinks the representatives (list from 01_gtdb_mycobacteria_genomes.sh) as
# <accession>_query.fasta and submits the IMMENSE pipeline on them (-t fasta).
#
# Every accession is itself a GTDB-Tk reference genome, so gtdbtk_classify_wf rejects
# them as queries ("same id as GTDB-Tk reference genomes"). The list pairs each accession
# with a "_query" id; the symlink carries that id, which becomes the tree tip name.
#
# Usage:  bash 03_run_gtdb_tree.sh [-s GTDB_REPRESENTATIVES_DIR]   (conda activate env_immense not needed, only submits)
#   -s  directory the <accession>_query.fasta links are written to (default GTDB_REPRESENTATIVES, the reference set of all repos)
# After the Slurm job (job_kansasii_complex_gtdb_representatives) has finished and been checked:
#   bash 07_generate_itol_species_labels.sh        # iTOL files for the tree (reads the tree from $ROOT/runs/, writes output/iTOL/)
# run_IMMENSE.sh only submits the controller job and returns at once, so step 07 must wait.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${KANSASII_ROOT:-/shares/sander.imm.uzh/MM/kansasii}/repos/kansasii-docs/templates/kansasii_paths.sh"
RUN=kansasii_complex_gtdb_representatives
ACCESSIONS_FILE=$GTDB_ACCESSIONS_DIR/kansasii_complex_gtdb_representative_accessions_renamed.txt
GENOME_DATA_DIR=$NCBI_DATASET
SELECTED_DIR=$GTDB_REPRESENTATIVES
while getopts s: o; do case $o in s) SELECTED_DIR=$OPTARG ;; *) echo "usage: $0 [-s dir]" >&2; exit 2 ;; esac; done
SNIPPY_DB_DIR=$IMMENSE_DB_ROOT/$RUN
RUN_DIR=$RUNS/$RUN

[[ -s "$ACCESSIONS_FILE" ]] || { echo "missing $ACCESSIONS_FILE: run 01_gtdb_mycobacteria_genomes.sh first" >&2; exit 1; }
mkdir -p "$SELECTED_DIR" "$SNIPPY_DB_DIR" "$RUN_DIR"

n=0
while read -r acc renamed; do
  [[ -z "$acc" ]] && continue
  src=$(find "$GENOME_DATA_DIR/$acc" -maxdepth 1 \( -name '*.fna' -o -name '*.fasta' \) | head -1)
  if [[ -z "$src" ]]; then
    echo "WARNING: no fasta/fna found for $acc" >&2
    continue
  fi
  ln -sf "$src" "$SELECTED_DIR/$renamed.fasta"
  n=$((n+1))
done < "$ACCESSIONS_FILE"
echo "linked $n genomes into $SELECTED_DIR"

cd "$RUN_DIR"
bash "$HERE/run_IMMENSE.sh" -j "job_$RUN" -t fasta -r "$RUN" \
     -x "--kansasii_snippy_db $SNIPPY_DB_DIR" -i "$SELECTED_DIR"
