#!/usr/bin/env bash
#
# The kansasii_phylo.nf tree (kansasii_complex_tree.treefile) has tip labels
# equal to the input sample names (fasta name or fastq pair prefix; Channel.fromFilePairs keys tips off the
# fasta filename), so the raw tree is unreadable on iTOL without a species
# mapping. This script builds that mapping and writes two iTOL annotation
# files that can be dragged onto the tree in the iTOL browser after uploading
# the .treefile there (both are display overlays, not changes to the
# underlying tree/tip IDs):
#
#   itol_species_labels.txt      LABELS dataset: renames each tip's display
#                                 text to "Species name [accession|sample]"
#   itol_species_colorstrip.txt  DATASET_COLORSTRIP dataset: adds a colored
#                                 strip next to each tip grouping it into
#                                 kansasii complex / MTBC / MAC / M. simiae
#                                 complex
#
# Two modes provide the (tip_id, display_id, species) map:
#
#   gtdb     (default) GTDB representative genomes. Tips are the "_query"-
#            suffixed ids from an accessions file (accession<TAB>renamed_id,
#            built in immensekansasii/scripts/gtdb_mycobacteria_genomes.sh; the
#            suffix avoids a collision with GTDB-Tk's own reference ids).
#            Species come from GTDB metadata (bac120_metadata_r232.tsv).
#   samples  real isolates. Tips are the short ids (NR column) used as fasta
#            names by scripts/run.sh; species come from screening_map_results.csv
#            (written by immensekansasii/scripts/screening_map_results.py).
#            Display text is "Species [Mkan329-NNN]".
#
# Usage: bash generate_itol_species_labels.sh [-m gtdb|samples] [-a ACCESSIONS_FILE]
#                                              [-r RESULTS_CSV] [-o OUT_DIR] [-p PREFIX]
#   -m  mode (default gtdb)
#   -a  gtdb mode: accessions file name/path (default
#       kansasii_complex_gtdb_representative_accessions_renamed.txt in OUT_DIR; use
#       mycobacterium_relevant_species_representative_accessions_renamed.txt for the 20-genome set)
#   -r  samples mode: screening_map_results.csv (default data/imm/screening_map_results.csv)
#   -o  output dir (default output/lit/gtdb/gtdb232 in gtdb mode, output/mkan329 in samples mode)
#   -p  output file prefix, e.g. "mkan329_" (default none)
# Writes: <prefix>itol_species_labels.txt, <prefix>itol_species_colorstrip.txt in OUT_DIR

set -euo pipefail

K=/shares/sander.imm.uzh/MM/kansasii
DATA_DIR=$K/data/lit/gtdb/gtdb232
METADATA="$DATA_DIR/bac120_metadata_r232.tsv"

MODE=gtdb
ACCESSIONS_FILE="kansasii_complex_gtdb_representative_accessions_renamed.txt"
RESULTS_CSV="$K/data/imm/screening_map_results.csv"
OUT_DIR=""
PREFIX=""
while getopts "m:a:r:o:p:" opt; do
  case $opt in
    m) MODE=$OPTARG ;;
    a) ACCESSIONS_FILE=$OPTARG ;;
    r) RESULTS_CSV=$OPTARG ;;
    o) OUT_DIR=$OPTARG ;;
    p) PREFIX=$OPTARG ;;
    *) echo "usage: $0 [-m gtdb|samples] [-a accessions] [-r results.csv] [-o outdir] [-p prefix]" >&2; exit 2 ;;
  esac
done

case $MODE in
  gtdb)    : "${OUT_DIR:=$K/output/lit/gtdb/gtdb232}" ;;
  samples) : "${OUT_DIR:=$K/output/mkan329}" ;;
  *) echo "unknown mode: $MODE" >&2; exit 2 ;;
esac

# resolve the accessions file against OUT_DIR if given as a bare name
if [ "$MODE" = gtdb ] && [ "${ACCESSIONS_FILE#/}" = "$ACCESSIONS_FILE" ] && [ ! -f "$ACCESSIONS_FILE" ]; then
  ACCESSIONS_FILE="$OUT_DIR/$ACCESSIONS_FILE"
fi
mkdir -p "$OUT_DIR"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
JOINED="$TMP/joined.tsv"   # tip_id <TAB> display_id <TAB> species

