#!/bin/bash

module load singularityce/4.1.0

# Get the path where nextflow expects the singularity containers
INSTALL_PATH=$1
echo ""
echo "Installing Singularity Containers at:            ${INSTALL_PATH}"
echo ""

singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-abricate-1.0.1--ha8f3691_2.img docker://quay.io/biocontainers/abricate:1.0.1--ha8f3691_2
singularity build --sandbox ${INSTALL_PATH}/nfcore-bcl2fastq-2.20.0.422.img docker://nfcore/bcl2fastq:2.20.0.422
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-blast-2.14.1--pl5321h6f7f691_0.img docker://quay.io/biocontainers/blast:2.14.1--pl5321h6f7f691_0
singularity build --sandbox ${INSTALL_PATH}/ezlabgva-busco_v5.3.2_cv1.img docker://ezlabgva/busco:v5.3.2_cv1
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-fastqc-0.12.1--hdfd78af_0.img docker://quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-multiqc-1.23--pyhdfd78af_0.img docker://quay.io/biocontainers/multiqc:1.23--pyhdfd78af_0
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-quast-5.0.2--py37pl5262h190e900_4.img docker://quay.io/biocontainers/quast:5.0.2--py37pl5262h190e900_4
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-trimmomatic-0.39--hdfd78af_2.img docker://quay.io/biocontainers/trimmomatic:0.39--hdfd78af_2
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-unicycler-0.5.1--py312hdcc493e_5.img docker://quay.io/biocontainers/unicycler:0.5.1--py312hdcc493e_5
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-gtdbtk-2.5.2---pyh1f0d9b5_0 docker://quay.io/biocontainers/gtdbtk:2.5.2--pyh1f0d9b5_0
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-metaphlan-4.1.0--pyhca03a8a_0.img docker://quay.io/biocontainers/metaphlan:4.1.0--pyhca03a8a_0
singularity build --sandbox ${INSTALL_PATH}/r-base-4.3.3.img docker://r-base:4.3.3
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-checkm-genome-1.2.2--pyhdfd78af_1.img docker://quay.io/biocontainers/checkm-genome:1.2.2--pyhdfd78af_1
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-pymlst-2.1.6--pyhdfd78af_0.img docker://quay.io/biocontainers/pymlst:2.1.6--pyhdfd78af_0
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-mlst:2.22.0--hdfd78af_0.img docker://quay.io/biocontainers/mlst:2.22.0--hdfd78af_0
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-ncbi-amrfinderplus-4.0.23--hf69ffd2_0.img docker://quay.io/biocontainers/ncbi-amrfinderplus:4.0.23--hf69ffd2_0
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-bakta-1.9.3--pyhdfd78af_0.img docker://quay.io/biocontainers/bakta:1.9.3--pyhdfd78af_0
singularity build --sandbox ${INSTALL_PATH}/pbieber-bwa-pilon-samtools-python-2.0.0.img docker://pbieber/bwa-pilon-samtools-python:2.0.0
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-tb-profiler-6.3.0--pyhdfd78af_0.img docker://quay.io/biocontainers/tb-profiler:6.3.0--pyhdfd78af_0
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-lissero-0.4.9--py_0.img docker://quay.io/biocontainers/lissero:0.4.9--py_0
singularity build --sandbox ${INSTALL_PATH}/quay.io/biocontainers/insilicoseq-2.0.0--pyh7cba7a3_0.img docker://quay.io/biocontainers/insilicoseq:2.0.0--pyh7cba7a3_0