#!/usr/bin/env bash
# CheckM for public samples that have an assembly but no CheckM result.
# The pipeline submits `checkm` only for samples MetaPhlAn4 classifies as bacteria (main.nf, samples_to_run_checkM_ch),
# so a sample whose metaphlan4 task failed, or whose profile is 100 % UNCLASSIFIED, has no 3_quality/checkM/
# (kansasii-docs/docs/RUNS.md, "Exceptions"). This job runs the command of modules/checkm.nf in the same container
# on every such sample and writes the same files:
#   -> runs/public_<BioProject>/assembly/results/<sample>/3_quality/checkM/{checkm_output.tsv,results/,<sample>_checkm_version.txt}
#      plus checkm_rerun.txt (job id and date: the result does not come from a Nextflow task)
#   -> runs/public_checkm_rerun/{rerun.tsv,MANIFEST.txt} (work dir; one line per sample)
# Samples that already have checkm_output.tsv are skipped, so the job can be submitted again.
# The per-sample summary (3_quality/summary/<sample>.tab) is not rewritten: it keeps `null` in the checkm columns;
# hsp65-refalign and gyrA-refalign read checkm_output.tsv.
# Not part of run_downstream.sh (about 4 min per sample). Afterwards: hsp65-refalign submit_public.sbatch,
# gyrA-refalign submit_gyrA.sbatch, kansasii-docs bin/make_runs_report.py. Submit: sbatch submit_public_checkm.sbatch
#SBATCH --job-name=public-checkm
#SBATCH --cpus-per-task=8
#SBATCH --mem=40G
#SBATCH --time=06:00:00
#SBATCH --output=/shares/sander.imm.uzh/MM/kansasii/output/immensekansasii/logs/%x-%j.log

set -euo pipefail
source "${KANSASII_ROOT:-/shares/sander.imm.uzh/MM/kansasii}/repos/kansasii-docs/templates/kansasii_paths.sh"
REPO=$REPOS/immensekansasii
WORK=$RUNS/public_checkm_rerun
IMAGE=quay.io-biocontainers-checkm-genome-1.2.2--pyhdfd78af_1.img   # conf/container_images.config: checkm
CPUS=${SLURM_CPUS_PER_TASK:-8}
mkdir -p "$WORK"

module load apptainer
CHECKM="apptainer exec -B $WORK $IMMENSE_CONTAINERS/$IMAGE"
version="checkM $($CHECKM checkm -h | grep '...:::' | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')"

log=$WORK/rerun.tsv
[[ -s $log ]] || printf 'date\tjob\tbioproject\tsample\tcompleteness\tcontamination\tstrain_heterogeneity\n' > "$log"
n=0
for project in "${PUBLIC_PROJECTS[@]}"; do
  results=$(public_assemblies "$project")
  for dir in "$results"/*/; do
    id=$(basename "$dir")
    fasta=$dir/1_unicycler/$id.fasta
    target=$dir/3_quality/checkM
    [[ -s $fasta && ! -s $target/checkm_output.tsv ]] || continue
    w=$WORK/$id
    rm -rf "$w"; mkdir -p "$w"
    cp "$fasta" "$w/$id.fasta"
    ( cd "$w"
      $CHECKM checkm lineage_wf --reduced_tree -t "$CPUS" -x fasta "$w" results/ > checkm_output.tsv
      rm -R results/bins
      printf '%s\tquay.io/biocontainers/checkm-genome:1.2.2--pyhdfd78af_1\t%s\t' "$version" "$IMAGE" > "${id}_checkm_version.txt"
      echo "CheckM run outside Nextflow by immensekansasii/submit_public_checkm.sbatch, job ${SLURM_JOB_ID:-none}, $(date -Is)" > checkm_rerun.txt
      rm "$id.fasta" )
    # the result row starts with the bin id; the INFO lines of the same file name the work dir, which ends in the id too
    read -r comp cont het < <(awk -v id="$id" '$1 == id {print $(NF-2), $(NF-1), $NF}' "$w/checkm_output.tsv")
    [[ -n ${cont:-} ]] || { echo "ERROR: no CheckM row for $id in $w/checkm_output.tsv" >&2; exit 1; }
    mkdir -p "$target"
    cp -r "$w"/. "$target"/
    rm -rf "$w"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -Is)" "${SLURM_JOB_ID:-none}" "$project" "$id" "$comp" "$cont" "$het" >> "$log"
    echo "$project $id completeness $comp contamination $cont"
    n=$((n + 1))
  done
done
echo "$n samples"

# provenance (see kansasii-docs/docs/PROVENANCE.md)
bash "$MANIFEST_SCRIPT" "$WORK" "$REPO" submit_public_checkm.sbatch "$RUNS"/public_PRJNA*/assembly/results
echo done
