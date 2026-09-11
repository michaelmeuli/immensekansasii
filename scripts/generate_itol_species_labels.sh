#!/usr/bin/env bash
#
# The kansasii_phylo.nf tree (kansasii_complex_tree.treefile) has tip labels
# equal to the input accessions (Channel.fromFilePairs keys tips off the
# fasta filename -- see selected_relevant_species/$acc.fasta in run.sh), so
# the raw tree is unreadable on iTOL without a species mapping. This script
# builds that mapping from GTDB metadata and writes two iTOL annotation
# files that can be dragged onto the tree in the iTOL browser after
# uploading the .treefile there (Tree menu is unaffected -- both are display
# overlays, not changes to the underlying tree/accession IDs):
#
#   itol_species_labels.txt      LABELS dataset: renames each tip's display
#                                 text to "Species name [accession]"
#   itol_species_colorstrip.txt  DATASET_COLORSTRIP dataset: adds a colored
#                                 strip next to each tip grouping it into
#                                 kansasii complex / MTBC / MAC / M. simiae
#                                 complex
#
# Usage: bash generate_itol_species_labels.sh
# Reads (from gtdb232, hardcoded below): bac120_metadata_r232.tsv,
#   mycobacterium_relevant_species_representative_accessions.txt
# Writes: itol_species_labels.txt, itol_species_colorstrip.txt (same dir)

set -euo pipefail
cd /shares/sander.imm.uzh/MM/kansasii/lit/gtdb/gtdb232

ACCESSIONS_FILE="mycobacterium_relevant_species_representative_accessions.txt"
METADATA="bac120_metadata_r232.tsv"

ACC_COL=$(head -1 "$METADATA" | tr '\t' '\n' | grep -n '^accession$' | cut -d: -f1)
TAX_COL=$(head -1 "$METADATA" | tr '\t' '\n' | grep -n '^gtdb_taxonomy$' | cut -d: -f1)

# accession (prefix stripped) -> GTDB species (s__ token, e.g. "Mycobacterium kansasii")
awk -F'\t' -v OFS='\t' -v acc="$ACC_COL" -v tax="$TAX_COL" '
  NR>1 {
    a = substr($acc, 4)               # strip RS_/GB_ source-flag prefix
    t = $tax
    sub(/.*s__/, "", t)                # keep species token only
    print a, t
  }' "$METADATA" > /tmp/acc_species.$$.tsv

join -t $'\t' <(sort "$ACCESSIONS_FILE") <(sort -t $'\t' -k1,1 /tmp/acc_species.$$.tsv) \
  > /tmp/acc_species_joined.$$.tsv
rm -f /tmp/acc_species.$$.tsv

n_in=$(wc -l < "$ACCESSIONS_FILE")
n_joined=$(wc -l < /tmp/acc_species_joined.$$.tsv)
if [ "$n_in" -ne "$n_joined" ]; then
  echo "WARNING: $n_joined/$n_in accessions matched in $METADATA -- some tips will be unlabeled" >&2
fi

# --- LABELS dataset: rename tip display text to "Species [accession]" ---
{
  echo "LABELS"
  echo "SEPARATOR TAB"
  echo "DATA"
  awk -F'\t' -v OFS='\t' '{print $1, $2 " [" $1 "]"}' /tmp/acc_species_joined.$$.tsv
} > itol_species_labels.txt

# --- DATASET_COLORSTRIP dataset: color by species complex ---
# GTDB species clusters get an _A/_B/_C suffix for within-species clades
# (e.g. colombiense_A); strip it so complex membership matches on the base
# species name.
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
      acc = $1
      sp = $2
      base = sp
      sub(/_[A-Z]$/, "", base)
      if (base ~ /^Mycobacterium (kansasii|persicum|pseudokansasii|innocens|attenuatum|ostraviense|gastri)$/) {
        color = "#4daf4a"; group = "M. kansasii complex"
      } else if (base ~ /^Mycobacterium tuberculosis$/) {
        color = "#e41a1c"; group = "M. tuberculosis complex"
      } else if (base ~ /^Mycobacterium (avium|intracellulare|colombiense|arosiense|marseillense|vulneris)$/) {
        color = "#377eb8"; group = "M. avium complex"
      } else if (base ~ /^Mycobacterium simiae$/) {
        color = "#984ea3"; group = "M. simiae complex"
      } else {
        color = "#999999"; group = "other"
      }
      print acc, color, group
    }' /tmp/acc_species_joined.$$.tsv
} > itol_species_colorstrip.txt

rm -f /tmp/acc_species_joined.$$.tsv

echo "Wrote itol_species_labels.txt and itol_species_colorstrip.txt ($n_joined tips)"
