#!/usr/bin/env nextflow

nextflow.enable.dsl=2

/*
 * Define the pipeline parameters
 *
 */

// Pipeline version
version = '0.3'

// this prints the input parameters
log.info """
AMR-Pipeline - N F TESTPIPE  ~  version ${version}
=============================================
reads                  : ${params.reads}
"""

/*
* check if SE or PE reads
*/
if (params.single == "NO") {
    println("Reads are paired ends")
} else if (params.single == "YES") {
    println("Reads are single ends")
} else {
    exit 1, "Please specify YES or NO for single or paired ends"
}


Channel
    .fromPath( params.reads)
    .ifEmpty { error "Cannot find any reads matching: ${params.reads}" }
    .set { reads_for_fastqc }

Channel
    .fromFilePairs( params.reads, size: -1 )
    .ifEmpty { error "Cannot find any reads matching: ${params.reads}" }
    .set { reads_for_trimming }

Channel
    .value( params.illuminaclip)
    .set { illuminaclip }

Channel
    .value( params.db_16s)
    .set { db_16s }

Channel
    .value( params.db_rMLST)
    .set { db_rMLST }

Channel
    .value( params.bigsdb_rMLST)
    .set { bigsdb_rMLST }


/*
* including the modules
*/

include { fastqc } from "./modules/fastqc"
include { multiqc } from "./modules/multiqc"
include { trimmomaticPE; trimmomaticSE } from "./modules/trimmomatic"
include { unicycler; unicyclerSE } from "./modules/unicycler"
include { bwaIndex } from "./modules/bwa_index"
include { bwaAlign } from "./modules/bwa-mem"
include { samtools } from "./modules/samtools"
include { pilon; pilon_remapping } from "./modules/pilon"
include { prokka } from "./modules/prokka"
include { quast } from "./modules/quast"
include { rMLST; call_rMLST } from "./modules/rMLST"
include { metaphlan3 } from "./modules/metaphlan"
include { make_one_contig; parse_sam_for_insertsize; coverage_pilon_corrected } from "./modules/python_functions"
include { bwaIndex as indexRemapping } from "./modules/bwa_index"
include { bwaAlign as alignRemapping } from "./modules/bwa-mem"
include { samtools as samtoolsRemapping} from "./modules/samtools"
include { typing_16S } from "./modules/typing_16S.nf"
include { abricate } from "./modules/abricate"
include { summary_sample; merge_summaries } from "./modules/summary"


// The main worflow can directly call the named workflows from the modules
workflow {
  if (params.single == "NO") {
    trimm_out = trimmomaticPE(reads_for_trimming, illuminaclip)
    unicycler_out = unicycler(trimm_out.trimmed_reads)
  }
  else {
    trimm_out = trimmomaticSE(reads_for_trimming, illuminaclip)
    unicycler_out = unicyclerSE(trimm_out.trimmed_reads)
  }
}
