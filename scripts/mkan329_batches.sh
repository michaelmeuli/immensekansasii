#!/usr/bin/env bash
#
# Split the Mkan329 paired-end reads into a small "test" batch, fixed-size
# batches and one "all" batch, in NR order (first column of
# screening_map_link.csv), and print the run_IMMENSE.sh command for each.
#
#   <batches_dir>/test/            first -t samples by NR (pilot, own run dir + snippy db)
#   <batches_dir>/b01, b02, ...    -b samples each, by NR (b01 starts at the first
#                                  sample again, so the pilot samples are re-run
#                                  there: ~2% extra compute, and the pilot db
#                                  never ends up in the real tree)
#   <batches_dir>/all/             every sample with a complete pair
#
# Each batch dir is flat: symlinks <PROBENNUMMER>_R1.fastq.gz /
# <PROBENNUMMER>_R2.fastq.gz (the sample id is Mkan329-NNN) + id_map.tsv
# (NR, PROBENNUMMER, original paths). The delivered files are named
# Mkan329-NNN_r1.fastq.gz (lower case); the links get the upper-case _R1/_R2
# that main.nf's {R1,R2,1,2} glob needs. Do NOT use the bare NR as sample id
# (scripts/run.sh's old short ids): checkm.nf does `grep ${sample_id}` on the
# CheckM log, a bare number matches almost every line (timestamps) and
# garbles <run>_quality.tsv (evaluate_QC.py then crashes). Samples without a complete pair
# (not delivered yet) are skipped with a warning, so rerunning this script
# after the next delivery just fills in the gaps (batches are rebuilt from
# scratch each time, so membership can shift -- only rerun it before submitting).
#
# One run dir for the real run: b01..bNN and all go through the same
# runs/mkan329/ with the same run id (mkan329) and snippy db (mkan329). Per-
# sample results (assembly/results/<NR>/) and the snippy db accumulate, and
# -resume (bin/submit_to_cluster.sh) reuses the finished samples, but
# mkan329_quality.tsv and the other tables in mkan329_transfer_result/ only
# cover the samples of the latest invocation. So: run the batches one after
# another (Nextflow allows one run per dir), and finish with "all", which
# rebuilds those tables and the tree over every sample.
#
# This script only builds the links and prints the commands; it submits nothing.
#
# Usage: mkan329_batches.sh [-r reads_dir] [-m link_csv] [-o batches_dir]
#                           [-t test_size] [-b batch_size]

set -euo pipefail

BASE="/shares/sander.imm.uzh/MM/kansasii"
READS_DIR="$BASE/data/illumina/Mkan329/reads/kansasii"
LINK_CSV="$BASE/data/imm/screening_map_link.csv"
BATCHES_DIR="$BASE/data/illumina/Mkan329/batches"
TEST_SIZE=3
BATCH_SIZE=45
RUN_IMMENSE="$BASE/repos/immensekansasii/run_IMMENSE.sh"
DB_ROOT="/shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/kansasii_complex"

while getopts ":r:m:o:t:b:" opt; do
  case $opt in
    r) READS_DIR=$OPTARG ;;
    m) LINK_CSV=$OPTARG ;;
    o) BATCHES_DIR=$OPTARG ;;
    t) TEST_SIZE=$OPTARG ;;
    b) BATCH_SIZE=$OPTARG ;;
    *) sed -n '/^# Usage/,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
  esac
done

find_read() {  # $1 = PROBENNUMMER, $2 = 1|2 ; accepts _r1 / _R1 / _1
  find "$READS_DIR" -maxdepth 1 \( -iname "$1_r$2.f*q.gz" -o -iname "$1_$2.f*q.gz" \) | sort | head -1
}

# batch name -> sample count, filled below
declare -A COUNT
batch_dir=""
cur=""
n_in_batch=0
n_batch=0
n_total=0

start_batch() {  # $1 = name
  cur=$1
  batch_dir="$BATCHES_DIR/$cur"
  rm -rf "$batch_dir"
  mkdir -p "$batch_dir"
  printf 'NR\tPROBENNUMMER\toriginal_path_R1\toriginal_path_R2\n' > "$batch_dir/id_map.tsv"
  COUNT[$cur]=0
  n_in_batch=0
}

add_sample() {  # $1 = NR, $2 = PROBENNUMMER, $3 = r1, $4 = r2  (to the current batch)
  ln -sfn "$3" "$batch_dir/${2}_R1.fastq.gz"
  ln -sfn "$4" "$batch_dir/${2}_R2.fastq.gz"
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$batch_dir/id_map.tsv"
  COUNT[$cur]=$(( COUNT[$cur] + 1 ))
  n_in_batch=$(( n_in_batch + 1 ))
}

# Pass 1: NR-ordered list of samples that have a complete pair
samples=()
while IFS=, read -r nr pnr _; do
  [ "$nr" = "NR" ] && continue
  r1=$(find_read "$pnr" 1); r2=$(find_read "$pnr" 2)
  if [ -z "$r1" ] || [ -z "$r2" ]; then
    echo "WARNING: no complete fastq pair for $pnr (NR $nr), skipped" >&2
    continue
  fi
  samples+=("$nr	$pnr	$r1	$r2")
done < "$LINK_CSV"
echo "${#samples[@]} samples with a complete pair" >&2

# Pass 2: test batch = first TEST_SIZE, then consecutive batches over all
mkdir -p "$BATCHES_DIR"
rm -rf "$BATCHES_DIR"/b[0-9][0-9]   # stale batches from an earlier -b (only symlinks + id_map.tsv)
start_batch test
for s in "${samples[@]:0:TEST_SIZE}"; do IFS=$'\t' read -r nr pnr r1 r2 <<< "$s"; add_sample "$nr" "$pnr" "$r1" "$r2"; done

order=(test)
for s in "${samples[@]}"; do
  IFS=$'\t' read -r nr pnr r1 r2 <<< "$s"
  if [ "$cur" = test ] || [ "$n_in_batch" -ge "$BATCH_SIZE" ]; then
    n_batch=$(( n_batch + 1 ))
    start_batch "$(printf 'b%02d' "$n_batch")"
    order+=("$cur")
  fi
  add_sample "$nr" "$pnr" "$r1" "$r2"
done

# "all" batch: every sample, for the final cumulative run
start_batch all
for s in "${samples[@]}"; do IFS=$'\t' read -r nr pnr r1 r2 <<< "$s"; add_sample "$nr" "$pnr" "$r1" "$r2"; done
order+=(all)

# Report + commands
echo
for b in "${order[@]}"; do
  first=$(sed -n 2p "$BATCHES_DIR/$b/id_map.tsv" | cut -f1)
  last=$(tail -n 1 "$BATCHES_DIR/$b/id_map.tsv" | cut -f1)
  echo "$b: ${COUNT[$b]} samples (NR $first..$last)"
done
echo
echo "# Commands. test = pilot (own run dir and db). The rest share runs/mkan329:"
echo "# submit b01..bNN one after another (wait for each to finish), then all."
for b in "${order[@]}"; do
  if [ "$b" = test ]; then run="mkan329_test"; else run="mkan329"; fi
  db="$DB_ROOT/$run"
  echo "mkdir -p $BASE/runs/$run \\"
  echo "  && cd $BASE/runs/$run \\"
  echo "  && bash $RUN_IMMENSE -j job_mkan329_$b -t fq_PE -r $run \\"
  echo "       -x \"--kansasii_snippy_db $db\" -i $BATCHES_DIR/$b"
done
