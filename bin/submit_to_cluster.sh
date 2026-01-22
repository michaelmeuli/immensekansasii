#!/bin/bash

#SBATCH --time=24:00:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=4
#SBATCH --ntasks=1
#SBATCH --job-name=IMMENSE

export SINGULARITY_BINDPATH=/scratch,/data,/home/$USER,/shares
export SINGULARITY_TMPDIR=/tmp
export TMPDIR="/tmp"

module purge
module load mamba
module load singularityce/4.1.0

source activate env_immense

# Increas the percentages available in the java heap space
export NXF_JVM_ARGS="-XX:InitialRAMPercentage=10 -XX:MaxRAMPercentage=75"

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

# A hack to try to prevent nextflow from getting stuck on UZH's S3IT (bug: https://github.com/nextflow-io/nextflow/issues/2695 )
WORK_DIR="$1/work"
echo "Monitoring ${WORK_DIR} for open files"
nohup lsof +D ${WORK_DIR} -r 600 &> /dev/null &
LSOF_PID=$!
trap "kill $LSOF_PID" EXIT

WORK_DIR="/sctmp/${USER}"
echo "And monitoring ${WORK_DIR} for open files"
nohup lsof +D ${WORK_DIR} -r 600 &> /dev/null &
LSOF_PID=$!
trap "kill $LSOF_PID" EXIT


# The profile has to be updated if running on a different infrastructure
#nextflow run $MAIN_DIR/main.nf \
nextflow -trace nextflow.executor run $MAIN_DIR/main.nf \
          -profile imm \
          -resume \
          --run_id "$RUN_ID" \
          --input_type "$INPUT_TYPE" \
          --input "$INPUT_DIR" \
          --SE "$SINGLE_END" \
          $ADDITIONAL_ARGS

#-ansi-log false \ # This would keep the slurm output log a bit cleaner but gives less info.

touch pipeline.complete
chmod -R 775 $launchDir
