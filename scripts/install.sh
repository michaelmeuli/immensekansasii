srun --pty -n 1 -c 6 --time=01:00:00 --mem=16G bash -l
bash Singularity/pull_singularity_img.sh /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/containers

module load apptainer
apptainer shell /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/containers/quay.io-biocontainers-metaphlan-4.1.0--pyhca03a8a_0.img 
cd /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/metaphlan/Metaphlan4_Jun23 # where you want the database to exist
# To download the June 2023 database use the following command
metaphlan --bowtie2db mpa_vJun23_CHOCOPhlAnSGB_202307 --install

mkdir -p /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/busco
srun --pty -n 1 -c 6 --time=01:00:00 --mem=16G bash -l
module load apptainer
apptainer shell /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/containers/quay.io-biocontainers-busco-6.0.0--pyhdfd78af_2.img
busco --download "all" --download_path /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/busco

busco --download bacteria_odb12 --download_path /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/busco

curl -L -o /tmp/mycobacterium_odb12.tar.gz https://busco-data.ezlab.org/v5/data/lineages/mycobacterium_odb12.2026-05-22.tar.gz
cd /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/busco/lineages/
tar -xzf /tmp/mycobacterium_odb12.tar.gz
ls -la mycobacterium_odb12/


# To download the GTDBtk r207v2 dataset we used the following paths
mkdir -p /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/gtdbtk_r226
cd /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/gtdbtk_r226
wget -c https://data.ace.uq.edu.au/public/gtdb/data/releases/release207/207.0/auxillary_files/gtdbtk_r207_v2_data.tar.gz
# Alternative mirror if the first url is too slow: https://data.gtdb.ecogenomic.org/releases/release207/207.0/auxillary_files/gtdbtk_r207_v2_data.tar.gz
# Unpack the dataset:
tar xvzf gtdbtk_r207_v2_data.tar.gz

conda env remove -n env_immense
conda env create -f environment.yml


# https://gtdb.ecogenomic.org/   -> adanced search
/shares/sander.imm.uzh/MM/kansasii/data/gtdb_genomes/Mycobacterium_attenuatum/ncbi_dataset/data/GCA_002086865.1/
   GCA_002086865.1_ASM208686v1_genomic.fna
   genomic.gff

srun --pty -n 1 -c 6 --time=03:00:00 --mem=16G bash -l
mkdir -p /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/16S_ribosomal_20260123
cd /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/16S_ribosomal_20260123
# Download it from https://ftp.ncbi.nlm.nih.gov/blast/db/
wget https://ftp.ncbi.nlm.nih.gov/blast/db/16S_ribosomal_RNA.tar.gz
# Unpack it
tar -xzvf 16S_ribosomal_RNA.tar.gz


mkdir -p /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/rMLST
rsync -avhP \
  /shares/sander.imm.uzh/IMMense/immense_databases/rMLST/database_20220527/ \
  /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/rMLST/database_20220527/

quality_rules   = "/shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/QC_bacteria/rules.csv"
cp /shares/sander.imm.uzh/IMMense/immense_databases/QC_bacteria/* /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/QC_bacteria/



srun --pty -n 1 -c 6 --time=03:00:00 --mem=16G bash -l
module load apptainer
mkdir -p /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/AMRfinderplus/
cd /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/AMRfinderplus/

apptainer shell --bind $(pwd):/mnt /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/containers/quay.io-biocontainers-ncbi-amrfinderplus-4.2.7--hf69ffd2_0.img
# Navigate to /mnt because that mirrors the current working directory from where you launched the container
cd /mnt
# Download the newest database to this directory:
amrfinder_update --force_update --database .
# Look at folder structure, it will create a "YYY-MM-DD" & "latest" directory, 
# Decide which one you want to use and update path in your config profile.


srun --pty -n 1 -c 6 --time=03:00:00 --mem=16G bash -l
module load apptainer
# Navigate to where you want the database to be stored & run amrfinderplus interactively
mkdir -p /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/bakta/
cd /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/bakta/
apptainer shell --bind $(pwd):/mnt /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/containers/quay.io-biocontainers-bakta-1.11.4--pyhdfd78af_0.img
cd /mnt
bakta_db download --output . --type full

