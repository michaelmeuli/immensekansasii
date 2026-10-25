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
# Usage:  bash 03_run_gtdb_tree.sh        (conda activate env_immense not needed, only submits)
# After the Slurm job (job_kansasii_complex_gtdb_representatives) has finished and been checked:
#   rsync -a --exclude work --exclude .nextflow --exclude '*_transfer_result/genomes/' \
#       $ROOT/runs/kansasii_complex_gtdb_representatives/ $ROOT/output/kansasii_complex_gtdb_representatives/
#   bash 07_generate_itol_species_labels.sh        # iTOL files for the tree
# run_IMMENSE.sh only submits the controller job and returns at once, so the rsync must wait.
set -euo pipefail

ROOT=${KANSASII_ROOT:-/shares/sander.imm.uzh/MM/kansasii}
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
RUN=kansasii_complex_gtdb_representatives
ACCESSIONS_FILE=$ROOT/output/immensekansasii/gtdb/gtdb232/kansasii_complex_gtdb_representative_accessions_renamed.txt
GENOME_DATA_DIR=$ROOT/data/gtdb_genomes/Mycobacteriaceae/ncbi_dataset/data
SELECTED_DIR=$ROOT/data/gtdb_genomes/Mycobacteriaceae/$RUN
SNIPPY_DB_DIR=/shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/kansasii_complex/$RUN
RUN_DIR=$ROOT/runs/$RUN

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
