#!/bin/bash

module load singularityce/4.1.0

# Get the path where nextflow expects the singularity containers
INSTALL_PATH=$1
echo ""
echo "Installing Singularity Containers at:            ${INSTALL_PATH}"
echo ""

singularity build --sandbox -F ${INSTALL_PATH}/quay.io-biocontainers-abricate-1.0.1--ha8f3691_2.img docker://quay.io/biocontainers/abricate:1.0.1--ha8f3691_2
singularity build --sandbox -F ${INSTALL_PATH}/jlboat-BioinfoContainers_bcl2fastq.img shub://jlboat/BioinfoContainers:bcl2fastq
singularity build --sandbox -F ${INSTALL_PATH}/quay.io-biocontainers-blast-2.14.1--pl5321h6f7f691_0.img docker://quay.io/biocontainers/blast:2.14.1--pl5321h6f7f691_0
singularity build --sandbox -F ${INSTALL_PATH}/ezlabgva-busco_v5.3.2_cv1.img docker://ezlabgva/busco:v5.3.2_cv1
singularity build --sandbox -F ${INSTALL_PATH}/quay.io-biocontainers-bwa-0.7.17--h5bf99c6_8.img docker://quay.io/biocontainers/bwa:0.7.17--h5bf99c6_8
singularity build --sandbox -F ${INSTALL_PATH}/quay.io-biocontainers-fastqc-0.12.1--hdfd78af_0.img docker://quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0
singularity build --sandbox -F ${INSTALL_PATH}/quay.io-biocontainers-multiqc-1.11--pyhdfd78af_0.img docker://quay.io/biocontainers/multiqc:1.11--pyhdfd78af_0
singularity build --sandbox -F ${INSTALL_PATH}/quay.io-biocontainers-pilon-1.24--hdfd78af_0.img docker://quay.io/biocontainers/pilon:1.24--hdfd78af_0
singularity build --sandbox -F ${INSTALL_PATH}/quay.io-biocontainers-prokka-1.14.6--pl5262hdfd78af_1.img docker://quay.io/biocontainers/prokka:1.14.6--pl5262hdfd78af_1
singularity build --sandbox -F ${INSTALL_PATH}/quay.io-biocontainers-quast-5.0.2--py37pl5262h190e900_4.img docker://quay.io/biocontainers/quast:5.0.2--py37pl5262h190e900_4
singularity build --sandbox -F ${INSTALL_PATH}/quay.io-biocontainers-samtools-1.19.2--h50ea8bc_1.img docker://quay.io/biocontainers/samtools:1.19.2--h50ea8bc_1
singularity build --sandbox -F ${INSTALL_PATH}/quay.io-biocontainers-trimmomatic-0.39--hdfd78af_2.img docker://quay.io/biocontainers/trimmomatic:0.39--hdfd78af_2
singularity build --sandbox -F ${INSTALL_PATH}/quay.io-biocontainers-unicycler-0.4.8--py39h98c8e45_5.img docker://quay.io/biocontainers/unicycler:0.4.8--py39h98c8e45_5
singularity build --sandbox -F ${INSTALL_PATH}/quay.io-biocontainers-gtdbtk-2.3.2--pyhdfd78af_0.img docker://quay.io/biocontainers/gtdbtk:2.3.2--pyhdfd78af_0
singularity build --sandbox -F ${INSTALL_PATH}/quay.io-biocontainers-metaphlan-4.1.0--pyhca03a8a_0.img docker://quay.io/biocontainers/metaphlan:4.1.0--pyhca03a8a_0
singularity build --sandbox -F ${INSTALL_PATH}/r-base-4.3.3.img docker://r-base:4.3.3
singularity build --sandbox -F ${INSTALL_PATH}/quay.io-biocontainers-checkm-genome-1.2.2--pyhdfd78af_1.img docker://quay.io/biocontainers/checkm-genome:1.2.2--pyhdfd78af_1
singularity build --sandbox -F ${INSTALL_PATH}/quay.io-biocontainers-pymlst-2.1.6--pyhdfd78af_0.img docker://quay.io/biocontainers/pymlst:2.1.6--pyhdfd78af_0
singularity build --sandbox -F ${INSTALL_PATH}/quay.io-biocontainers-ncbi-amrfinderplus-3.12.8--h283d18e_0.img docker://quay.io/biocontainers/ncbi-amrfinderplus:3.12.8--h283d18e_0