if [ "$MODE" = gtdb ]; then
  ACC_COL=$(head -1 "$METADATA" | tr '\t' '\n' | grep -n '^accession$' | cut -d: -f1)
  TAX_COL=$(head -1 "$METADATA" | tr '\t' '\n' | grep -n '^gtdb_taxonomy$' | cut -d: -f1)

  # accession (prefix stripped) -> GTDB species (s__ token, e.g. "Mycobacterium kansasii")
  awk -F'\t' -v OFS='\t' -v acc="$ACC_COL" -v tax="$TAX_COL" '
    NR>1 {
      a = substr($acc, 4)               # strip RS_/GB_ source-flag prefix
      t = $tax
      sub(/.*s__/, "", t)                # keep species token only
      print a, t
    }' "$METADATA" > "$TMP/acc_species.tsv"

  # ACCESSIONS_FILE is (accession, renamed_id); join on accession, then emit
  # (renamed_id = tip id, accession = display id, species).
  join -t $'\t' -1 1 -2 1 <(sort -t $'\t' -k1,1 "$ACCESSIONS_FILE") <(sort -t $'\t' -k1,1 "$TMP/acc_species.tsv") |
    awk -F'\t' -v OFS='\t' '{print $2, $1, $3}' > "$JOINED"
  n_in=$(grep -c . "$ACCESSIONS_FILE" || true)
else
  # NR (tip id), PROBENNUMMER (display id), species. Species: GTDB species from
  # screening_map_results.csv; reference strains (no genome result) fall back to LABEL.
  python3 - "$RESULTS_CSV" > "$JOINED" <<'PY'
import csv, sys
for r in csv.DictReader(open(sys.argv[1], newline="", encoding="utf-8")):
    sp = r.get("species") or r.get("LABEL") or ""
    if not r["NR"] or not sp:
        continue
    print("\t".join([r["NR"], r["PROBENNUMMER"], sp]))
PY
  n_in=$(python3 -c "import csv,sys; print(sum(1 for _ in csv.DictReader(open(sys.argv[1], newline='', encoding='utf-8'))))" "$RESULTS_CSV")
fi

n_joined=$(grep -c . "$JOINED" || true)
if [ "$n_in" -ne "$n_joined" ]; then
  echo "WARNING: $n_joined/$n_in entries have a species -- some tips will be unlabeled" >&2
fi

# --- LABELS dataset: rename tip display text to "Species [display_id]" ---
{
  echo "LABELS"
  echo "SEPARATOR TAB"
  echo "DATA"
  awk -F'\t' -v OFS='\t' '{print $1, $3 " [" $2 "]"}' "$JOINED"
} > "$OUT_DIR/${PREFIX}itol_species_labels.txt"

# --- DATASET_COLORSTRIP dataset: color by species complex ---
# GTDB species clusters get an _A/_B/_C suffix for within-species clades
# (e.g. colombiense_A); strip it so complex membership matches on the base
# species name. Reference-strain LABELs ("M. kansasii (ATCC 12478)") are
# normalised to the "Mycobacterium x" form first.
{
  echo "DATASET_COLORSTRIP"
  echo "SEPARATOR TAB"
  echo -e "DATASET_LABEL\tSpecies complex"
  echo -e "COLOR\t#000000"
  echo -e "LEGEND_TITLE\tSpecies complex"
  echo -e "LEGEND_SHAPES\t1\t1\t1\t1"
  echo -e "LEGEND_COLORS\t#4daf4a\t#e41a1c\t#377eb8\t#984ea3"
  echo -e "LEGEND_LABELS\tM. kansasii complex\tM. tuberculosis complex\tM. avium complex\tM. simiae complex"
  echo "DATA"
  awk -F'\t' -v OFS='\t' '
    {
      id = $1
      base = $3
      sub(/ \(.*/, "", base)             # drop "(ATCC ...)" from reference LABELs
      sub(/^M\. /, "Mycobacterium ", base)
      sub(/_[A-Z]$/, "", base)
      if (base ~ /^Mycobacterium (kansasii|persicum|pseudokansasii|innocens|attenuatum|ostraviense|gastri)$/) {
        color = "#4daf4a"; group = "M. kansasii complex"
      } else if (base ~ /^Mycobacterium tuberculosis/) {
        color = "#e41a1c"; group = "M. tuberculosis complex"
      } else if (base ~ /^Mycobacterium (avium|intracellulare|colombiense|arosiense|marseillense|vulneris)$/) {
        color = "#377eb8"; group = "M. avium complex"
      } else if (base ~ /^Mycobacterium simiae$/) {
        color = "#984ea3"; group = "M. simiae complex"
      } else {
        color = "#999999"; group = "other"
      }
      print id, color, group
    }' "$JOINED"
} > "$OUT_DIR/${PREFIX}itol_species_colorstrip.txt"

echo "Wrote ${PREFIX}itol_species_labels.txt and ${PREFIX}itol_species_colorstrip.txt to $OUT_DIR ($n_joined tips, mode $MODE)"
