#!/usr/bin/env bash
#
# Split the downloaded reads of one public BioProject into a small "test" batch
# and fixed-size batches, in selected.tsv order, and print the run_IMMENSE.sh
# command for each. Counterpart of 04_mkan329_batches.sh for the reads fetched
# by 09/10 (<public_dir>/<BioProject>/{selected.tsv,reads/}).
#
#   <public_dir>/<BioProject>/batches/test   first -t samples (pilot, own run dir + snippy db)
#   <public_dir>/<BioProject>/batches/b01..  -b samples each (b01 starts at the first
#                                            sample again, so the pilot samples are re-run:
#                                            the pilot db never ends up in the real tree)
#
# Each batch dir is flat: symlinks <sample_id>_R1.fastq.gz / _R2.fastq.gz + id_map.tsv
# (sample_id, biosample, species as submitted, original paths). The sample id is the ENA run
# accession (never a bare number, see 10_public_select_and_download.py).
#
# One run id per BioProject (public_<BioProject>): test goes to public_<BioProject>_test,
# b01..bNN share runs/public_<BioProject>/ and its snippy db. Submit them one after another
# (Nextflow allows one run per dir). Samples whose reads are missing are skipped with a
# warning, so rerun this script after the download has finished. Batches are rebuilt from
# scratch each time, so only rerun it before submitting.
#
# The snippy db dir must exist before the run (kansasii_phylo.nf bind-mounts it), hence the
# mkdir -p in the printed commands. This script only builds links and prints commands.
#
# Usage: 11_public_batches.sh [-o public_dir] [-t test_size] [-b batch_size] BioProject

set -euo pipefail

BASE="/shares/sander.imm.uzh/MM/kansasii"
PUBLIC_DIR="$BASE/data/illumina/public"
TEST_SIZE=3
BATCH_SIZE=45
RUN_IMMENSE="$BASE/repos/immensekansasii/run_IMMENSE.sh"
DB_ROOT="/shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/kansasii_complex"

while getopts ":o:t:b:" opt; do
  case $opt in
    o) PUBLIC_DIR=$OPTARG ;;
    t) TEST_SIZE=$OPTARG ;;
    b) BATCH_SIZE=$OPTARG ;;
    *) sed -n '/^# Usage/,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
[ $# -eq 1 ] || { sed -n '/^# Usage/,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
PROJ=$1
PDIR="$PUBLIC_DIR/$PROJ"
SELECTED="$PDIR/selected.tsv"
BATCHES_DIR="$PDIR/batches"
[ -f "$SELECTED" ] || { echo "ERROR: $SELECTED missing, run 10_public_select_and_download.py first" >&2; exit 1; }

declare -A COUNT
batch_dir=""; cur=""; n_in_batch=0; n_batch=0

start_batch() {  # $1 = name
  cur=$1
  batch_dir="$BATCHES_DIR/$cur"
  rm -rf "$batch_dir"
  mkdir -p "$batch_dir"
  printf 'sample_id\tbiosample\tscientific_name\toriginal_path_R1\toriginal_path_R2\n' > "$batch_dir/id_map.tsv"
  COUNT[$cur]=0
  n_in_batch=0
}

add_sample() {  # sample_id biosample species r1 r2  (to the current batch)
  ln -sfn "$4" "$batch_dir/${1}_R1.fastq.gz"
  ln -sfn "$5" "$batch_dir/${1}_R2.fastq.gz"
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" >> "$batch_dir/id_map.tsv"
  COUNT[$cur]=$(( COUNT[$cur] + 1 ))
  n_in_batch=$(( n_in_batch + 1 ))
}

# Pass 1: samples with both read files present (selected.tsv columns: see 10_...py)
header=$(head -1 "$SELECTED")
col() { echo "$header" | tr '\t' '\n' | grep -nx "$1" | cut -d: -f1; }
c_id=$(col sample_id); c_bs=$(col biosample); c_sp=$(col scientific_name); c_r1=$(col R1); c_r2=$(col R2)
samples=()
# awk (not read with IFS=tab): empty columns such as strain/host must not collapse
while IFS='|' read -r id bs sp r1 r2; do
  if [ ! -s "$r1" ] || [ ! -s "$r2" ]; then
    echo "WARNING: reads missing for $id, skipped" >&2
    continue
  fi
  samples+=("$id|$bs|$sp|$r1|$r2")
done < <(awk -F'\t' -v OFS='|' -v a="$c_id" -v b="$c_bs" -v c="$c_sp" -v d="$c_r1" -v e="$c_r2" 'NR>1{print $a,$b,$c,$d,$e}' "$SELECTED")
echo "${#samples[@]} samples with reads" >&2

# Pass 2: test batch = first TEST_SIZE, then consecutive batches over all
mkdir -p "$BATCHES_DIR"
rm -rf "$BATCHES_DIR"/b[0-9][0-9]
start_batch test
for s in "${samples[@]:0:TEST_SIZE}"; do IFS='|' read -r id bs sp r1 r2 <<< "$s"; add_sample "$id" "$bs" "$sp" "$r1" "$r2"; done

order=(test)
for s in "${samples[@]}"; do
  IFS='|' read -r id bs sp r1 r2 <<< "$s"
  if [ "$cur" = test ] || [ "$n_in_batch" -ge "$BATCH_SIZE" ]; then
    n_batch=$(( n_batch + 1 ))
    start_batch "$(printf 'b%02d' "$n_batch")"
    order+=("$cur")
  fi
  add_sample "$id" "$bs" "$sp" "$r1" "$r2"
done

echo
for b in "${order[@]}"; do
  echo "$b: ${COUNT[$b]} samples"
done
echo
echo "# Commands. test = pilot (own run dir and db). The rest share runs/public_$PROJ."
echo "# Submit b01..bNN one after another (wait for each to finish)."
for b in "${order[@]}"; do
  if [ "$b" = test ]; then run="public_${PROJ}_test"; else run="public_$PROJ"; fi
  db="$DB_ROOT/$run"
  echo "mkdir -p $db $BASE/runs/$run \\"
  echo "  && cd $BASE/runs/$run \\"
  echo "  && bash $RUN_IMMENSE -j job_public_${PROJ}_$b -t fq_PE -r $run \\"
  echo "       -x \"--kansasii_snippy_db $db\" -i $BATCHES_DIR/$b"
done
