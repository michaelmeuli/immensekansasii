#!/bin/bash


#SBATCH --qos=1day
#SBATCH --mem=2G
#SBATCH --cpus-per-task=1
#SBATCH --job-name=USBacto


### adjust here the run_id, input_type, if SE, and input_dir

run_id="run000"
input_type="bcl"   # "bcl" or "fastq"  ("fasta" not implemented yet)
single_end="NO"    # "NO" for pair-end reads, "YES" for single-end reads

input_dir="/scicore/home/egliadr/GROUP/runQC/"$run_id"/demultiplexing"   # path to demultiplexing or reads folder
one_sample="-"


ml purge
ml Miniconda2/4.3.30
source activate /scicore/home/egliadr/GROUP/Software/conda_environments/nextflow

launchDir=$PWD

MAIN_DIR="/scicore/home/egliadr/GROUP/Software/pipelines/nextflow/USBacto"

nextflow run $MAIN_DIR/main.nf \
          -with-singularity -with-report -profile slurm \
          --run_id "$run_id" \
          --input_type "$input_type" \
          --input "$input_dir" \
          --single_sample "$one_sample" \
          --SE "$single_end"


ml purge
ml R/3.6.3-foss-2018b

cp $MAIN_DIR/bin/resistance_table.R assembly/
cd $launchDir/assembly/
Rscript resistance_table.R
mv resistances.txt $launchDir/${run_id}_transfer_result

cd $launchDir/${run_id}_transfer_result/
cp $MAIN_DIR/bin/Dashboard_tabset.Rmd .
ml Pandoc/2.7.3
ml R/3.6.3-foss-2018b

R -e "rmarkdown::render('Dashboard_tabset.Rmd',output_file='QC_dashboard.html')"

cd $launchDir
rm work/*/*/*.sam work/*/*/*.bam* work/*/*/*.fastq.gz
touch pipeline.complete

chmod -R 775 $launchDir
