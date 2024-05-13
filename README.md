# IMMENSE

IMM Extended Nextflow Sequencing Environment

[![Nextflow](https://img.shields.io/badge/Nextflow-21.10.0-brightgreen.svg)]([https://www.nextflow.io/])

## Author

* Michèle Leemann, Marco Meola (mmeola@imm.uzh.ch)
* Updated/extended by Philipp v. Bieberstein

Institution: Applied Microbiology Research - Institute of Medical Microbiology - University of Zurich (UZH)

The steps that are included are:

* Preprocessing
	* Trimmomatic (0.39)
* Pre-Assembly QC
	* MultiQC (1.11)
* Assembly
	* Unicycler (0.4.8)
* Post-Assembly QC
	* Quast (5.0.2)
	* GenomeQC - BUSCO (5.3.2)
* Taxonomy
	* GTDB-tk (2.3.2)
	* Metaphlan4 (4.1.0)
	* 16S blastn (2.12.0+)
	* rMLST blastn (2.11.0+)
* Genome annotation
	* Prokka (1.14.6)
* Genome inspection (antimicrobial resistance genes, virulence factors)
	* abricate (1.0.1)

[<img src="dag.png" width="800" />](dag.png)

# Table of contents

* [Introduction](#Introduction)
* [Running IMMENSE on S3IT](#Running-IMMENSE-on-S3IT)
	* [Running the pipeline on raw data](#Running-the-pipeline-on-raw-data)
	* [Running the pipeline on fastq files](#Running-the-pipeline-on-fastq-files)
	* [Running the pipeline on single fastq file(s)](#Running-the-pipeline-on-single-fastq-file(s))
	* [Running the pipeline on fasta files](#Running-the-pipeline-on-fasta-files)
	* [Email-notification](#Email-notification)
	* [Change parameters for Trimmomatic](#Change-parameters-for-Trimmomatic)
	* [Troubleshooting](#Troubleshooting)
		* [Additional samples](#Additional-samples)
		* [Inspecting failed processes](#Inspecting-failed-processes)
		* [Pipeline does not finish / Missing quality files](#Pipeline-does-not-finish-/-Missing-quality-files)

* [Preparations for usage on other infrastructure](#Preparations-for-usage-on-other-infrastructure)
	* [Requirements](#Requirements)
	* [Adjusting the nextflow.config file](#Adjusting-the-nextflow.config-file)
	* [Adjusting the params.config file](#Adjusting-the-params.config-file)
	* [Launching the pipeline](#Launching-the-pipeline)
		

# Introduction

IMMENSE is a nextflow pipeline. Information about Nextflow can be found under https://www.nextflow.io/ and in the [Nextflow documentation](https://www.nextflow.io/docs/latest/index.html).   

The workflow of the pipeline is defined in the **main.nf** file. The underlying processes are defined in the **modules** of each tool. The configuration for the usage of the containers (Singularity) and the ressource management for the executor (SLURM) are defined in the **nextflow.config** file. The locations of the required databases and default values are specified in the **params.config** file. 

Each process of the pipeline has its own working directory that is located in the **work** folder, where all the output and log files for each process are stored. The favoured output files are copied to the results folder and therefore it is useful to **remove the work directory** if the pipeline finished satisfactorily.  

While the pipeline is running the status can be monitored in **.nextflow.log** or in the slurm file. With successful completion the **report.html** is produced which gives information about each process inlcuding the used ressources. 

# Running IMMENSE on S3IT

The pipeline can be run on **raw data**, **fastq files**, or **fasta files**.

The general command to run the pipeline is:

```
# Go to directory where you want to save your output
cd where/you/want/your/output

# Start Pipeline
bash path/to/pipeline/run_IMMENSE.sh -j <SLURM_JOB_NAME> -t <input_type> -r <run_id> -i </absolute_path/to/input> -x "<additional_options>"
```

**SLURM_JOB_NAME input_type run_id /absolute_path/to/input "additional_options"** must be provided in this order!

**SLURM_JOB_NAME**: Job name for the SLURM job name

**input_type**: raw_PE, raw_SE, fq_PE, fq_SE, or fasta

**run_id**: the transfer folder, the quality file, and the software version file will be tagged with the run_id.

**"additional_options"**: is optional and is used for specifying single samples, email address, or different parameters for trimmomatic. Several additional options can be combined by listing them one after the other inside double quotes (```"option1 option2 ... "```). 

After completion of the pipeline and if everything is ok, it is useful to **remove the work folder**. 

## Running the pipeline on raw data

Depending on the data use **raw_PE** or **raw_SE** for the **input_type**:  

* **raw_PE** &nbsp; &nbsp; &nbsp; &nbsp; for raw data of paired-end reads  
* **raw_SE** &nbsp; &nbsp; &nbsp; &nbsp; for raw data of single-end reads

Provide the absolute path to where the **samplesheet** and the **data** is located, for example  
``` 
/scicore/home/egliadr/GROUP/runQC/run500/demultiplexing 
``` 

Example command for analysing the raw paired-end data of run500:  

``` 
bash /home/progal/software/IMMENSE_phil_dev/run_IMMENSE.sh -j IMMENSE_run500 -t raw_PE -r run500 -i /scicore/home/egliadr/GROUP/runQC/run500/demultiplexing

# To run locally or on IMM cluster, the nextflow script is started directly:

# Use tmux so you can close the command line but keep the job running (RECOMMENDED)
tmux
nextflow run /path/to/IMMENSE/main.nf -profile imm --run_id run500 --input_type fastq --input /path/to/IMMENSE/data/test_dataset --SE NO
# Later you can re-enter the tmux session by 
tmux a -t 0

#TODO: Below method doesn't work yet, find out why.
# Or run the pipeline in the background and you can monitor the progress looking at the pipeline.log file
# nohup nextflow run your_pipeline.nf > pipeline.log 2>&1 &
#NOTE: Remember the process ID because you need it to kill your pipeline if it gets stuck or takes too long:
#kill <pid>
```
**Note**: There must be no quotes around the paths.

## Running the pipeline on fastq files

Depending on the reads use **fq_PE** or **fq_SE** for the **input_type**:  

* **fq_PE** &nbsp; &nbsp; &nbsp; &nbsp; for paired-end reads 
* **fq_SE** &nbsp; &nbsp; &nbsp; &nbsp; for single-end reads

Provide the absolute path to the **"reads" folder**, for example 
``` 
/shares/amr.imm.uzh/data/illumina/routine/runQC/run500/reads 
```  
or for a single species
``` 
/shares/amr.imm.uzh/data/illumina/routine/run500/reads/esccol 
``` 

Example command for analysing the paired-end reads of run500:  

``` 
bash /home/progal/software/IMMENSE_phil_dev/run_IMMENSE.sh -j IMMENSE_run500 -t fq_PE -r run500 -i /scicore/home/egliadr/GROUP/runQC/run500/reads

``` 
**Note**: There must be no quotes around the paths.

## Running the pipeline on single fastq file(s)

It is possible to run one or several single samples out of the reads folder. 

For **one single sample** add ```"--single_sample <sample_id>"``` at the end of the sbatch command (i.e. **"additional_options"**).

Example to run one **single sample**: 
``` 
bash /home/progal/software/IMMENSE_phil_dev/run_IMMENSE.sh -j IMMENSE_singleSample -t fq_PE -r run_singleSample -i /scicore/home/egliadr/GROUP/runQC/IMMENSETestHSS/reads/pseaer "--single_sample 401915-22"
``` 

For **several individual samples** add ```"--single_sample {sample_id_1,sample_id_2,...,sample_id_X}"``` at the end of the sbatch command (i.e. **"additional_options"**).

Example to run **three samples**:
``` 
bash /home/progal/software/IMMENSE_phil_dev/run_IMMENSE.sh -j IMMENSE_threeSamples -t fq_PE -r run_threeSamples -i /scicore/home/egliadr/GROUP/runQC/IMMENSETestHSS/reads "--single_sample {401915-22,502637-1-21,202315-22}"
``` 
## Running the pipeline on fasta files

To run the pipeline on fasta files provide a directory with the genome files to be run. Allowed endings are ```.fasta``` or ```.fna```. 

The **input_type** to be used is **fasta**.

``` 
bash /home/progal/software/IMMENSE_phil_dev/run_IMMENSE.sh -j IMMENSE_genomes -t fasta -r run_genomes -i /S3IT/home/egliadr/GROUP/Michele/example_genomes
``` 

## Email-notification

To receive an email notification when the pipeline is finished including multiqc files and the quality file use  
```"--email <email_address1,email_address2,...>"``` at the end of the sbatch command (i.e. **"additional_options"**).

``` 
bash /home/progal/software/IMMENSE_phil_dev/run_IMMENSE.sh -j IMMENSE_run500 -t raw_PE -r run500 -i /scicore/home/egliadr/GROUP/runQC/run500/demultiplexing "--email username@imm.uzh.ch"

```

You can also use it in combination with the single_sample option:

``` 
bash /home/progal/software/IMMENSE_phil_dev/run_IMMENSE.sh -j IMMENSE_run500 -t raw_PE -r run500 -i /scicore/home/egliadr/GROUP/runQC/run500/demultiplexing "--single_sample {sample_id_1,sample_id_2,...,sample_id_X} --email username@imm.uzh.ch"
``` 

## Change parameters for Trimmomatic

The default values for Trimmomatic are:

* **Paired-end reads**: SLIDINGWINDOW:4:12 MINLEN:100
* **Single-end reads**: SLIDINGWINDOW:4:12 MINLEN:70

To change one of the values use the **"additional_options"** argument, for example:  

&nbsp; &nbsp; &nbsp; &nbsp; **Paired-end reads**: ```"--trimmomatic_PE_extra SLIDINGWINDOW:4:12 MINLEN:80"```  

&nbsp; &nbsp; &nbsp; &nbsp; **Single-end reads**: ```"--trimmomatic_SE_extra SLIDINGWINDOW:4:12 MINLEN:50"``` 

Both, SLIDINGWINDOW and MINLEN need to be specified, but also additional trimmomatic options could be included if desired by placing them after the MINLEN argument. 

Full command:

``` 
bash /home/progal/software/IMMENSE_phil_dev/run_IMMENSE.sh -j IMMENSE_run500 -t raw_PE -r run500 -i /scicore/home/egliadr/GROUP/runQC/run500/demultiplexing "--trimmomatic_PE_extra SLIDINGWINDOW:4:12 MINLEN:80"
```

## Troubleshooting

### Lacking Write permission

If you receive this error when starting the pipeline:
```
ERROR ~ .nextflow/history.lock (No such file or directory)

 -- Check '.nextflow.log' file for details
```
Then this usually means you don't have permission to write into your current working directory. Add write permissions to current working directory with `sudo chmod 777 .`


### Additional samples

If there are additional samples for a run or samples need to be rerun start the pipeline again in the run folder but use a different **run_id**, for example ```run500_2```. 

The results for the samples will be added to ```assembly/results``` and a second transfer folder will be created. 

If the same **run_id** is used, the existing quality and software version files will get overwritten. 

### Inspecting failed processes

In the slurm file all processes run in the pipeline are visible. If a job fails, the exit status is displayed. 

[<img src="pics/slurm_fail.png" width="800" />](pics/slurm_fail.png)

The cause of the error can be reviewed in the working directory of the process which is ```work/<hash_id>``` of the process. For the above example ```work/30/b21bef...```

Besides input and output files, the working directory of each process has the following hidden files:

[<img src="pics/command_files.png" width="400" />](pics/command_files.png)

The **.command.sh** file shows the command that was run in the process, and the **.command.err** the error that caused the failing of the process.

[<img src="pics/error.png" width="600" />](pics/error.png)

Sometimes the .command.log or the .command.out file can give further information about the problem. 

# Preparations for usage on other infrastructure

### Install Dependencies

Clone IMMENSE repository.

```
git clone https://gitlab.uzh.ch/appliedmicrobiologyresearch/amr_research/immense.git
```

Install [minionda](https://conda.io/projects/conda/en/latest/user-guide/install/index.html) or Mamba. Then the `run_IMMENSE.sh` script automatically checks if you have all dependencies installed and if not installs them based on `environment.yml`. Alternatively, manually use the `environment.yml` file to install the dependencies:

```
cd path/to/IMMENSE_repo
conda env update -n env_IMMENSE --file ./environment.yml
# This creates a conda environment called `env_immense` which can be activated by:
# conda activate env_immense
```

### Download Singular containers
Get all the required singularity images by starting an interactive S3IT session on SLURM: (login node will run out of memory)

>If you want to change where the singularity containers are stored, also change the line `cacheDir =` under the singularity settings in your infrastructure specific config file

```
srun --pty -n 1 -c 6 --time=01:00:00 --mem=16G bash -l
```

Then loading singularity and using the script in the repo to load all the container images to the location where they should be saved. You supply the path to the script as the only argument. This should match with your path in `conf/<your-profile>.config`

```
module load singularityce # Or load `env_immense` conda environment for singularity (`conda activate env_immense`)

# Navigate to the pipeline repository
cd path/to/IMMENSE_repo

# Then run the script to pull all the container images to the directory you specify
bash Singularity/pull_singularity_img.sh path/to/directory/singularity_images_cache
```

## Adjusting the Config files

Global configurations are set in `nextflow.config` (should not need changing) and infrastructure specific configurations are specified in specific profiles in the `conf/profiles` directory.
To run on UZH's S3IT cluster, we use the `s3it.config`, to run on the IMM cluster without slurm we use the `imm.config` by specifying `-profile s3it` or `-profile imm`.

To run the pipeline somewhere else (or if the setup changes) create a new "profile" by copying one of the existing `.config` files and changing the profile name and the **database paths** and any other settings you need. If using the `run_IMMENSE.sh` script to submit the pipeline to the SLURM scheduler, also adjust the *profile* name in the `bin/submit_to_cluster.sh` script which contains the nextflow command.

### Setting up on a new infrastructure

Adjust the paths in the infrastructure specific `.config` files to location of the different databases/files. 

The following databases/files are required (see below how to install/download):

* Metaphlan4 database
* BUSCO database
* GTDB 
* 16S database
* rMLST database

### Prepare required Databases

#### metaphlan4
```{bash}
# Put the metaphlan4 database where you want and update path in params.config

# The easiest way to download metaphlan4 database is to use metaphlan (depending on your system you may have to start an interactive SLURM session)
# Load singularity by `module` or activate conda environment
# module load singularity
# conda activate env_immense

singularity shell path/to/singularity/containers/quay.io-biocontainers-metaphlan-4.1.0--pyhca03a8a_0.img 
cd path/to/metaphlan4/database # where you want the database to exist

# To download the June 2023 database use the following command
metaphlan --bowtie2db mpa_vJun23_CHOCOPhlAnSGB_202307 --install
```

#### BUSCO

```{bash}
singularity shell /home/progalla/data/immense_dependencies/singularity/ezlabgva-busco_v5.3.2_cv1.img
busco --download --download_path /path/to/immense_dependencies/busco_downloads
```

#### GTDBtk

```{bash}
# To download the GTDBtk r207v2 dataset we used the following paths
mkdir -p /path/to/immense_dependencies/gtdb/gtdbtk_r207_v2
cd /path/to/immense_dependencies/gtdb/gtdbtk_r207_v2

wget https://data.ace.uq.edu.au/public/gtdb/data/releases/release207/207.0/auxillary_files/gtdbtk_r207_v2_data.tar.gz
# wget https://data.gtdb.ecogenomic.org/releases/release207/207.0/auxillary_files/gtdbtk_r207_v2_data.tar.gz # Alternative mirror if the first url is too slow

tar xvzf gtdbtk_r207_v2_data.tar.gz
```

#### NCBI 16S Database:

```{bash}
mkdir -p /path/to/immense_dependencies/BLAST/16S_ribosomal_RNA
cd /path/to/immense_dependencies/BLAST/16S_ribosomal_RNA

# Download it from https://ftp.ncbi.nlm.nih.gov/blast/db/
wget https://ftp.ncbi.nlm.nih.gov/blast/db/16S_ribosomal_RNA.tar.gz

# Unpack it
tar -xzvf 16S_ribosomal_RNA.tar.gz
```

#### Download rMLST Database:

For this you need an account at [https://pubmlst.org/data](https://pubmlst.org/data):
1. Make an account
2. Request access to the entire dataset under <MY ACCOUNT>: Ribosomal MLST genomes (pubmlst_rmlst_isolates) and Ribosomal MLST typing (pubmlst_rmlst_seqdef)
3. Go to *SPECIES ID* in the menu and then the *Typing* link. [Link to Tab](https://pubmlst.org/bigsdb?db=pubmlst_rmlst_seqdef)
4. On the right under *DOWNLOADS* section, right click on *Ribosomal MLST profiles* and save-link-as. This file refers to the `bigsdb_rMLST` path in the config file.
> Downloading with command line is not possible because it needs authentication
5. Download all Sequences by clicking *Allele Sequence* then expand the *Typing* tree selector and click *Ribosomal MLST*. On the bottom you will see the option to download each Sequence file from `BACT000001 (rpsA)` to `BACT000065 (rpmJ)`. Download each of them and save all fasta files together with the *Ribosomal MLST profiles* file (Step 4) in the same directory and move to wherever you want to store this database. This path should be added as `db_rMLST` variable in your config profile under `conf/profiles/`. And the path to the specific `Ribosomal MLST profiles` text file is added as `bigsdb_rMLST` variable.
6. Create blastn databases from each fasta file

```{bash}
# Making tar archive to compress files and send to server where IMMense will run
tar -zcvf archive_name.tar.gz directory_to_compress/

# Sending over to server
rsync -az --progress bigMLST.tar.gz "<USERNAME>@<SERVER_NAME>:/directory/for/saved/databases/rMLST/"

# Unpacking the archive:
tar -xzvf bigMLST.tar.gz

# If you compressed on a Mac and extract in linux, you may get some warning such as:
--------
MLST/._BACT000017.fas
tar: Ignoring unknown extended header keyword 'LIBARCHIVE.xattr.com.apple.quarantine'
tar: Ignoring unknown extended header keyword 'LIBARCHIVE.xattr.com.apple.metadata:kMDItemWhereFroms'
tar: Ignoring unknown extended header keyword 'LIBARCHIVE.xattr.com.apple.macl'
MLST/BACT000017.fas
--------

# You can ignore these and remove all the ._... files created by running:
`rm ._*` in the directory

```

Create blastn database using the blastn contained in the prokka singularity image (because this image contains blastn)

```{bash}
conda activate env_immense

singularity shell --bind $(pwd):/mnt path/to/singularity/containers/quay.io-biocontainers-prokka-1.14.6--pl5262hdfd78af_1.img

cd mnt/database_directory

bash directory/to/immense/pipeline/bin/
make_MLST_blast_database.sh .

# Exit the singularity container
exit

# Now you should have these file extensions for each of the .fas files:
#fas.nin
#fas.ntf
#fas.ndb
#fas.not
#fas.nto
#fas.nhr
#fas.nsq
```

This is your ribosomal MLST database. Make sure you link to this directory and the profile.txt file in your profile config file `conf/profiles`

## Launching the pipeline

For S3IT the launching of the pipeline was defined in the run_IMMENSE.sh. 

```
# By default the output is always written in the current directory
cd /directory/where/you/want/output
bash /path/to/IMMENSE/run_IMMENSE.sh -j test_run -t fq_PE -r test_run -i /path/to/IMMENSE/data/test_dataset
```

To run the pipeline directly without SLURM, the general command to launch the pipeline locally is: 

```
nextflow run /path/to/IMMENSE/main.nf -with-singularity -with-report -with-trace -with-timeline -profile <profile-name> --run_id <run_id> --input_type <input_type> --input <input_dir> --SE YES/NO

# Make sure you specify a `profile` that works with your infrastructure or create a new one
nextflow run /path/to/IMMENSE/main.nf -profile <profile-name> --run_id <run_name> --input_type fastq/bcl/fasta --input /path/to/IMMENSE/data/test_dataset --SE YES/NO

# For example:
nextflow run /path/to/IMMENSE/main.nf -profile imm --run_id test_run --input_type fastq --input /path/to/IMMENSE/data/test_dataset --SE NO
```

>**Arguments**
>-profile	Name of the executer profile defined in `conf/profiles` directory
>--run_id	Name of the run
>--input_type	Type of the input data: bcl (for raw data), fastq, or fasta
>--input		Absolute path to the input data
>--SE		Single-end reads: YES or NO
> **OPTIONAL ARGUMENTS:**
>--single_sample <NAME_OF_SAMPLE>


The **additional options** as described for the usage on S3IT can be added in the same manner to the command and all parameters defined in the params.config file can be overwritten on the command line with `--<parames-name> <params-value>`.

## License

[GNU General Public License, version 3](https://www.gnu.org/licenses/gpl-3.0.html)