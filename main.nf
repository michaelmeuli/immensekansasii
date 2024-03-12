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
run ID                 : ${params.run_id}
input type             : ${params.input_type}
input directory        : ${params.input}
single_sample          : ${params.single_sample}
single-end reads       : ${params.SE}
"""

/*
* check the input type and create relevant channels
*/

if (params.input_type == "bcl") {

  Channel
      .fromPath("${params.input}/*_*_*_*", checkIfExists: true, type: 'dir')
      .ifEmpty { error "Can not find folder ${params.input}" }
      .set { rundir }

  Channel
      .fromPath("${params.input}/*.csv", checkIfExists: true, type: 'file')
      .ifEmpty { error "Cannot find the samplesheet" }
      .set { samplesheet }

}

else if (params.input_type == "fastq") {

  if (params.SE == "NO") {

    if (params.single_sample == "-") {

        Channel
            .fromFilePairs( "${params.input}/**_{R1,R2,1,2}.fastq*" )
            .ifEmpty { error "Cannot find any reads matching: ${params.input}/**_{R1,R2,1,2}.fastq.gz" }
            .branch{
              sarscov2: it =~ /sarscov-2/
              undet: it =~ /Undetermined/
              other: true}.set{ reads_for_trimming }
    }

    else {

      Channel
          .fromPath( "${params.input}/**${params.single_sample}_{R1,R2,1,2}.fastq*" )
          .ifEmpty { error "Cannot find any reads matching: ${params.input}/**_{R1,R2,1,2}.fastq*" }
          .map { file -> tuple(file.simpleName.replaceAll(/_R1|_R2|_1|_2$/,''), file) }
          .groupTuple(sort:true)
          .branch{
            sarscov2: it =~ /sarscov-2/
            undet: it =~ /Undetermined/
            other: true}.set{ reads_for_trimming }
    }

  }

  else if (params.SE == "YES") {

    if (params.single_sample == "-") {

      Channel
          .fromPath( "${params.input}/**{_R1,_1,}.fastq*")
          .filter{ it =~/^(?!.*(_raw_reads))/ }
          .ifEmpty { error "Cannot find any reads matching: ${params.input}**{_R1,_1,}.fastq*" }
          .map { file -> tuple(file.simpleName.replaceAll(/_R1|_1$/,''), file) }
          .branch{
            sarscov2: it =~ /sarscov-2/
            undet: it =~ /Undetermined/
            other: true}.set{ reads_for_trimming }
    }

    else {

      Channel
          .fromPath( "${params.input}/**${params.single_sample}{_R1,_1,}.fastq*")
          .filter{ it =~/^(?!.*(_raw_reads))/ }
          .ifEmpty { error "Cannot find any reads matching: ${params.input}**{_R1,_1,}.fastq*" }
          .map { file -> tuple(file.simpleName.replaceAll(/_R1|_1$/,''), file) }
          .branch{
            sarscov2: it =~ /sarscov-2/
            undet: it =~ /Undetermined/
            other: true}.set{ reads_for_trimming }
    }

  }

}

else if (params.input_type == "fasta") {

  Channel
      .fromFilePairs( "${params.input}/*.{fasta,fna}", size: -1 )
      .ifEmpty { error "Cannot find any fasta matching: ${params.input}/*.{fasta,fna}" }
      .set { genome }
}

Channel
    .value( params.db_rMLST)
    .set { db_rMLST }

Channel
    .value( params.bigsdb_rMLST)
    .set { bigsdb_rMLST }


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

  if (params.SE == "NO") {  
    
    // if starting from bcl files, first process to fastq
    if (params.input_type == "bcl") { 
      bcl2fastq_out = bcl2fastq(rundir, samplesheet)

      bcl2fastq_out.raw_fastq.flatten().branch{
        undet: it =~ /Undetermined/
        other: true}.set{ for_fastqc }
      fastqc_out = fastqc(for_fastqc.other)

      bcl2fastq_out.fastq.flatten().branch{
        sarscov2: it =~ /sarscov-2/
        undet: it =~ /Undetermined/
        other: true}.set{ fastqs }
      trimm_out = trimmomaticPE(fastqs.other.map{ file -> tuple(file.simpleName.replaceAll(/_R1|_R2$/,''), file)}.groupTuple(sort:true))

      mqc_reads_out = multiqc_reads(bcl2fastq_out.reports, fastqc_out.qc.collect(), trimm_out.trim_log.flatten().filter{it =~/quality_read_trimm_info/}.collect())
      linked_reads = link_reads(mqc_reads_out.version)
    }
    
    // if starting from fastq, directly do trimmomatic
    else if (params.input_type == "fastq") {

    bcl2fastq_out = Channel.value(["version": ""]) // since bcl2fastq was not run, make the version channel empty
    fastqc_out = Channel.value(["version": ""]) // since fastqc was not run, make the version channel empty

    trimm_out = trimmomaticPE(reads_for_trimming.other)
    }

      unicycler_out = unicycler(trimm_out.trimmed_reads)
      annotation = prokka(unicycler_out.assembly)
      busco_out = busco(unicycler_out.assembly)
      busco_lineages = get_busco_lineages(busco_out.version.collect())
      busco_plot(busco_out.summary_specific.flatten().filter{it =~/short_summary/}.collect())
      assembly_stats = quast(annotation.fna)
      mqc_assembly_out = multiqc_assembly(trimm_out.trim_log.flatten().filter{it =~/quality_read_trimm_info/}.collect(), assembly_stats.stats.collect(), annotation.annot_all.collect(), busco_out.summary_specific.flatten().filter{it =~/short_summary/}.collect())
      gtdb_out = gtdbtk_classify_wf(annotation.fna)
      typing_rMLST = rMLST(annotation.fna, db_rMLST)
      rmlst_out = call_rMLST(typing_rMLST.blast_tabs, bigsdb_rMLST)
      metaphlan_out = metaphlan4(trimm_out.trimmed_reads)
      one_contig = make_one_contig(annotation.fna)
      bwa_index_remapping = indexRemapping(one_contig)
      remapping = alignRemapping(trimm_out.trimmed_reads.join(bwa_index_remapping.index))
      insertsize = parse_sam_for_insertsize(remapping.sam)
      bam_remapping = samtoolsRemapping(remapping.sam)
      remapping_polished = pilon_remapping(bam_remapping.bam.join(one_contig))
      coverage = coverage_pilon_corrected(remapping_polished.vcf)
      typ16S = typing_16S(one_contig)
      abricate_out = abricate(annotation.fna)
      single_summary = summary_sample(trimm_out.trim_log.join(coverage.ifEmpty("NA"))
                                                        .join(insertsize.ifEmpty("NA"))
                                                        .join(assembly_stats.tsv.ifEmpty("NA"))
                                                        .join(typ16S.blast_tab.ifEmpty("NA"))
                                                        .join(metaphlan_out.profile.ifEmpty("NA"))
                                                        .join(rmlst_out.ifEmpty("NA"))
                                                        .join(busco_out.summary_specific.ifEmpty("NA"))
                                                        .join(gtdb_out.summary.ifEmpty("NA")))
      summary = merge_summaries(single_summary.sample_quality.collect())
      links_for_transfer(one_contig)
      // collecting the versions of the various software
      software_version_channel = trimm_out.version.first().concat(
                              unicycler_out.version.first(),
                              annotation.version.first(),
                              busco_lineages,
                              assembly_stats.version.first(),
                              mqc_assembly_out.version,
                              gtdb_out.version.first(),
                              typing_rMLST.version.first(),
                              metaphlan_out.version.first(),
                              typ16S.version.first(),
                              abricate_out.version.first()).collect()

      if (params.input_type == "bcl") { // if `bcl` input, then bcl2fastq and fastqc where also used
      software_version_channel = software_version_channel.concat(
                                    bcl2fastq_out.version,
                                    fastqc_out.version.first()).collect()
      }

      write_software_versions(software_version_channel)
    }

  if (params.SE == "YES") {
    if (params.input_type == "bcl") {
      bcl2fastq_out = bcl2fastq(rundir, samplesheet)

      bcl2fastq_out.raw_fastq.flatten().branch{
        undet: it =~ /Undetermined/
        other: true}.set{ for_fastqc }
      fastqc_out = fastqc(for_fastqc.other)

      bcl2fastq_out.fastq.flatten().branch{
        sarscov2: it =~ /sarscov-2/
        undet: it =~ /Undetermined/
        other: true}.set{ fastqs }
      trimm_out = trimmomaticSE(fastqs.other.map{ file -> tuple(file.simpleName.replaceAll(/_R1|_R2$/,''), file)}.groupTuple(sort:true))

      mqc_reads_out = multiqc_reads(bcl2fastq_out.reports, fastqc_out.qc.collect(), trimm_out.trim_log.flatten().filter{it =~/quality_read_trimm_info/}.collect())
      linked_reads = link_reads(mqc_reads_out.version)
      unicycler_out = unicyclerSE(trimm_out.trimmed_reads)
      annotation = prokka(unicycler_out.assembly)
      busco_out = busco(unicycler_out.assembly)
      busco_lineages = get_busco_lineages(busco.out.version.collect())
      busco_plot(busco_out.summary_specific.flatten().filter{it =~/short_summary/}.collect())
      assembly_stats = quast(annotation.fna)
      gtdb_out = gtdbtk_classify_wf(annotation.fna)
      mqc_assembly_out = multiqc_assembly(trimm_out.trim_log.flatten().filter{it =~/quality_read_trimm_info/}.collect(), assembly_stats.stats.collect(), annotation.annot_all.collect(), busco_out.summary_specific.flatten().filter{it =~/short_summary/}.collect())
      typing_rMLST = rMLST(annotation.fna, db_rMLST)
      rmlst_out = call_rMLST(typing_rMLST.blast_tabs, bigsdb_rMLST)
      metaphlan_out = metaphlan4SE(trimm_out.trimmed_reads)
      one_contig = make_one_contig(annotation.fna)
      bwa_index_remapping = indexRemapping(one_contig)
      remapping = alignRemappingSE(trimm_out.trimmed_reads.join(bwa_index_remapping.index))
      insertsize = parse_sam_for_insertsize(remapping.sam)
      bam_remapping = samtoolsRemapping(remapping.sam)
      remapping_polished = pilon_remappingSE(bam_remapping.bam.join(one_contig))
      coverage = coverage_pilon_corrected(remapping_polished.vcf)
      typ16S = typing_16S(one_contig)
      abricate_out = abricate(annotation.fna)
      single_summary = summary_sample(trimm_out.trim_log.join(coverage.ifEmpty("NA")).join(insertsize.ifEmpty("NA")).join(assembly_stats.tsv.ifEmpty("NA")).join(typ16S.blast_tab.ifEmpty("NA")).join(metaphlan_out.profile.ifEmpty("NA")).join(rmlst_out.ifEmpty("NA")).join(busco_out.summary_specific.ifEmpty("NA")).join(gtdb_out.summary.ifEmpty("NA")))
      summary = merge_summaries(single_summary.sample_quality.collect())
      links_for_transfer(one_contig)
      write_software_versions(bcl2fastq_out.version.concat(
                              fastqc_out.version.first(),
                              trimm_out.version.first(),
                              unicycler_out.version.first(),
                              annotation.version.first(),
                              busco_lineages,
                              assembly_stats.version.first(),
                              mqc_assembly_out.version,
                              gtdb_out.version.first(),
                              typing_rMLST.version.first(),
                              metaphlan_out.version.first(),
                              typ16S.version.first(),
                              abricate_out.version.first()).collect())
    }

    else if (params.input_type == "fastq") {
      trimm_out = trimmomaticSE(reads_for_trimming.other)
      unicycler_out = unicyclerSE(trimm_out.trimmed_reads)
      annotation = prokka(unicycler_out.assembly)
      busco_out = busco(unicycler_out.assembly)
      busco_lineages = get_busco_lineages(busco.out.version.collect())
      busco_plot(busco_out.summary_specific.flatten().filter{it =~/short_summary/}.collect())
      assembly_stats = quast(annotation.fna)
      mqc_assembly_out = multiqc_assembly(trimm_out.trim_log.flatten().filter{it =~/quality_read_trimm_info/}.collect(), assembly_stats.stats.collect(), annotation.annot_all.collect(), busco_out.summary_specific.flatten().filter{it =~/short_summary/}.collect())
      gtdb_out = gtdbtk_classify_wf(annotation.fna)
      typing_rMLST = rMLST(annotation.fna, db_rMLST)
      rmlst_out = call_rMLST(typing_rMLST.blast_tabs, bigsdb_rMLST)
      metaphlan_out = metaphlan4SE(trimm_out.trimmed_reads)
      one_contig = make_one_contig(annotation.fna)
      bwa_index_remapping = indexRemapping(one_contig)
      remapping = alignRemappingSE(trimm_out.trimmed_reads.join(bwa_index_remapping.index))
      insertsize = parse_sam_for_insertsize(remapping.sam)
      bam_remapping = samtoolsRemapping(remapping.sam)
      remapping_polished = pilon_remappingSE(bam_remapping.bam.join(one_contig))
      coverage = coverage_pilon_corrected(remapping_polished.vcf)
      typ16S = typing_16S(one_contig)
      abricate_out = abricate(annotation.fna)
      single_summary = summary_sample(trimm_out.trim_log.join(coverage.ifEmpty("NA")).join(insertsize.ifEmpty("NA")).join(assembly_stats.tsv.ifEmpty("NA")).join(typ16S.blast_tab.ifEmpty("NA")).join(metaphlan_out.profile.ifEmpty("NA")).join(rmlst_out.ifEmpty("NA")).join(busco_out.summary_specific.ifEmpty("NA")).join(gtdb_out.summary.ifEmpty("NA")))
      summary = merge_summaries(single_summary.sample_quality.collect())
      links_for_transfer(one_contig)
      write_software_versions(trimm_out.version.first().concat(
                              unicycler_out.version.first(),
                              annotation.version.first(),
                              busco_lineages,
                              assembly_stats.version.first(),
                              mqc_assembly_out.version,
                              gtdb_out.version.first(),
                              typing_rMLST.version.first(),
                              metaphlan_out.version.first(),
                              typ16S.version.first(),
                              abricate_out.version.first()).collect())
    }
  }

  if (params.input_type == "fasta") {
      annotation = prokka(genome)
      gtdb_out = gtdbtk_classify_wf(annotation.fna)
      typing_rMLST = rMLST(annotation.fna, db_rMLST)
      rmlst_out = call_rMLST(typing_rMLST.blast_tabs, bigsdb_rMLST)
      one_contig = make_one_contig(annotation.fna)
      typ16S = typing_16S(one_contig)
      abricate_out = abricate(annotation.fna)
      links_for_transfer(one_contig)
      write_software_versions(annotation.version.first().concat(
                              gtdb_out.version.first(),
                              typing_rMLST.version.first(),
                              typ16S.version.first(),
                              abricate_out.version.first()).collect())
  }
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

    quality_tab = file("${params.run_id}_transfer_result/${params.run_id}_quality.tab")
    mulQC_ass = file("${params.run_id}_transfer_result/${params.run_id}_multiqc_assembly_report.html")
    mulQC_reads = file("demultiplexing/multiqc/${params.run_id}_multiqc_reads.html")
    dashb = file("${params.run_id}_transfer_result/QC_dashboard.html")

        sendMail{
          to "${params.email}"
          subject "IMMENSE ${params.run_id} complete"
          body msg
          if (quality_tab.exists()) { attach "${params.run_id}_transfer_result/${params.run_id}_quality.tab" }
          if (dashb.exists()) { attach "${params.run_id}_transfer_result/QC_dashboard.html" }
          if (mulQC_ass.exists()) { attach "${params.run_id}_transfer_result/${params.run_id}_multiqc_assembly_report.html", fileName: "multiqc_report_assembly.html" }
          if (mulQC_reads.exists()) { attach "demultiplexing/multiqc/${params.run_id}_multiqc_reads.html", fileName: "multiqc_report_reads.html" }
        }
    }
}
