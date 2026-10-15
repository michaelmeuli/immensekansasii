#!/usr/bin/env bash
#
# Build one extra batch (default b05) from the jc-sequenced reads, which are
# delivered under their NGS TNR (reads/kansasii_jc/2023187xxx_R1/R2.fastq.gz),
# not under Mkan329-NNN. The NGS TNR -> PROBENNUMMER mapping is the NGS_JC
# column of screening_map_link.csv (written by 02_screening_map_link.py from
# screening_map_ngs_jc.csv).
#
# The batch dir has the same layout as the ones from 04_mkan329_batches.sh: flat
# symlinks <PROBENNUMMER>_R1.fastq.gz / _R2.fastq.gz (upper-case, see there)
# + id_map.tsv (NR, PROBENNUMMER, original paths), in NR order.
#
# Samples listed in -x are skipped. By default Mkan329-009 and Mkan329-056:
# they were already sequenced in the main run (reads/kansasii, b01/b02), and
# the same sample id with different reads would clash in the shared
# runs/mkan329 results and snippy db.
#
# The batch dir is rebuilt from scratch. 04_mkan329_batches.sh removes every
# b[0-9][0-9] dir, so rerun this script after it.
#
# This script only builds the links and prints the run command; it submits
# nothing.
#
# -I limits the batch to the listed PROBENNUMMER (default: all). -s appends a
# suffix to the sample id of the links (e.g. -s -jc gives Mkan329-056-jc), so a
# resequenced sample does not clash with the same id from the main run. -R sets
# the run id (run dir runs/<R>, snippy db <R>); give a separate one (e.g.
# -R mkan329_jc) when the samples must stay out of the shared mkan329 tree.
# Example (b06, resequenced 2023187866 = Mkan329-056 and 2023187902 = Mkan329-009):
#   05_mkan329_batch_jc.sh -o .../batches/b06 -I "Mkan329-056 Mkan329-009" -x "" -s -jc -R mkan329_jc
#
# Usage: 05_mkan329_batch_jc.sh [-r reads_dir] [-m link_csv] [-c ngs_column]
#                            [-o batch_dir] [-x "id id ..."] [-I "id id ..."]
#                            [-s id_suffix] [-R run_id]

set -euo pipefail

BASE="/shares/sander.imm.uzh/MM/kansasii"
READS_DIR="$BASE/data/illumina/Mkan329/reads/kansasii_jc"
LINK_CSV="$BASE/data/imm/screening_map_link.csv"
NGS_COL="NGS_JC"
BATCH_DIR="$BASE/data/illumina/Mkan329/batches/b05"
EXCLUDE="Mkan329-009 Mkan329-056"
INCLUDE=""
SUFFIX=""
RUN_ID="mkan329"
RUN_IMMENSE="$BASE/repos/immensekansasii/run_IMMENSE.sh"
DB_ROOT="/shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/kansasii_complex"

while getopts ":r:m:c:o:x:I:s:R:" opt; do
  case $opt in
    r) READS_DIR=$OPTARG ;;
    m) LINK_CSV=$OPTARG ;;
    c) NGS_COL=$OPTARG ;;
    o) BATCH_DIR=$OPTARG ;;
    x) EXCLUDE=$OPTARG ;;
    I) INCLUDE=$OPTARG ;;
    s) SUFFIX=$OPTARG ;;
    R) RUN_ID=$OPTARG ;;
    *) sed -n '/^# Usage/,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
  esac
done

# NR, PROBENNUMMER, NGS id of the wanted column (CSV has no quoted commas)
rows=$(awk -F, -v col="$NGS_COL" '
  NR == 1 { for (i = 1; i <= NF; i++) if ($i == col) c = i
            if (!c) { print "column " col " not found in header" > "/dev/stderr"; exit 1 }
            next }
  $c != "" { print $1 "\t" $2 "\t" $c }' "$LINK_CSV")

mkdir -p "$BATCH_DIR"
find "$BATCH_DIR" -maxdepth 1 \( -type l -o -name id_map.tsv \) -delete
printf 'NR\tPROBENNUMMER\toriginal_path_R1\toriginal_path_R2\n' > "$BATCH_DIR/id_map.tsv"

n=0
while IFS=$'\t' read -r nr pnr ngs; do
  case " $EXCLUDE " in *" $pnr "*) echo "skip $pnr (excluded)" >&2; continue ;; esac
  if [ -n "$INCLUDE" ]; then case " $INCLUDE " in *" $pnr "*) ;; *) continue ;; esac; fi
  id="${pnr}${SUFFIX}"
  r1="$READS_DIR/${ngs}_R1.fastq.gz"; r2="$READS_DIR/${ngs}_R2.fastq.gz"
  if [ ! -e "$r1" ] || [ ! -e "$r2" ]; then
    echo "WARNING: no complete fastq pair for $pnr ($ngs), skipped" >&2
    continue
  fi
  ln -sfn "$r1" "$BATCH_DIR/${id}_R1.fastq.gz"
  ln -sfn "$r2" "$BATCH_DIR/${id}_R2.fastq.gz"
  printf '%s\t%s\t%s\t%s\n' "$nr" "$id" "$r1" "$r2" >> "$BATCH_DIR/id_map.tsv"
  n=$(( n + 1 ))
done <<< "$rows"

echo "$BATCH_DIR: $n samples" >&2
echo
echo "# Command (run id $RUN_ID: run dir runs/$RUN_ID and snippy db $RUN_ID; run after earlier batches of the same run id finished):"
echo "mkdir -p $DB_ROOT/$RUN_ID $BASE/runs/$RUN_ID \\"
echo "  && cd $BASE/runs/$RUN_ID \\"
echo "  && bash $RUN_IMMENSE -j job_${RUN_ID}_$(basename "$BATCH_DIR") -t fq_PE -r $RUN_ID \\"
echo "       -x \"--kansasii_snippy_db $DB_ROOT/$RUN_ID\" -i $BATCH_DIR"
