#!/bin/bash

#SBATCH --time=1-00:00:00
#SBATCH --mem=2G
#SBATCH --cpus-per-task=1
#SBATCH --job-name=IMMENSE

export SINGULARITY_BINDPATH=/scratch,/data,/home/$USER,/shares
export SINGULARITY_TMPDIR=/tmp
export TMPDIR="/tmp"

module purge
module load mamba
module load singularityce/3.10.2

source activate env_immense

launchDir=$PWD

# It's important that the arguments are supplied in the expected order.
MAIN_DIR=$1
INPUT_TYPE=$2
SINGLE_END=$3
RUN_ID=$4
INPUT_DIR=$5
ADDITIONAL_ARGS=$6

nextflow run $MAIN_DIR/main.nf \
          -with-singularity -with-report -profile slurm \
          -with-trace \
          -with-timeline \
          -resume \
          --run_id "$RUN_ID" \
          --input_type "$INPUT_TYPE" \
          --input "$INPUT_DIR" \
          --SE "$SINGLE_END" \
          $ADDITIONAL_ARGS


module purge
module load amd
module load mamba
# Make sure all relevant R packages are install for resistance_table.R (within conda nextflow environment)

cp $MAIN_DIR/bin/resistance_table.R assembly/
cd $launchDir/assembly/
Rscript resistance_table.R
mv resistances.txt $launchDir/${RUN_ID}_transfer_result

cd $launchDir/${RUN_ID}_transfer_result/
cp $MAIN_DIR/bin/Dashboard_tabset.Rmd .
module load singularityce/3.10.2
source activate env_immense

# Use R to render this dashboard

R -e "rmarkdown::render('Dashboard_tabset.Rmd',output_file='QC_dashboard.html')"

cd $launchDir
# rm work/*/*/*.sam work/*/*/*.bam* work/*/*/*.fastq.gz # Commented out by PvB -> it causes -resume not to work

touch pipeline.complete
chmod -R 775 $launchDir
