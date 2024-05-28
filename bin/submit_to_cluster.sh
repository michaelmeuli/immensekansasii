#!/bin/bash

#SBATCH --time=23:00:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=2
#SBATCH --ntasks=1
#SBATCH --job-name=IMMENSE

export SINGULARITY_BINDPATH=/scratch,/data,/home/$USER,/shares
export SINGULARITY_TMPDIR=/tmp
export TMPDIR="/tmp"

module purge
module load mamba
module load singularityce/4.1.0

source activate env_immense

launchDir=$PWD

# It's important that the arguments are supplied in the expected order.
MAIN_DIR=$1
INPUT_TYPE=$2
SINGLE_END=$3
RUN_ID=$4
INPUT_DIR=$5
# Caputing all arguments after the 5th and add them as additional Arguments
shift 5
ADDITIONAL_ARGS="$@"


# The profile has to be updated if running on a different infrastructure
#nextflow run $MAIN_DIR/main.nf \
nextflow -trace nextflow.executor run $MAIN_DIR/main.nf \
          -profile s3it \
          -resume \
          --run_id "$RUN_ID" \
          --input_type "$INPUT_TYPE" \
          --input "$INPUT_DIR" \
          --SE "$SINGLE_END" \
          $ADDITIONAL_ARGS

#-ansi-log false \ # This would keep the slurm output log a bit cleaner but gives less info.

touch pipeline.complete
chmod -R 775 $launchDir
