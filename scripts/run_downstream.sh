#!/usr/bin/env bash
# run_downstream.sh - submit every step after the IMMENSE pipeline runs as a Slurm
# dependency chain (steps 6-13 of "Run order" in WORKFLOW.md):
#
#   link table -> MIC analysis ----------------------------+
#              -> MLSA inputs -> main1(+excluded) -> hsp65 references -> main3(hsp65)
#                              -> main2(+excluded), main3, genome_identity_check
#   results table (needs MIC, main2, main2_excluded, main3) -> main4, iTOL, SAMPLES.md, gwas
#   results table -> mst figures
#   arm (assemblies) -> arm reannotation (needs MIC + results)
#
# Prerequisites (not run here): the pipeline runs of step 5b are finished and copied, data/imm
# input tables and the Sanger .ab1 files are in place, conda envs exist.
#
# Usage: bash run_downstream.sh [--dry-run] [--with-bam]
#   --dry-run   print the sbatch commands only
#   --with-bam  also run the read-mapping arm variant (131+ array tasks, about 1 h each batch)
# Logs: $ROOT/runs/downstream-<date>/   Watch: squeue -u $USER
set -euo pipefail

DRY=0; BAM=0
for a in "$@"; do
  case "$a" in --dry-run) DRY=1 ;; --with-bam) BAM=1 ;; *) echo "unknown option $a" >&2; exit 1 ;; esac
done

ROOT=${KANSASII_ROOT:-/shares/sander.imm.uzh/MM/kansasii}
R=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
IMM=$R/immensekansasii MIC=$R/kansasii-mic MLSA=$R/mlsa-kansasii GWAS=$R/kansasii-gwas ARM=$R/kansasii-amr-marker-screen MST=$R/kansasii-mst
MANIFEST=$R/kansasii-docs/bin/write_manifest.sh
LOG=$ROOT/runs/downstream-$(date +%Y%m%d)
mkdir -p "$LOG"; cd "$LOG"

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
# submit_file DEPS FILE [SBATCH_ARGS...]  -> prints job id (the file carries its own #SBATCH resources)
submit_file () {
  local deps=$1 file=$2; shift 2
  local dep=(); [[ -n "$deps" ]] && dep=(--dependency="afterok:$deps" --kill-on-invalid-dep=yes)
  if (( DRY )); then echo "[dry] sbatch ${dep[*]:-} $file" >&2; echo "J_$(basename "$file" .sbatch)"; return; fi
  sbatch --parsable --export=ALL "${dep[@]}" "$@" "$file"
}
join () { local IFS=:; echo "$*"; }

# 2  link table, 6 MIC (tests first), figures start from an empty dir
link=$(submit_wrap link kansasii_mic "" "python $IMM/scripts/02_screening_map_link.py")
mic=$(submit_wrap mic kansasii_mic "$link" \
  "cd $MIC; MPLBACKEND=Agg pytest -q tests; rm -rf $ROOT/output/mic/mhk $ROOT/output/mic/mgit; MPLBACKEND=Agg python scripts/run_analysis.py --mic-csv $ROOT/data/imm/mic.csv --screening-map $ROOT/data/imm/screening_map_link.csv --ast-jc $ROOT/data/imm/screening_map_ast_jc.csv --out-dir $ROOT/output/mic; bash $MANIFEST $ROOT/output/mic $MIC run_analysis.py $ROOT/data/imm/mic.csv $ROOT/data/imm/screening_map_link.csv")

# 7  MLSA inputs
prep=$(submit_wrap mlsa-links env_mlsa "$link" \
  "bash $MLSA/scripts/01_download_filter_gtdb.sh; bash $MLSA/scripts/02_link_gtdb_kansasii_complex.sh; bash $MLSA/scripts/03_link_sanger_kansasii.sh")

# 8  MLSA programs (each sbatch file has its own resources and env)
main1=$(submit_file "$prep"  "$MLSA/main1_locus_discovery/submit_locus_discovery.sbatch")
main1x=$(submit_file "$prep" "$MLSA/main1_locus_discovery_excluded/submit_locus_discovery_excluded.sbatch")
hsp65=$(submit_wrap hsp65-refs env_mlsa "$main1" "python $MLSA/scripts/04_make_hsp65_references.py")
main2=$(submit_file "$main1"  "$MLSA/main2_sanger_differentiation/submit_sanger_differentiation.sbatch")
main2x=$(submit_file "$main1x" "$MLSA/main2_sanger_differentiation_excluded/submit_sanger_differentiation_excluded.sbatch")
main3=$(submit_file "$prep"  "$MLSA/main3_reference_alignment/submit_reference_alignment.sbatch")
main3h=$(submit_file "$hsp65" "$MLSA/main3_reference_alignment/submit_hsp65_amplicon_alignment.sbatch")
gic=$(submit_file "$prep"    "$MLSA/genome_identity_check/submit_genome_identity_check.sbatch")

# 9  results table
results=$(submit_wrap results kansasii_mic "$(join "$mic" "$main2" "$main2x" "$main3")" \
  "python $IMM/scripts/06_screening_map_results.py")

# 8b main4 reads the results table; 10 iTOL; 11 samples report
main4=$(submit_file "$(join "$results" "$main3h")" "$MLSA/main4_hsp65_vs_wgs/submit_hsp65_vs_wgs.sbatch")
itol=$(submit_wrap itol env_immense "$results" \
  "bash $IMM/scripts/07_generate_itol_species_labels.sh; bash $IMM/scripts/07_generate_itol_species_labels.sh -m samples -p mkan329_")
report=$(submit_wrap samples-report kansasii_mic "$results" "cd $IMM; python scripts/08_mkan329_samples_report.py")

# 12b core-SNP MST figures (kansasii-mst; reads the results table)
mst=$(submit_file "$results" "$MST/run_all.sbatch")

# 12 genotype vs MIC
gwas=$(submit_file "$(join "$results" "$mic")" "$GWAS/run_all.sbatch")

# 13 AMR markers: assemblies need nothing but the pipeline runs; reannotation joins MIC + results
arm=$(submit_file "" "$ARM/submit_arm.sbatch")
arm_deps=("$arm" "$mic" "$results")
if (( BAM )); then
  bam_prep=$(submit_wrap arm-bam-prepare env_arm "$arm" "bash $ARM/run_arm_bam.sh prepare")
  n_samples=$(ls "$ROOT/runs/mkan329/assembly/results" | wc -l)   # array covers every sample
  bam=$(submit_file "$bam_prep" "$ARM/submit_arm_bam.sbatch" --array="0-$((n_samples - 1))%20")
  bam_fin=$(submit_wrap arm-bam-finish env_arm "$bam" "bash $ARM/run_arm_bam.sh finish")
  arm_deps+=("$bam_fin")
fi
arm_re=$(submit_file "$(join "${arm_deps[@]}")" "$ARM/submit_arm_reannot.sbatch")

echo
echo "submitted; logs in $LOG"
echo "  link=$link mic=$mic prep=$prep main1=$main1 main1x=$main1x hsp65=$hsp65"
echo "  main2=$main2 main2x=$main2x main3=$main3 main3h=$main3h gic=$gic"
echo "  results=$results main4=$main4 itol=$itol report=$report gwas=$gwas mst=$mst arm=$arm arm_reannot=$arm_re"
