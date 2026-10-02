

# Every one of these accessions is itself a GTDB-Tk reference genome, so
# gtdbtk_classify_wf rejects them outright as query input ("You have N
# genomes with the same id as GTDB-Tk reference genomes, please rename
# them."). kansasii_complex_gtdb_representative_accessions_renamed.txt
# (built in gtdb_mycobacteria_genomes.sh) pairs each accession with a
# "_query"-suffixed id; symlink under the renamed id so the destination
# filename -- which is what gtdbtk/Channel.fromFilePairs key tips off --
# no longer collides.
#
# Feeding this SELECTED_DIR into run_IMMENSE.sh with -t fasta runs
# kansasii_phylo.nf and produces a tree (kansasii_complex_tree.treefile)
# with tip labels = renamed ids (accession + "_query") -- see
# scripts/generate_itol_species_labels.sh for turning those into iTOL
# species-name annotations after upload (its default accessions file is this
# same kansasii_complex list; -a selects another one).
ACCESSIONS_FILE="/shares/sander.imm.uzh/MM/kansasii/output/lit/gtdb/gtdb232/kansasii_complex_gtdb_representative_accessions_renamed.txt"
GENOME_DATA_DIR="/shares/sander.imm.uzh/MM/kansasii/data/gtdb_genomes/Mycobacteriaceae/ncbi_dataset/data"
SELECTED_DIR="/shares/sander.imm.uzh/MM/kansasii/data/gtdb_genomes/Mycobacteriaceae/kansasii_complex_gtdb_representatives"
SNIPPY_DB_DIR="/shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/kansasii_complex/kansasii_complex_gtdb_representatives"
RUN_DIR="/shares/sander.imm.uzh/MM/kansasii/runs/kansasii_complex_gtdb_representatives"

mkdir -p "$SELECTED_DIR"
mkdir -p "$SNIPPY_DB_DIR"
mkdir -p "$RUN_DIR"
while read -r acc renamed; do
  [ -z "$acc" ] && continue
  src=$(find "$GENOME_DATA_DIR/$acc" -maxdepth 1 \( -name '*.fna' -o -name '*.fasta' \) | head -1)
  if [ -z "$src" ]; then
    echo "WARNING: no fasta/fna found for $acc" >&2
    continue
  fi
  ln -sf "$src" "$SELECTED_DIR/$renamed.fasta"
done < "$ACCESSIONS_FILE"

cd "$RUN_DIR"
bash /shares/sander.imm.uzh/MM/kansasii/repos/immensekansasii/run_IMMENSE.sh -j job_kansasii_complex_gtdb_representatives -t fasta -r kansasii_complex_gtdb_representatives -x "--kansasii_snippy_db $SNIPPY_DB_DIR" -i "$SELECTED_DIR"
# run_IMMENSE.sh only submits a SLURM job: once it has finished, copy the
# end results (without work/) to output/
rsync -a --exclude work --exclude .nextflow --exclude '*_transfer_result/genomes/' /shares/sander.imm.uzh/MM/kansasii/runs/kansasii_complex_gtdb_representatives/ /shares/sander.imm.uzh/MM/kansasii/output/kansasii_complex_gtdb_representatives/






RUN_DIR="/shares/sander.imm.uzh/MM/kansasii/runs/mkan329"
SNIPPY_DB_DIR="/shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/kansasii_complex/mkan329"
RAW_DIR="/shares/sander.imm.uzh/MM/kansasii/data/mkan329"
INPUT_DIR="/shares/sander.imm.uzh/MM/kansasii/data/mkan329_short"
LINK_CSV="/shares/sander.imm.uzh/MM/kansasii/data/imm/screening_map_link.csv"

# mkan329 comes as paired-end fastq (-t fq_PE). Short ids (purely cosmetic --
# the pipeline also works with the Mkan329-NNN prefix): symlink each pair as
# <NR>_R1.fastq.gz / <NR>_R2.fastq.gz (NR = first column of screening_map_link.csv),
# so the pipeline's sample id is <NR>, and keep the mapping in id_map.tsv.
# Raw files are found by PROBENNUMMER prefix, with R1/R2 or 1/2 read marker.
# If numeric ids turn out to upset a tool, use "s$(printf %03d $nr)" instead.
mkdir -p "$INPUT_DIR"
printf 'NR\tPROBENNUMMER\toriginal_path_R1\toriginal_path_R2\n' > "$INPUT_DIR/id_map.tsv"
find_read() {  # $1 = PROBENNUMMER, $2 = 1|2
  find "$RAW_DIR" \( -name "$1*_R$2*.f*q.gz" -o -name "$1*_$2.f*q.gz" -o -name "$1*_$2_*.f*q.gz" \) | sort | head -1
}
while IFS=, read -r nr pnr _; do
  [ "$nr" = "NR" ] && continue
  r1=$(find_read "$pnr" 1); r2=$(find_read "$pnr" 2)
  if [ -z "$r1" ] || [ -z "$r2" ]; then
    echo "WARNING: no complete fastq pair for $pnr (NR $nr; R1='$r1' R2='$r2')" >&2
    continue
  fi
  ln -sf "$r1" "$INPUT_DIR/${nr}_R1.fastq.gz"
  ln -sf "$r2" "$INPUT_DIR/${nr}_R2.fastq.gz"
  printf '%s\t%s\t%s\t%s\n' "$nr" "$pnr" "$r1" "$r2" >> "$INPUT_DIR/id_map.tsv"
done < "$LINK_CSV"

mkdir -p "$RUN_DIR"
cd "$RUN_DIR"
bash /shares/sander.imm.uzh/MM/kansasii/repos/immensekansasii/run_IMMENSE.sh -j job_mkan329 -t fq_PE -r mkan329 -x "--kansasii_snippy_db $SNIPPY_DB_DIR" -i "$INPUT_DIR"
# run_IMMENSE.sh only submits a SLURM job: once it has finished, copy the
# end results (without work/) to output/
rsync -a --exclude work --exclude .nextflow --exclude '*_transfer_result/genomes/' /shares/sander.imm.uzh/MM/kansasii/runs/mkan329/ /shares/sander.imm.uzh/MM/kansasii/output/mkan329/

# Afterwards (conda activate kansasii_mic): add GTDB species + TNR_MLSA to the
# screening map (writes data/imm/screening_map_results.csv, copy in output/mlsa)
# and generate iTOL labels for the tree tips (short ids -> "Species [Mkan329-NNN]").
python /shares/sander.imm.uzh/MM/kansasii/repos/immensekansasii/scripts/screening_map_results.py \
  --quality /shares/sander.imm.uzh/MM/kansasii/output/mkan329/mkan329_transfer_result/mkan329_quality.tsv \
  --id-map "$INPUT_DIR/id_map.tsv"
bash /shares/sander.imm.uzh/MM/kansasii/repos/immensekansasii/scripts/generate_itol_species_labels.sh -m samples -p mkan329_





New-Item -ItemType Directory -Path "$env:USERPROFILE\kansasii_C\downloads\" -Force
scp -r mimeul@cluster.s3it.uzh.ch:/shares/sander.imm.uzh/MM/kansasii/output/* "$env:USERPROFILE\kansasii_C\downloads\"
 