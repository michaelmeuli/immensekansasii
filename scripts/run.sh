


# By default the output is always written in the current directory
cd /shares/sander.imm.uzh/MM/kansasii/output
bash /shares/sander.imm.uzh/MM/kansasii/immensekansasii/run_IMMENSE.sh -j test_run -t fq_PE -r test_run -i /shares/sander.imm.uzh/MM/kansasii/immensekansasii/data/test_dataset




ssh mimeul@cluster.s3it.uzh.ch "cd /shares/sander.imm.uzh/MM/kansasii/output && tar --exclude='work' -cf /tmp/archive.tar ."
scp mimeul@cluster.s3it.uzh.ch:/tmp/archive.tar "$env:USERPROFILE\kansasii\downloads\"
cd "$env:USERPROFILE\kansasii\downloads"
tar -xf archive.tar



# ssh mimeul@cluster.s3it.uzh.ch "cd /shares/sander.imm.uzh/MM/kansasii/output && find . -name '*.html' | tar -cf /tmp/htmls.tar -T -"
# scp mimeul@cluster.s3it.uzh.ch:/tmp/htmls.tar "$env:USERPROFILE\kansasii\downloads\"
# cd "$env:USERPROFILE\kansasii\downloads"
# tar -xf htmls.tar

# ssh mimeul@cluster.s3it.uzh.ch "cd /shares/sander.imm.uzh/MM/kansasii/output && tar --exclude='./*/work' -cf /tmp/archive.tar ."



mkdir -p /shares/sander.imm.uzh/MM/kansasii/output/reference_genomes_gtdb_232
cd /shares/sander.imm.uzh/MM/kansasii/output/reference_genomes_gtdb_232
bash /shares/sander.imm.uzh/MM/kansasii/immensekansasii/run_IMMENSE.sh -j ref_232_run -t fasta -r ref_run -i /shares/sander.imm.uzh/MM/kansasii/data/reference_genomes_gtdb_232/

ssh mimeul@cluster.s3it.uzh.ch "rm -f /shares/sander.imm.uzh/MM/kansasii/output/archive.tar"
ssh mimeul@cluster.s3it.uzh.ch "cd /shares/sander.imm.uzh/MM/kansasii/output/reference_genomes_gtdb_232 && tar --exclude='work' -cf /shares/sander.imm.uzh/MM/kansasii/output/archive.tar ."
New-Item -ItemType Directory -Path "$env:USERPROFILE\kansasii\downloads\reference_genomes_gtdb_232\" -Force
scp mimeul@cluster.s3it.uzh.ch:/shares/sander.imm.uzh/MM/kansasii/output/archive.tar "$env:USERPROFILE\kansasii\downloads\reference_genomes_gtdb_232\"
cd "$env:USERPROFILE\kansasii\downloads\reference_genomes_gtdb_232\"
tar -xf archive.tar




# -i only takes a single directory (the pipeline recurses through it with
# **/*.{fasta,fna}), so it can't be handed a glob of per-genome dirs -- only
# the first match would ever be used. Build a flat directory of symlinks,
# one per accession listed in mycobacterium_representative_type_strain_accessions.txt,
# and point -i at that instead.
ACCESSIONS_FILE="/shares/sander.imm.uzh/MM/kansasii/lit/gtdb/gtdb232/mycobacterium_representative_type_strain_accessions.txt"
GENOME_DATA_DIR="/shares/sander.imm.uzh/MM/kansasii/data/gtdb_genomes/Mycobacteriaceae/ncbi_dataset/data"
SELECTED_DIR="/shares/sander.imm.uzh/MM/kansasii/data/gtdb_genomes/Mycobacteriaceae/selected_type_strains"

mkdir -p "$SELECTED_DIR"
while read -r acc; do
  [ -z "$acc" ] && continue
  acc=$(echo "$acc" | cut -c4-)  # strip RS_/GB_ source-flag prefix
  src=$(find "$GENOME_DATA_DIR/$acc" -maxdepth 1 \( -name '*.fna' -o -name '*.fasta' \) | head -1)
  if [ -z "$src" ]; then
    echo "WARNING: no fasta/fna found for $acc" >&2
    continue
  fi
  ln -sf "$src" "$SELECTED_DIR/$acc.fasta"
done < "$ACCESSIONS_FILE"

mkdir -p /shares/sander.imm.uzh/MM/kansasii/output/tree_run
cd /shares/sander.imm.uzh/MM/kansasii/output/tree_run
bash /shares/sander.imm.uzh/MM/kansasii/immensekansasii/run_IMMENSE.sh -j job_tree_run -t fasta -r tree_run -i "$SELECTED_DIR"
