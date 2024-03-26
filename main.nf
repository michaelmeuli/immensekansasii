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

    //TODO: make this ELSE statement obsolete by making params.single_sample default to ""
    else {  

      Channel
        .fromPath( "${params.input}/**${params.single_sample}_{R1,R2,1,2}.fastq*" )
        .ifEmpty { error "Cannot find any reads matching: ${params.input}/**${params.single_sample}_{R1,R2,1,2}.fastq*" }
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

    // TODO: Make this ELSE statement obsolete by setting params.single_sample to empty string
    else {
      Channel
          .fromPath( "${params.input}/${params.single_sample}**{_R1,_1,}.fastq*")
          .filter{ it =~/^(?!.*(_raw_reads))/ }
          .ifEmpty { error "Cannot find any reads matching: ${params.input}**${params.single_sample}{_R1,_1,}.fastq*" }
          .map { file -> tuple(file.simpleName.replaceAll(/_R1|_1$/,''), file) }
          .branch{
            sarscov2: it =~ /sarscov-2/
            undet: it =~ /Undetermined/
            other: true}.set{ reads_for_trimming }
    }

  }

}

else if (params.input_type == "fasta") {
  //TODO: check if it makes sense that fromFilePairs is used for fasta files
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

  if (params.input_type != "fasta") {
  // if starting from bcl files, first process to fastq
  if (params.input_type == "bcl") { 
    bcl2fastq_out = bcl2fastq(rundir, samplesheet)

    // send raw reads to fastqc
    bcl2fastq_out.raw_fastq.flatten().branch{
      undet: it =~ /Undetermined/
      other: true}.set{ for_fastqc }

    // send raw reads to trimmomatic
    bcl2fastq_out.fastq.flatten().branch{
      sarscov2: it =~ /sarscov-2/
      undet: it =~ /Undetermined/
      other: true}.set{ fastqs }

    fastqc_out = fastqc(for_fastqc.other)

    // Depending if its paired-end reads or not, trim differently
    if (params.SE == "NO") {  
    trimm_out = trimmomaticPE(fastqs.other.map{ file -> tuple(file.simpleName.replaceAll(/_R1|_R2$/,''), file)}.groupTuple(sort:true))
    } else if (params.SE == "YES") {
    trimm_out = trimmomaticSE(fastqs.other.map{ file -> tuple(file.simpleName.replaceAll(/_R1|_R2$/,''), file)}.groupTuple(sort:true))
    }

    mqc_reads_out = multiqc_reads(bcl2fastq_out.reports, fastqc_out.qc.collect(), trimm_out.trim_log.flatten().filter{it =~/quality_read_trimm_info/}.collect())
    linked_reads = link_reads(mqc_reads_out.version)
  }
    
  // if starting from fastq, directly do trimmomatic
  else if (params.input_type == "fastq") {
    if (params.SE == "NO") {  
      trimm_out = trimmomaticPE(reads_for_trimming.other)
    } else if (params.SE == "YES") {
      trimm_out = trimmomaticSE(reads_for_trimming.other)
    }
  }

  // Checking that input files are large enough (otherwise processes fail)
  // After trimming, check that reads are still at least 1MB: if too small then put in failed channel to track them.
  if (params.SE == "NO") {  
    trimm_out.trimmed_reads.branch { // check paired-end reads
      failed: (file(it[1]).size() < 1.MB && file(it[2]).size() < 1.MB) //it[1] is read_r1 and it[2] is read_r2
      passed: (file(it[1]).size() >= 1.MB || file(it[2]).size() >= 1.MB)
      }
      .set { trimm_out_checked }
  } else if (params.SE == "YES") { // Check single-end reads
    trimm_out.trimmed_reads.branch {
      failed: ( file(it[1]).size() < 1.MB )
      passed: ( file(it[1]).size() >= 1.MB )
      }
      .set { trimm_out_checked }
  }

    qc_size_passed = trimm_out_checked.passed.map { sample ->
    // Assuming the first element of each tuple is sample_id
    return [sample[0], ""]
    }

    qc_size_failed = trimm_out_checked.failed.map { sample ->
    // Assuming the first element of each tuple is sample_id
    return [sample[0], "Trimmed fastq below 1MB - Assembly skipped"] // the note to put into the quality.csv file
    }
    // collect warning if files are not large enough
    qc_size_warning = qc_size_passed.concat(qc_size_failed)

    // Debug: View how files are passed on
    //trimm_out_checked.passed.view{ item -> "Passed Reads Key: ${item[0]}, read1: ${item[1]}, read2: ${item[2]}, read1_size: ${file(item[1]).size()}, read2_size: ${file(item[2]).size()}" }
    //trimm_out_checked.failed.view{ item -> "Failed Reads Key: ${item[0]}, read1: ${item[1]}, read2: ${item[2]}, read1_size: ${file(item[1]).size()}, read2_size: ${file(item[2]).size()}" }
      
      // Different assembly depending on single-end or paired-end reads
      if (params.SE == "NO") {  
        unicycler_out = unicycler(trimm_out_checked.passed)
      } else if (params.SE == "YES") {
        unicycler_out = unicyclerSE(trimm_out_checked.passed)
      }

      annotation = prokka(unicycler_out.assembly)
      busco_out = busco(unicycler_out.assembly)
      busco_lineages = get_busco_lineages(busco_out.version.collect())
      busco_plot(busco_out.summary_specific.flatten().filter{it =~/short_summary/}.collect())
      assembly_stats = quast(annotation.fna)
      mqc_assembly_out = multiqc_assembly(trimm_out.trim_log.flatten().filter{it =~/quality_read_trimm_info/}.collect(), 
                                          assembly_stats.stats.collect(), annotation.annot_all.collect(), 
                                          busco_out.summary_specific.flatten().filter{it =~/short_summary/}.collect())
      gtdb_out = gtdbtk_classify_wf(annotation.fna)
      typing_rMLST = rMLST(annotation.fna)
      rmlst_out = call_rMLST(typing_rMLST.blast_tabs)
      one_contig = make_one_contig(annotation.fna)
      bwa_index_remapping = indexRemapping(one_contig)

      // Different metaphlan4 & alignment depending on single-end or paired-end reads
      if (params.SE == "NO") {  
        metaphlan_out = metaphlan4(trimm_out_checked.passed.concat(trimm_out_checked.failed))
        remapping = alignRemapping(trimm_out_checked.passed.join(bwa_index_remapping.index))
        insertsize = parse_sam_for_insertsize(remapping.sam)
        bam_remapping = samtoolsRemapping(remapping.sam)
        remapping_polished = pilon_remapping(bam_remapping.bam.join(one_contig))

      } else if (params.SE == "YES") {
        metaphlan_out = metaphlan4SE(trimm_out_checked.passed.concat(trimm_out_checked.failed))
        remapping = alignRemappingSE(trimm_out_checked.passed.join(bwa_index_remapping.index))
        insertsize = parse_sam_for_insertsize(remapping.sam)
        bam_remapping = samtoolsRemapping(remapping.sam)
        remapping_polished = pilon_remappingSE(bam_remapping.bam.join(one_contig))
      }

      coverage = coverage_pilon_corrected(remapping_polished.vcf)
      typ16S = typing_16S(one_contig)
      abricate_out = abricate(annotation.fna)

      summary_channel = trimm_out.passed_reads_percentage.join(trimm_out.passed_reads_number, remainder: true)
                                                        .join(coverage.read_depth, remainder: true)
                                                        .join(coverage.alt_bases, remainder: true)  
                                                        .join(insertsize.insert_size, remainder: true)
                                                        .join(assembly_stats.number_contigs, remainder: true)
                                                        .join(assembly_stats.total_length, remainder: true)
                                                        .join(assembly_stats.n50, remainder: true)
                                                        .join(assembly_stats.gc_percent, remainder: true)
                                                        .join(typ16S.taxa, remainder: true)
                                                        .join(typ16S.aln_length, remainder: true)
                                                        .join(typ16S.aln_identity, remainder: true)
                                                        .join(metaphlan_out.taxa, remainder: true)
                                                        .join(metaphlan_out.purity, remainder: true)
                                                        .join(rmlst_out.taxa, remainder: true)    
                                                        .join(rmlst_out.best_rST, remainder: true)    
                                                        .join(rmlst_out.alleles_missing, remainder: true)    
                                                        .join(busco_out.complete_busco, remainder: true)
                                                        .join(busco_out.busco_groups, remainder: true)
                                                        .join(busco_out.busco_lineage, remainder: true)                                                     
                                                        .join(gtdb_out.species, remainder: true)
                                                        .join(gtdb_out.ani_ref, remainder: true)
                                                        .join(gtdb_out.ani_ani, remainder: true)
                                                        .join(gtdb_out.ani_af, remainder: true)
                                                        .join(gtdb_out.placement_ref, remainder: true)
                                                        .join(gtdb_out.gtdb_notes, remainder: true)
                                                        .join(qc_size_warning, remainder: true)
      // summary_channel.view() // To see what gets passed to the summary processes

      single_summary = summary_sample(summary_channel)

      summary = merge_summaries(single_summary.sample_quality.collect(sort: true))

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
