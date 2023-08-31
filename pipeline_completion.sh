#!/bin/bash


#SBATCH --time=1-00:00:00
#SBATCH --mem=2G
#SBATCH --cpus-per-task=1
#SBATCH --job-name=IMMENSE


module purge
module load anaconda3
module load singularityce/3.10.2
source activate /home/$USER/data/miniconda3/envs/nextflow

launchDir=$PWD

MAIN_DIR="/shares/amr.imm.uzh/bioinfo/pipelines/nextflow/IMMENSE"

nextflow run $MAIN_DIR/complete_pipeline.nf \
          -with-singularity -with-report -profile slurm \
          --run_id "$1"


ml purge
ml R/3.6.3-foss-2018b

cp $MAIN_DIR/bin/resistance_table.R assembly/
cd $launchDir/assembly/
Rscript resistance_table.R
mv resistances.txt $launchDir/${1}_transfer_result

cd $launchDir/${1}_transfer_result/
cp $MAIN_DIR/bin/Dashboard_tabset.Rmd .
ml Pandoc/2.7.3
ml R/3.6.3-foss-2018b

R -e "rmarkdown::render('Dashboard_tabset.Rmd',output_file='QC_dashboard.html')"

cd $launchDir
rm work/*/*/*.sam work/*/*/*.bam* work/*/*/*.fastq.gz

touch pipeline.complete
chmod -R 775 $launchDir
