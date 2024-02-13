#!/bin/bash

#SBATCH --time=1-00:00:00
#SBATCH --mem=2G
#SBATCH --cpus-per-task=1
#SBATCH --job-name=IMMENSE

export SINGULARITY_BINDPATH=/scratch,/data,/home/$USER,/shares
export SINGULARITY_CACHEDIR=/shares/amr.imm.uzh/.singularity
export SINGULARITY_TMPDIR=/tmp
export TMPDIR="/tmp"

module purge
module load mamba
module load singularityce/3.10.2

source activate env_immense

launchDir=$PWD

MAIN_DIR="/home/progal/software/IMMENSE_phil_dev"

input_type=$1
single_end=$2

nextflow run $MAIN_DIR/main.nf \
          -with-singularity -with-report -profile slurm \
          --run_id "$3" \
          --input_type "$input_type" \
          --input "$4" \
          --SE "$single_end" \
          $5


module purge
module load amd
module load mamba
# Make sure all relevant R packages are install for resistance_table.R (within conda nextflow environment)

cp $MAIN_DIR/bin/resistance_table.R assembly/
cd $launchDir/assembly/
Rscript resistance_table.R
mv resistances.txt $launchDir/${2}_transfer_result

cd $launchDir/${2}_transfer_result/
cp $MAIN_DIR/bin/Dashboard_tabset.Rmd .
module load singularityce/3.10.2
source activate env_immense

# Use R to render this dashboard

R -e "rmarkdown::render('Dashboard_tabset.Rmd',output_file='QC_dashboard.html')"

cd $launchDir
rm work/*/*/*.sam work/*/*/*.bam* work/*/*/*.fastq.gz

touch pipeline.complete
chmod -R 775 $launchDir
