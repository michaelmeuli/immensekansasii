#!/usr/bin/env bash
# run_downstream.sh - submit every step after the IMMENSE pipeline runs as a Slurm dependency chain
# (steps 2-13 of "Run order" in WORKFLOW.md):
#
#   link table -> MIC analysis ---------------------------------------------------------------+
#              -> MLSA inputs -> locus_discovery(+excluded) -> hsp65 references -> sanger_refalign(hsp65)
#                              -> sanger_mlsa(+excluded), sanger_refalign, genome_identity_check
#   cgMLST scheme + allele calls (00-07) --------------------------------------------------------+
#   results table (needs MIC, sanger_mlsa, sanger_mlsa_excluded, sanger_refalign, cgMLST sample_qc)
#        -> sanger_vs_wgs, hsp65-refalign (01, 04, 05), gyrA-refalign, iTOL, SAMPLES.md
#        -> cgMLST distances / MSTs / Ridom export (08-10), core-SNP MSTs
#   arm (assemblies) -> arm reannotation (needs MIC + results)
#   atypical-sample table and SUMMARY.html (need hsp65-refalign, gyrA-refalign)
#
# Not run here: the pipeline runs (step 5b: finished and copied before), sanger-microsynth (reads and
# sends mail; test it with `scripts/02_analyse_report.py --batch DIR --no-send --no-blast`), the NCBI BLAST
# of hsp65-refalign 02 (sends sequences out) and the GWAS work. Inputs that must exist: data/imm tables, the
# Sanger .ab1 files, the conda envs (env_mic, env_mlsa, env_immense, env_amr, env_cgmlst, env_mst).
#
# Usage: bash run_downstream.sh [--dry-run] [--with-bam]
#   --dry-run   print the sbatch commands only
#   --with-bam  also run the read-mapping arm variant (131+ array tasks, about 1 h each batch)
# Logs: runs/downstream-<date>/   Watch: squeue -u $USER
set -euo pipefail

DRY=0; BAM=0
for a in "$@"; do
  case "$a" in --dry-run) DRY=1 ;; --with-bam) BAM=1 ;; *) echo "unknown option $a" >&2; exit 1 ;; esac
done

source "${KANSASII_ROOT:-/shares/sander.imm.uzh/MM/kansasii}/repos/kansasii-docs/templates/kansasii_paths.sh"
IMM=$REPOS/immensekansasii MLSA=$REPOS/mlsa-kansasii ARM=$REPOS/kansasii-amr-marker-screen
MIC=$REPOS/kansasii-mic MST=$REPOS/kansasii-mst CG=$REPOS/kansasii-cgmlst
HSP=$REPOS/hsp65-refalign GYRA=$REPOS/gyrA-refalign DOCS=$REPOS/kansasii-docs
LOG=$RUNS/downstream-$(date +%Y%m%d)
mkdir -p "$LOG"; cd "$LOG"
# log directories named in the #SBATCH --output lines must exist before sbatch
for d in mlsa mic hsp65_refalign gyrA_refalign arm mst sanger-microsynth; do mkdir -p "$OUTPUT_ROOT/$d/logs"; done
mkdir -p "$RUNS/cgmlst/logs"

CONDA_SH='source "$(conda info --base)/etc/profile.d/conda.sh"'

