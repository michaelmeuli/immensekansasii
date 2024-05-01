#!/usr/bin/env nextflow

nextflow.enable.dsl=2

/*
 * Define the pipeline parameters
 */


// this prints the input parameters
log.info """
IMMENSE  ~  version ${workflow.manifest.version}

Anything you have to do repeatedly
may be ripe for automation.
— Doug McIlroy

=============================================
"""

/*
* check the input type and create relevant channels
*/

Channel
    .fromPath( "$PWD/assembly/results/*/3_quality/BUSCO/*_busco_version.txt")
    .collect()
    .set { busco_versions }

Channel
    .fromPath( "$PWD/assembly/results/*/3_quality/BUSCO/*/short_summary.specific.*.txt")
    .collect()
    .set { busco_summaries }


Channel
    .fromPath( "$PWD/assembly/results/*/0_trimming/*.quality_read_trimm_info")
    .collect()
    .set { trim_logs }

Channel
    .fromPath( "$PWD/assembly/results/*/3_quality/quast_*/", type: 'dir')
    .collect()
    .set { quast_stats }

Channel
    .fromPath( "$PWD/assembly/results/*/2_annotation/*")
    .collect()
    .set { annot_stats }

Channel
    .fromPath( "$PWD/assembly/results/*/3_quality/summary/*.tab")
    .collect()
    .set { singel_summaries }


/*
* include the modules
*/

include { bcl2fastq } from "./modules/bcl2fastq"
include { link_reads; links_for_transfer } from "./modules/create_links"
include { fastqc } from "./modules/fastqc"
include { multiqc_reads; multiqc_assembly } from "./modules/multiqc"
include { trimmomaticPE; trimmomaticSE } from "./modules/trimmomatic"
include { unicycler; unicyclerSE } from "./modules/unicycler"
include { bwaIndex } from "./modules/bwa_index"
include { bwaAlign; bwaAlignSE } from "./modules/bwa-mem"
include { samtools } from "./modules/samtools"
include { pilon; pilonSE; pilon_remapping; pilon_remappingSE } from "./modules/pilon"
include { prokka } from "./modules/prokka"
include { busco; get_busco_lineages; busco_plot } from "./modules/busco"
include { quast } from "./modules/quast"
include { gtdbtk_classify_wf } from "./modules/gtdbtk"
include { rMLST; call_rMLST } from "./modules/rMLST"
include { metaphlan4; metaphlan4SE } from "./modules/metaphlan"
include { make_one_contig; parse_sam_for_insertsize; coverage_pilon_corrected } from "./modules/python_functions"
include { bwaIndex as indexRemapping } from "./modules/bwa_index"
include { bwaAlign as alignRemapping; bwaAlignSE as alignRemappingSE } from "./modules/bwa-mem"
include { samtools as samtoolsRemapping} from "./modules/samtools"
include { typing_16S } from "./modules/typing_16S.nf"
include { abricate } from "./modules/abricate"
include { summary_sample; merge_summaries } from "./modules/summary"
include { write_software_versions } from "./modules/write_software_versions"


/*
* main workflow
*/

workflow {

      busco_lineages = get_busco_lineages(busco_versions)
      busco_plot(busco_summaries)
      mqc_assembly_out = multiqc_assembly(trim_logs, quast_stats, annot_stats, busco_summaries)
      summary = merge_summaries(singel_summaries)

}


workflow.onComplete {
    println ""
    println "Pipeline finished!"
    println ""
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
    println ""
}

workflow.onError {
    println ""
    println "Pipeline execution stopped with the following message: ${workflow.errorMessage}"
    println ""
    println "${workflow.errorReport}"
}

/*
* Mail notification
*/

if (params.email == "yourmail@yourdomain" || params.email == "") {
    log.info 'Skipping the email\n'
}
else {
    log.info "Sending the email to ${params.email}\n"

    workflow.onComplete {

    def msg = """\
        IMMENSE ${params.run_id} execution summary
        ---------------------------
        Completed at: ${workflow.complete}
        Duration    : ${workflow.duration}
        Success     : ${workflow.success}
        workDir     : ${workflow.launchDir}
        exit status : ${workflow.exitStatus}
        Error report: ${workflow.errorReport ?: '-'}
        """
        .stripIndent()

    mulQC_ass = file("${params.run_id}_transfer_result/multiqc_assembly/multiqc_report.html")
    mulQC_reads = file("demultiplexing/multiqc/multiqc_report.html")
    dashb = file("${params.run_id}_transfer_result/QC_dashboard.html")

        sendMail{
          to "${params.email}"
          subject "IMMENSE ${params.run_id} complete"
          body msg
          attach "${params.run_id}_transfer_result/${params.run_id}_quality.tsv"
          if (dashb.exists()) { attach "${params.run_id}_transfer_result/QC_dashboard.html" }
          if (mulQC_ass.exists()) { attach "${params.run_id}_transfer_result/multiqc_assembly/multiqc_report.html", fileName: "multiqc_report_assembly.html" }
          if (mulQC_reads.exists()) { attach "demultiplexing/multiqc/multiqc_report.html", fileName: "multiqc_report_reads.html" }
        }
    }
}
