# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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