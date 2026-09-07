#!/usr/bin/env bash

# srun --pty -n 1 -c 6 --time=01:00:00 --mem=16G bash -l

set -euo pipefail
mkdir -p /shares/sander.imm.uzh/MM/kansasii/lit/gtdb/gtdb232
cd /shares/sander.imm.uzh/MM/kansasii/lit/gtdb/gtdb232

if [ ! -f bac120_metadata_r232.tsv ]; then
  wget https://data.gtdb.aau.ecogenomic.org/releases/release232/232.0/bac120_metadata_r232.tsv.gz
  gunzip bac120_metadata_r232.tsv.gz
fi

# SPECIES_PATTERN='s__Mycobacterium (kansasii|persicum|pseudokansasii|innocens|attenuatum|ostraviense|gastri)'
# grep -E "$SPECIES_PATTERN" bac120_metadata_r232.tsv > kansasii_complex_rows_metadata.tsv

MYCOBACTERIACEAE='f__Mycobacteriaceae'
(head -1 bac120_metadata_r232.tsv; grep -F "$MYCOBACTERIACEAE" bac120_metadata_r232.tsv) > mycobacteriaceae_rows_metadata.tsv


ACCESSION=$(head -1 bac120_metadata_r232.tsv | tr '\t' '\n' | grep -n '^accession$' | cut -d: -f1)
REPR_COL=$(head -1 bac120_metadata_r232.tsv | tr '\t' '\n' | grep -n '^gtdb_genome_representative$' | cut -d: -f1)
GTDB_REP_COL=$(head -1 bac120_metadata_r232.tsv | tr '\t' '\n' | grep -n '^gtdb_representative$' | cut -d: -f1)   # t or f
TAX_COL=$(head -1 bac120_metadata_r232.tsv | tr '\t' '\n' | grep -n '^gtdb_taxonomy$' | cut -d: -f1)
GTDBTYPE_COL=$(head -1 bac120_metadata_r232.tsv | tr '\t' '\n' | grep -n '^gtdb_type_designation_ncbi_taxa$' | cut -d: -f1)
ASSEMNAME_COL=$(head -1 bac120_metadata_r232.tsv | tr '\t' '\n' | grep -n '^ncbi_assembly_name$' | cut -d: -f1)
BIOSAMPLE_COL=$(head -1 bac120_metadata_r232.tsv | tr '\t' '\n' | grep -n '^ncbi_biosample$' | cut -d: -f1)
NCBITYPE_COL=$(head -1 bac120_metadata_r232.tsv | tr '\t' '\n' | grep -n '^ncbi_type_material_designation$' | cut -d: -f1)

# NB: use awk with field-index variables here, not `cut -f...` -- cut
# always emits fields in ascending column-number order regardless of the
# order listed, so pulling several out-of-order columns that way silently
# mismatches which value lands in which position. Applying this to every
# row (header included) reproduces the correct header text for free, since
# the header row's own fields are the column names.
awk -F'\t' -v OFS='\t' \
  -v acc="$ACCESSION" -v repr="$REPR_COL" -v gtdbrep="$GTDB_REP_COL" \
  -v tax="$TAX_COL" -v gtype="$GTDBTYPE_COL" -v an="$ASSEMNAME_COL" \
  -v bs="$BIOSAMPLE_COL" -v ntype="$NCBITYPE_COL" \
  '{print $acc, $repr, $gtdbrep, $tax, $gtype, $an, $bs, $ntype}' \
  mycobacteriaceae_rows_metadata.tsv > mycobacteriaceae_selected_columns.tsv


OUTDIR="/shares/sander.imm.uzh/MM/kansasii/data/gtdb_genomes/Mycobacteriaceae"

# unlike gtdb-adv-search-genomes.sh, this script isn't split per named
# species -- mycobacteriaceae_selected_columns.tsv already covers the
# whole family, so this downloads it as a single batch instead of looping
# over a SPECIES_NAME table
download_species() {
  local accfile="mycobacteriaceae_accessions.txt"
  local dest="$OUTDIR"

  # GTDB accessions are prefixed with a 3-char source flag ("RS_"/"GB_")
  # that NCBI's `datasets` CLI doesn't accept -- strip it to get the bare
  # GCA_/GCF_ accession
  tail -n +2 mycobacteriaceae_rows_metadata.tsv | cut -f1 | cut -c4- > "$accfile"

  if [ ! -s "$accfile" ]; then
    echo "SKIP: no accessions found in mycobacteriaceae_selected_columns.tsv" >&2
    return
  fi

  mkdir -p "$dest"
  echo "-- Mycobacteriaceae: downloading $(wc -l < "$accfile") accession(s) --"
  datasets download genome accession --inputfile "$accfile" --include gff3,genome --filename "$dest/mycobacteriaceae.zip"
  unzip -o -q "$dest/mycobacteriaceae.zip" -d "$dest"
}

download_species


