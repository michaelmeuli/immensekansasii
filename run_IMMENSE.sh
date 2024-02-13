#!/bin/bash

# This script checks that the dependencies are all installed.
# If everything exists, it then submits the nextflow main job as a sbatch job

module load mamba # Using mamba instead of anaconda because its smaller and faster

###############################################################
## Code to make sure conda environment exists and is accessible
###############################################################

# Main directory is the directory where the pipeline is located
MAIN_DIR="$(dirname "$(readlink -f "$0")")"

echo "Pipeline is located at:"
echo $MAIN_DIR

# Conda Environment name
ENV_NAME="env_immense"

# Check that these packages are installed
#####################################################################
# Define the path to your environment.yml file
env_file="$MAIN_DIR/environment.yml"

# Start extracting after finding the line with 'dependencies:'
extract=false
# Create an empty array to hold package names
PACKAGES=()
# Read the environment.yml line by line
while IFS= read -r line; do
    if [[ $line == "dependencies:" ]]; then
        extract=true
        continue
    fi

    # Extract package names if within the dependencies block
    if $extract && [[ $line =~ ^[[:space:]]*-[[:space:]]*([^=]+)= ]]; then
        PACKAGES+=("${BASH_REMATCH[1]}")
    elif $extract && [[ $line =~ ^[[:space:]]*- ]]; then
        break # Stop if another block starts
    fi
done < "$env_file"
#####################################################################

# Check that the `env_immense` conda environment exists
if conda info --envs | grep -qw $ENV_NAME; then
    echo "Environment '$ENV_NAME' exists. Checking for packages..."

    # Activate environment
    source activate $ENV_NAME

    # Loop through packages and install if missing
    for pkg in "${PACKAGES[@]}"; do
        if ! conda list -n $ENV_NAME | grep -qw $pkg; then
            echo "Package '$pkg' is missing. Installing..."
            #conda install -n $ENV_NAME $pkg -y
            # If the package is missing, just install all required packages from the environment file.
            conda env update -n $ENV_NAME --file $MAIN_DIR/environment.yml
        else
            echo "Package '$pkg' is installed."
        fi
    done
else
    echo "Conda environment '$ENV_NAME' does not exist. Creating it now."
    echo ""
    echo "This may take a few minutes"
    echo ""
    conda env create -f $MAIN_DIR/environment.yml
    echo "Done initializing environment."
    echo "Please restart your bash session, then restart pipeline."
    exit
fi

echo "Done checking environment."
echo "==============================="
echo "==============================="

#########################################################
## Now the conda environment exists and is loadable
#########################################################


#########################################################
## Checking input arguments:
#TODO check arguments more robustly.

if [[ $2 == raw_PE ]]
then input_type="bcl" && single_end="NO"
elif [[ $2 == raw_SE ]]
then
  input_type="bcl" && single_end="YES"
elif [[ $2 == fq_PE ]]
then
  input_type="fastq" && single_end="NO"
elif [[ $2 == fq_SE ]]
then
  input_type="fastq" && single_end="YES"
elif [[ $2 == fasta ]]
then
  input_type="fasta" && single_end="NO"
else
  echo "you must specify an input option of raw_PE, raw_SE, fq_PE, fq_SE, or fasta!" && exit 1
fi

#########################################################

### Submitting the nextflow script to SLURM
echo "Submitting nextflow coordinator to SLURM."
sbatch --job-name=$1 $MAIN_DIR/bin/submit_to_cluster.sh $MAIN_DIR $input_type $single_end $3 $4 $5

# To run this script run:
# cd where/you/want/your/output
# bash /home/progal/software/IMMENSE_phil_dev/run_IMMENSE.sh IMMENSE_phil_test fq_PE phil_test /home/progal/data/IMMense_optimisation/reads/bursta