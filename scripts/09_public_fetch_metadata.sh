#!/usr/bin/env bash
#
# Fetch the ENA read-run metadata of public BioProjects (see PROJECTS.md) into
#   <public_dir>/<BioProject>/metadata.tsv
# One row per run: accessions, species as submitted, strain, country, host,
# collection date, platform, layout, read/base counts, fastq ftp paths + md5.
# 10_public_select_and_download.py reads these tables. Idempotent: a rerun
# overwrites metadata.tsv (ENA is the source of truth; nothing else is touched).
# Needs network only; submits nothing.
#
# Usage: 09_public_fetch_metadata.sh [-o public_dir] BioProject [BioProject ...]

set -euo pipefail

BASE="/shares/sander.imm.uzh/MM/kansasii"
PUBLIC_DIR="$BASE/data/illumina/public"
FIELDS="run_accession,experiment_accession,sample_accession,secondary_sample_accession,study_accession,scientific_name,strain,isolate,instrument_platform,instrument_model,library_strategy,library_source,library_layout,read_count,base_count,country,host,collection_date,sample_title,fastq_md5,fastq_ftp"

while getopts ":o:" opt; do
  case $opt in
    o) PUBLIC_DIR=$OPTARG ;;
    *) sed -n '/^# Usage/,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
[ $# -ge 1 ] || { sed -n '/^# Usage/,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

for p in "$@"; do
  dir="$PUBLIC_DIR/$p"
  mkdir -p "$dir"
  tmp=$(mktemp "$dir/metadata.XXXXXX")
  curl -sf -m 120 "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=$p&result=read_run&fields=$FIELDS&format=tsv" > "$tmp" \
    || { rm -f "$tmp"; echo "ERROR: ENA request failed for $p" >&2; exit 1; }
  n=$(( $(wc -l < "$tmp") - 1 ))
  [ "$n" -gt 0 ] || { rm -f "$tmp"; echo "ERROR: no runs returned for $p" >&2; exit 1; }
  mv "$tmp" "$dir/metadata.tsv"
  echo "$p: $n runs -> $dir/metadata.tsv"
  sleep 1
done