# submit_wrap NAME ENV DEPS CMD...   -> prints job id
submit_wrap () {
  local name=$1 env=$2 deps=$3; shift 3
  local dep=(); [[ -n "$deps" ]] && dep=(--dependency="afterok:$deps" --kill-on-invalid-dep=yes)
  local cmd="set -euo pipefail; $CONDA_SH; conda activate $env; export KANSASII_ROOT=$ROOT; $*"
  if (( DRY )); then echo "[dry] sbatch -J $name ${dep[*]:-} :: $*" >&2; echo "J_$name"; return; fi
  sbatch --parsable -J "$name" -o "%x-%j.log" --cpus-per-task=2 --mem=8G --time=02:00:00 "${dep[@]}" \
    --wrap "bash -c '$cmd'"
}
# submit_file DEPS FILE [SBATCH_ARGS...] [-- SCRIPT_ARGS...]  -> prints job id (the file carries its own #SBATCH resources)
submit_file () {
  local deps=$1 file=$2; shift 2
  local sb=() sc=()
  while [[ $# -gt 0 ]]; do
    if [[ $1 == -- ]]; then shift; sc=("$@"); break; fi
    sb+=("$1"); shift
  done
  local dep=(); [[ -n "$deps" ]] && dep=(--dependency="afterok:$deps" --kill-on-invalid-dep=yes)
  if (( DRY )); then echo "[dry] sbatch ${dep[*]:-} ${sb[*]:-} $file ${sc[*]:-}" >&2; echo "J_$(basename "$file" .sbatch)${sc[0]:-}"; return; fi
  sbatch --parsable --export=ALL "${dep[@]}" "${sb[@]}" "$file" "${sc[@]}"
}
join () { local IFS=:; echo "$*"; }

# 2  link table; 6 MIC (tests first, figures start from empty dirs)
link=$(submit_wrap link env_mic "" "python $IMM/scripts/02_screening_map_link.py")
mic=$(submit_file "$link" "$MIC/submit_mic.sbatch")

# 7  MLSA inputs
prep=$(submit_wrap mlsa-links env_mlsa "$link" \
  "bash $MLSA/scripts/01_download_filter_gtdb.sh; bash $MLSA/scripts/02_link_gtdb_kansasii_complex.sh; bash $MLSA/scripts/03_link_sanger_kansasii.sh")

# 8  MLSA programs (each sbatch file has its own resources and env)
ld=$(submit_file "$prep"  "$MLSA/submit_locus_discovery.sbatch")
ldx=$(submit_file "$prep" "$MLSA/submit_locus_discovery_excluded.sbatch")
hsp65=$(submit_wrap hsp65-refs env_mlsa "$ld" "python $MLSA/scripts/06_make_hsp65_references.py")
sm=$(submit_file "$ld"    "$MLSA/submit_sanger_mlsa.sbatch")
smx=$(submit_file "$ldx"  "$MLSA/submit_sanger_mlsa_excluded.sbatch")
ra=$(submit_file "$prep"  "$MLSA/submit_sanger_refalign.sbatch")
rah=$(submit_file "$hsp65" "$MLSA/submit_hsp65_amplicon_alignment.sbatch")
gic=$(submit_file "$prep" "$MLSA/submit_genome_identity_check.sbatch")

# 12a cgMLST scheme, allele calls and per-genome QC (00-07); needs the previous results table only for species/contamination
cg1=$(submit_file "$link" "$CG/submit_all.sbatch" --export=ALL,STEPS=00:01:02:03:04:05:06:07)

# 9  results table
results=$(submit_wrap results env_mic "$(join "$mic" "$sm" "$smx" "$ra" "$cg1")" \
  "python $IMM/scripts/06_screening_map_results.py")

# 8b/8c  validation that reads the results table
svw=$(submit_file "$(join "$results" "$rah")" "$MLSA/submit_sanger_vs_wgs.sbatch")
hv=$(submit_file "$results" "$HSP/submit_validate.sbatch")
hk=$(submit_file "$(join "$results" "$hsp65")" "$HSP/submit_korean_check.sbatch")
hp=$(submit_file "$hsp65" "$HSP/submit_public.sbatch")
hpp=$(submit_file "$hsp65" "$HSP/submit_public.sbatch" -- persicum)   # hsp65 of the GTDB-persicum samples (gyrA mosaics)
gy=$(submit_file "$(join "$results" "$hv")" "$GYRA/submit_gyrA.sbatch")

# 10 iTOL, 11 samples report
itol=$(submit_wrap itol env_immense "$results" \
  "bash $IMM/scripts/07_generate_itol_species_labels.sh; bash $IMM/scripts/07_generate_itol_species_labels.sh -m samples -p mkan329_")
report=$(submit_wrap samples-report env_mic "$results" "cd $IMM; python scripts/08_mkan329_samples_report.py")

# 12b cgMLST distances / MSTs / Ridom export, core-SNP MSTs
cg2=$(submit_file "$results" "$CG/submit_all.sbatch" --export=ALL,STEPS=08:09:10)
mst=$(submit_file "$results" "$MST/submit_all.sbatch")

# 13 AMR markers: assemblies need nothing but the pipeline runs; reannotation joins MIC + results
arm=$(submit_file "" "$ARM/submit_arm.sbatch")
arm_deps=("$arm" "$mic" "$results")
if (( BAM )); then
  bam_prep=$(submit_wrap arm-bam-prepare env_amr "$arm" "bash $ARM/scripts/run_arm_bam.sh prepare")
  n_samples=$(ls "$ASSEMBLIES" | wc -l)   # array covers every sample
  bam=$(submit_file "$bam_prep" "$ARM/submit_arm_bam.sbatch" --array="0-$((n_samples - 1))%20")
  bam_fin=$(submit_wrap arm-bam-finish env_amr "$bam" "bash $ARM/scripts/run_arm_bam.sh finish")
  arm_deps+=("$bam_fin")
fi
arm_re=$(submit_file "$(join "${arm_deps[@]}")" "$ARM/submit_arm_reannot.sbatch")

# 14 atypical gyrA / hsp65 samples (project and public) and the results overview
atyp=$(submit_wrap atypical env_mlsa "$(join "$hv" "$hk" "$hp" "$hpp" "$gy")" \
  "python $DOCS/bin/make_atypical_table.py; python $DOCS/bin/make_summary.py")

echo
echo "submitted; logs in $LOG"
echo "  link=$link mic=$mic prep=$prep ld=$ld ldx=$ldx hsp65=$hsp65 cg1=$cg1"
echo "  sm=$sm smx=$smx ra=$ra rah=$rah gic=$gic results=$results"
echo "  svw=$svw hsp65_validate=$hv korean=$hk public=$hp public_persicum=$hpp gyrA=$gy itol=$itol report=$report"
echo "  cg2=$cg2 mst=$mst arm=$arm arm_reannot=$arm_re atypical=$atyp"
