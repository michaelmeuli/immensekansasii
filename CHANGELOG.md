# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### `Added`
- 

### `Changed`
- 


## [1.1.1] - 2024-05-13

### `Added`
- Added more errors troubleshooting in `README.md`
- Created standalone config to define container images

### `Changed`
- Removed R packages from conda environment yml file
- Output directories for *sample outputs* and *run outputs* are now specified in config profiles instead of declared in each process definition
- Cleaned up process definitions
- FastQC and multiQC results are now put int *00_QC* subfolder of the *output_directory_run* (transfer folder)
- Fixed bug that failed to link raw reads if input was given as relative path
- Updated `README.md` to include more examples and code
- Fixed bugs that prevented single-end reads from running through
- User who started pipeline is now in completion email

## [1.1.0] - 2024-05-1

### `Added`
- Added local execution profile (for running on IMM cluster)
- Simplified code for enabling single sample analysis
- Added Singularity into conda environment
- Included test datasets in `data/test_dataset` to check if everything works
- Summarizing Resistance genes is now done by python script as part of nextflow pipeline (instead of afterwards)

### `Changed`
- Updated Readme to include database downloading, config changes and running locally on IMM
- Updated Abricate to include NCBI database from 2023-Nov-4
- Modularized `Config` files making it easier to run on new infrastructure

## [1.0.0] - 2024-04-24

### `Added`
- Starting bash script `run_IMMENSE.sh` now expects input parameters with flags `-j -t -r -i -x`, can handle any order and gives helpful feedback if wrong
- Start script `run_IMMENSE.sh` now checks that conda environment is set up as expected and creates it if necessary
- Resume functionality was added as default and works
- FastQC now runs before and after trimmomatic and generates multiQC reports for each timepoint
- If input sample fastq is less than 1 MB after trimmomatic, they are not processed (failed sequencing) but still included in `_quality.tab` output

### `Changed`

- Merged the four independent workflows (fastq vs. bcl, single-end vs. paired-end) into 1 sequential workflow which diverges as necessary
- Output is produced in current working directory by default
- Converted static paths throughout pipeline into paths all defined in `params.config` or `nextflow.config`
- BUSCO now runs with fungi and bacteria samples
- Data intensive jobs now copy data to local temporary directory `scratch = true` to prevent slowness when shared filesystem is overloaded
- GTDB was updated to `2.3.2` from `2.1.0` and runs with published biocontainer
- Metaphlan was updated to Metaphlan4 from Metaphlan3 (fixed canaur classification)
- Fixed `resistance_table.R` so it doesn't crash if a sample wasn't processed and thus lacks the Abricate output

### `Removed`
- Removed additional Pilon polishing step after Unicycler. Unicycler already does polishing as part of it's workflow.
- 

## [0.5.2] - 