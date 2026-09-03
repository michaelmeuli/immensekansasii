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



