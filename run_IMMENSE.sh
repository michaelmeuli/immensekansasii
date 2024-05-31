#!/bin/bash

# This script checks that the dependencies are all installed.
# If everything exists, it then submits the nextflow controller job as a sbatch job

###############################################################
## Parse and Check arguments
###############################################################

# Display usage
usage() {
    echo "Usage: $0 -j <Slurm Job Name> -t <Input Type> -r <Run ID> -i <Input Directory> [-x <Additional Options>]"
    echo ""
    echo "-j    Name of the SLURM job"
    echo "-t    Specifies the input type: raw_PE, raw_SE, fq_PE, fq_SE, or fasta"
    echo "-r    Used to tag the transfer folder, the quality file, and the software version file"
    echo "-i    This is where input files are"
    echo '-x    Optional. Used for specifying single samples, email address, or different parameters for trimmomatic. Several additional options can be combined by listing them one after the other inside double quotes "option1 option2 ...".'
    exit 1
}

# Initialize variables
jobName=""
inputType=""
runId=""
inputDirectory=""
additionalArguments=""

# Loop through arguments and process them
while getopts ":j:t:r:i:x:" opt; do
    case ${opt} in
        j )
            jobName=$OPTARG
            ;;
        t )
            inputType=$OPTARG
            ;;
        r )
            runId=$OPTARG
            ;;
        i )
            inputDirectory=$OPTARG
            ;;
        x )
            additionalArguments=$OPTARG
            ;;
        \? )
            echo "Invalid option: $OPTARG" 1>&2
            usage
            ;;
        : )
            echo "Invalid option: $OPTARG requires an argument" 1>&2
            usage
            ;;
    esac
done
shift $((OPTIND -1))

# Check if all required options were provided
if [ -z "$jobName" ] || [ -z "$runId" ] || [ -z "$inputType" ] || [ -z "$inputDirectory" ]; then
    echo "Options -j -t -r -i  are required."
    usage
fi

# Print the given arguments
echo "Job Name:             $jobName"
echo "Run ID:               $runId"
echo "Input Type:           $inputType"
echo "Input Directory:      $inputDirectory"
echo "Additional Arguments: $additionalArguments"

# Check that input directory exists:
if [ -d $inputDirectory ]; then
    echo ""
else
  echo ""
  echo "ERROR => Input directory does not exist. Please check your path."
  echo ""
  exit 1
fi

###############################################################
###############################################################

module load mamba # Using mamba instead of anaconda because its smaller and faster

###############################################################
## Check that Conda Environment has access to all Required Packages
###############################################################

# Main directory is the directory where the pipeline is located
MAIN_DIR="$(dirname "$(readlink -f "$0")")"

echo "Pipeline is located at: $MAIN_DIR"

# Conda Environment name
ENV_NAME="env_immense"

# Path to the environment.yml file
env_file="$MAIN_DIR/environment.yml"

extract=false # Helper variable for checking packages
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
            echo "Package '$pkg' was found."
        fi
    done
else
    echo "Conda environment '$ENV_NAME' does not exist. Creating it now."
    echo ""
    echo "This may take a few minutes"
    echo ""
    conda env create -f $MAIN_DIR/environment.yml
    echo "Done installing Conda environment."
    exit 1
fi

echo "Done checking environment."
echo "==============================="
echo "==============================="

#########################################################
## Now the conda environment exists and is loadable
#########################################################

# For future if we need current edge version 24.02.0
# This will automatically install this version before running the pipeline (if needed)
#TODO: Remove this once conda can install this version
#NXF_VER=24.02.0-edge 


#########################################################
## Checking input arguments:
#TODO check arguments more robustly.

if [[ $inputType == raw_PE ]]
then input_type="bcl" && single_end="NO"
elif [[ $inputType == raw_SE ]]
then
  input_type="bcl" && single_end="YES"
elif [[ $inputType == fq_PE ]]
then
  input_type="fastq" && single_end="NO"
elif [[ $inputType == fq_SE ]]
then
  input_type="fastq" && single_end="YES"
elif [[ $inputType == fasta ]]
then
  input_type="fasta" && single_end="NO"
else
  echo "you must specify an input option of raw_PE, raw_SE, fq_PE, fq_SE, or fasta!" && exit 1
fi

#########################################################

### Submitting the nextflow script to SLURM

echo "Submitting nextflow coordinator to SLURM."
echo "This is the command:"
echo "sbatch --job-name=$jobName $MAIN_DIR/bin/submit_to_cluster.sh $MAIN_DIR $input_type $single_end $runId $inputDirectory $additionalArguments"
sbatch --job-name=$jobName $MAIN_DIR/bin/submit_to_cluster.sh $MAIN_DIR $input_type $single_end $runId $inputDirectory "$additionalArguments"
# The submit_to_cluster.sh script expects the inputs in this exact order.

# To run this script run:
# cd where/you/want/your/output
# bash /home/progal/software/IMMENSE_phil_dev/run_IMMENSE.sh -j IMMENSE_phil_test -t fq_PE -r phil_test -i /home/progal/data/IMMense_optimisation/reads/bursta