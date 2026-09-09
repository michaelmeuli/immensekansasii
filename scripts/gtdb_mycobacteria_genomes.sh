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

# gtdb_type_designation_ncbi_taxa is the 5th column in mycobacteriaceae_selected_columns.tsv
awk -F'\t' -v OFS='\t' 'NR==1 || $5=="type strain of species"' \
  mycobacteriaceae_selected_columns.tsv > mycobacteriaceae_type_strains.tsv

SPECIES_PATTERN='s__Mycobacterium (kansasii|persicum|pseudokansasii|innocens|attenuatum|ostraviense|gastri)'
(head -1 mycobacteriaceae_type_strains.tsv; grep -E "$SPECIES_PATTERN" mycobacteriaceae_type_strains.tsv) > kansasii_complex_type_strains.tsv


# Mycobacterium (genus-level, not just family) GTDB species-representative
# genomes, accession only, with the RS_/GB_ source-flag prefix stripped
# (e.g. RS_GCF_002102175.1 -> GCF_002102175.1). Not filtered on type-strain
# designation: GTDB picks the representative by assembly quality, so it's
# often a different (better) genome than the one NCBI flags as the type
# strain -- requiring both conditions at once returns an empty set.
MYCOBACTERIUM_PATTERN='g__Mycobacterium'
awk -F'\t' -v OFS='\t' \
  -v acc="$ACCESSION" -v tax="$TAX_COL" -v gtdbrep="$GTDB_REP_COL" \
  -v pat="$MYCOBACTERIUM_PATTERN" \
  '$tax ~ pat && $gtdbrep == "t" {print $acc}' \
  mycobacteriaceae_rows_metadata.tsv | cut -c4- > mycobacterium_representative_accessions.txt


OUTDIR="/shares/sander.imm.uzh/MM/kansasii/data/gtdb_genomes/Mycobacteriaceae"
CHUNK_SIZE=500
MAX_RETRIES=3

# unlike gtdb-adv-search-genomes.sh, this script isn't split per named
# species -- mycobacteriaceae_selected_columns.tsv already covers the
# whole family, so this loops over accession chunks instead of a
# SPECIES_NAME table. A single ~18.6k-accession request produces a >30GB
# zip that NCBI's server has been failing to assemble ("Internal error
# (invalid zip archive)") partway through validation -- splitting into
# chunks keeps each request well under the size where that happens, and
# means a failed chunk only costs a re-download of that chunk, not
# everything.
download_species() {
  local accfile="mycobacteriaceae_accessions.txt"
  local dest="$OUTDIR"
  local chunkdir="$dest/.accession_chunks"

  # GTDB accessions are prefixed with a 3-char source flag ("RS_"/"GB_")
  # that NCBI's `datasets` CLI doesn't accept -- strip it to get the bare
  # GCA_/GCF_ accession
  tail -n +2 mycobacteriaceae_rows_metadata.tsv | cut -f1 | cut -c4- > "$accfile"

  if [ ! -s "$accfile" ]; then
    echo "SKIP: no accessions found in mycobacteriaceae_rows_metadata.tsv" >&2
    return
  fi

  mkdir -p "$dest" "$chunkdir"
  echo "-- Mycobacteriaceae: downloading $(wc -l < "$accfile") accession(s) in chunks of $CHUNK_SIZE --"
  split -d -a 4 -l "$CHUNK_SIZE" "$accfile" "$chunkdir/chunk_"

  local chunk zip attempt ok
  for chunk in "$chunkdir"/chunk_*; do
    zip="$chunk.zip"
    ok=0
    for attempt in $(seq 1 "$MAX_RETRIES"); do
      echo "-- chunk $(basename "$chunk"): attempt $attempt/$MAX_RETRIES ($(wc -l < "$chunk") accession(s)) --"
      if datasets download genome accession --inputfile "$chunk" --include gff3,genome --filename "$zip" \
        && unzip -o -q "$zip" -d "$dest"; then
        ok=1
        break
      fi
      echo "chunk $(basename "$chunk") failed on attempt $attempt" >&2
      rm -f "$zip"
    done
    if [ "$ok" -ne 1 ]; then
      echo "ERROR: chunk $(basename "$chunk") failed after $MAX_RETRIES attempts" >&2
      return 1
    fi
    rm -f "$zip"
  done
}

download_species


