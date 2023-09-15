#!/bin/bash

#SBATCH --time=1-00:00:00
#SBATCH --mem=2G
#SBATCH --cpus-per-task=1
#SBATCH --job-name=IMMENSE


if [[ $1 == raw_PE ]]
then input_type="bcl" && single_end="NO"
elif [[ $1 == raw_SE ]]
then
  input_type="bcl" && single_end="YES"
elif [[ $1 == fq_PE ]]
then
  input_type="fastq" && single_end="NO"
elif [[ $1 == fq_SE ]]
then
  input_type="fastq" && single_end="YES"
elif [[ $1 == fasta ]]
then
  input_type="fasta" && single_end="NO"
else
  echo "you must specify an input option of raw_PE, raw_SE, fq_PE, fq_SE, or fasta!" && exit 1
fi

export SINGULARITY_BINDPATH=/scratch,/data,/home/$USER,/shares
export SINGULARITY_CACHEDIR=/shares/amr.imm.uzh/.singularity

module purge
module load anaconda3
module load containers
module load singularityce/3.10.2
source activate /home/$USER/data/miniconda3/envs/nextflow

launchDir=$PWD

MAIN_DIR="/shares/amr.imm.uzh/bioinfo/pipelines/USBacto"

nextflow run $MAIN_DIR/main.nf \
          -with-singularity -with-report -profile slurm \
          --run_id "$2" \
          --input_type "$input_type" \
          --input "$3" \
          --SE "$single_end" \
          $4


module purge
module load amd
module load rstudio

cp $MAIN_DIR/bin/resistance_table.R assembly/
cd $launchDir/assembly/
Rscript resistance_table.R
mv resistances.txt $launchDir/${2}_transfer_result

cd $launchDir/${2}_transfer_result/
cp $MAIN_DIR/bin/Dashboard_tabset.Rmd .
module load singularityce/3.10.2
source activate /home/mmeola/data/miniconda3/envs/nextflow
module load rstudio

R -e "rmarkdown::render('Dashboard_tabset.Rmd',output_file='QC_dashboard.html')"

cd $launchDir
rm work/*/*/*.sam work/*/*/*.bam* work/*/*/*.fastq.gz

touch pipeline.complete
chmod -R 775 $launchDir


