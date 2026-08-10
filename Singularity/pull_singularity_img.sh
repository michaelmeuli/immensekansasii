#!/bin/bash

module load apptainer

# Get the path where nextflow expects the singularity containers
INSTALL_PATH=$1
echo ""
echo "Installing containers at:            ${INSTALL_PATH}"
echo ""

singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-abricate-1.0.1--ha8f3691_2.img docker://quay.io/biocontainers/abricate:1.0.1--ha8f3691_2
singularity build --sandbox ${INSTALL_PATH}/nfcore-bcl2fastq-2.20.0.422.img docker://nfcore/bcl2fastq:2.20.0.422
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-blast-2.17.0--h66d330f_0.img docker://quay.io/biocontainers/blast:2.17.0--h66d330f_0
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-busco-6.0.0--pyhdfd78af_2.img docker://quay.io/biocontainers/busco:6.0.0--pyhdfd78af_2
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-fastqc-0.12.1--hdfd78af_0.img docker://quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-multiqc-1.23--pyhdfd78af_0.img docker://quay.io/biocontainers/multiqc:1.23--pyhdfd78af_0
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-quast-5.0.2--py37pl5262h190e900_4.img docker://quay.io/biocontainers/quast:5.0.2--py37pl5262h190e900_4
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-trimmomatic-0.39--hdfd78af_2.img docker://quay.io/biocontainers/trimmomatic:0.39--hdfd78af_2
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-unicycler-0.5.1--py312hdcc493e_5.img docker://quay.io/biocontainers/unicycler:0.5.1--py312hdcc493e_5
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-gtdbtk-2.7.2--pyhdfd78af_1.img docker://quay.io/biocontainers/gtdbtk:2.7.2--pyhdfd78af_1
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-metaphlan-4.1.0--pyhca03a8a_0.img docker://quay.io/biocontainers/metaphlan:4.1.0--pyhca03a8a_0
singularity build --sandbox ${INSTALL_PATH}/r-base-4.3.3.img docker://r-base:4.3.3
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-checkm-genome-1.2.2--pyhdfd78af_1.img docker://quay.io/biocontainers/checkm-genome:1.2.2--pyhdfd78af_1
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-pymlst-2.1.6--pyhdfd78af_0.img docker://quay.io/biocontainers/pymlst:2.1.6--pyhdfd78af_0
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-mlst:2.32.2--hdfd78af_0.img docker://quay.io/biocontainers/mlst:2.32.2--hdfd78af_0
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-ncbi-amrfinderplus-4.2.7--hf69ffd2_0.img docker://quay.io/biocontainers/ncbi-amrfinderplus:4.2.7--hf69ffd2_0
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-bakta-1.11.4--pyhdfd78af_0.img docker://quay.io/biocontainers/bakta:1.11.4--pyhdfd78af_0
singularity build --sandbox ${INSTALL_PATH}/pbieber-bwa-pilon-samtools-python-2.0.0.img docker://pbieber/bwa-pilon-samtools-python:2.0.0
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-tb-profiler-6.3.0--pyhdfd78af_0.img docker://quay.io/biocontainers/tb-profiler:6.3.0--pyhdfd78af_0
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-lissero-0.4.9--py_0.img docker://quay.io/biocontainers/lissero:0.4.9--py_0
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-insilicoseq-2.0.0--pyh7cba7a3_0.img docker://quay.io/biocontainers/insilicoseq:2.0.0--pyh7cba7a3_0
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-snippy-4.6.0--hdfd78af_6.img docker://quay.io/biocontainers/snippy:4.6.0--hdfd78af_6
singularity build --sandbox ${INSTALL_PATH}/quay.io-biocontainers-iqtree-3.1.3--h8471819_0.img docker://quay.io/biocontainers/iqtree:3.1.3--h8471819_0
