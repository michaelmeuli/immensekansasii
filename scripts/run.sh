

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
# species-name annotations after upload (that script will need updating to
# match on the renamed ids too).
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
INPUT_DIR="/shares/sander.imm.uzh/MM/kansasii/data/mkan329"
mkdir -p "$RUN_DIR"
cd "$RUN_DIR"
bash /shares/sander.imm.uzh/MM/kansasii/repos/immensekansasii/run_IMMENSE.sh -j job_mkan329 -t fasta -r mkan329 -x "--kansasii_snippy_db $SNIPPY_DB_DIR" -i "$INPUT_DIR"
# run_IMMENSE.sh only submits a SLURM job: once it has finished, copy the
# end results (without work/) to output/
rsync -a --exclude work --exclude .nextflow --exclude '*_transfer_result/genomes/' /shares/sander.imm.uzh/MM/kansasii/runs/mkan329/ /shares/sander.imm.uzh/MM/kansasii/output/mkan329/





New-Item -ItemType Directory -Path "$env:USERPROFILE\kansasii_C\downloads\" -Force
scp -r mimeul@cluster.s3it.uzh.ch:/shares/sander.imm.uzh/MM/kansasii/output/* "$env:USERPROFILE\kansasii_C\downloads\"
 