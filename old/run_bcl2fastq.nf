#!/usr/bin/env nextflow

nextflow.enable.dsl=2

/*
 * Define the pipeline parameters
 *
 */

// Pipeline version
version = '0.4'

// this prints the input parameters
log.info """
USBacto ~  version ${version}
=============================================
input type             : ${params.input_type}
input directory        : ${params.input}
single-end reads       : ${params.SE}
"""

if (params.input_type == "bcl") {
  Channel
      .fromPath("${params.input}/*_*_*_*", checkIfExists: true, type: 'dir')
      .ifEmpty { error "Can not find folder ${params.input}" }
      .set { rundir }

  Channel
      .fromPath("${params.input}/*.csv", checkIfExists: true, type: 'file')
      .ifEmpty { error "Cannot find the samplesheet" }
      .set { samplesheet }

} else if (params.input_type == "fastq") {
  Channel
      .fromFilePairs( "${params.input}/**/*_R{1,2}.fastq.gz", size: -1 )
      .ifEmpty { error "Cannot find any reads matching: ${params.input}/**/*_R{1,2}.fastq.gz" }
      .branch{
        sarscov2: it =~ /sarscov-2/
        undet: it =~ /Undetermined/
        other: true}.set{ reads_for_trimming }

} else if (params.input_type == "fasta") {
  Channel
      .fromFilePairs( "${params.input}/*.fasta", size: -1 )
      .ifEmpty { error "Cannot find any fasta matching: ${params.input}/**/*.fasta" }
      .set { genome }
}


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
include { quast } from "./modules/quast"
include { rMLST; call_rMLST } from "./modules/rMLST"
include { metaphlan3; metaphlan3SE } from "./modules/metaphlan"
include { make_one_contig; parse_sam_for_insertsize; coverage_pilon_corrected } from "./modules/python_functions"
include { bwaIndex as indexRemapping } from "./modules/bwa_index"
include { bwaAlign as alignRemapping; bwaAlignSE as alignRemappingSE } from "./modules/bwa-mem"
include { samtools as samtoolsRemapping} from "./modules/samtools"
include { typing_16S } from "./modules/typing_16S.nf"
include { abricate } from "./modules/abricate"
include { summary_sample; merge_summaries } from "./modules/summary"

// workflow

workflow {

  if (params.SE == "NO") {
    if (params.input_type == "bcl") {
      bcl2fastq_out = bcl2fastq(rundir, samplesheet)

      bcl2fastq_out.raw_fastq.flatten().branch{
        undet: it =~ /Undetermined/
        other: true}.set{ for_fastqc }
      fastqc_out = fastqc(for_fastqc.other)

      linked_reads = link_reads(fastqc_out.collect())

      bcl2fastq_out.fastq.flatten().branch{
        sarscov2: it =~ /sarscov-2/
        undet: it =~ /Undetermined/
        other: true}.set{ fastqs }
      trimm_out = trimmomaticPE(fastqs.other.map{ file -> tuple(file.simpleName.replaceAll(/_R1|_R2$/,''), file)}.groupTuple(sort:true), illuminaclip)

      multiqc_reads(bcl2fastq_out.reports, fastqc_out.collect(), trimm_out.trim_log.flatten().filter{it =~/quality_read_trimm_info/}.collect())
      unicycler_out = unicycler(trimm_out.trimmed_reads)
      bwa_index_polishing = bwaIndex(unicycler_out.assembly)
      mapping = bwaAlign(trimm_out.trimmed_reads.join(bwa_index_polishing))
      bam = samtools(mapping)
      polished_assembly = pilon(bam.join(unicycler_out.assembly))
      annotation = prokka(polished_assembly.assembly)
      assembly_stats = quast(annotation.fna)
      multiqc_assembly(trimm_out.trim_log.flatten().filter{it =~/quality_read_trimm_info/}.collect(), assembly_stats.stats.collect(), annotation.annot_all.collect())
      typing_rMLST = rMLST(annotation.fna, db_rMLST)
      rmlst_out = call_rMLST(typing_rMLST, bigsdb_rMLST)
      metaphlan_out = metaphlan3(trimm_out.trimmed_reads)
      one_contig = make_one_contig(annotation.fna)
      bwa_index_remapping = indexRemapping(one_contig)
      remapping = alignRemapping(trimm_out.trimmed_reads.join(bwa_index_remapping))
      bam_remapping = samtoolsRemapping(remapping)
      insertsize = parse_sam_for_insertsize(remapping)
      remapping_polished = pilon_remapping(bam_remapping.join(one_contig))
      coverage = coverage_pilon_corrected(remapping_polished.vcf)
      typ16S = typing_16S(one_contig, db_16s)
      abricate(annotation.fna)
      single_summary = summary_sample(trimm_out.trim_log.join(coverage).join(insertsize).join(assembly_stats.tsv).join(typ16S).join(metaphlan_out.profile).join(rmlst_out))
      summary = merge_summaries(single_summary.sample_quality.collect())
      links_for_transfer(one_contig)
    }

    else if (params.input_type == "fastq") {
      trimm_out = trimmomaticPE(reads_for_trimming.other, illuminaclip)
      unicycler_out = unicycler(trimm_out.trimmed_reads)
      bwa_index_polishing = bwaIndex(unicycler_out.assembly)
      mapping = bwaAlign(trimm_out.trimmed_reads.join(bwa_index_polishing))
      bam = samtools(mapping)
      polished_assembly = pilon(bam.join(unicycler_out.assembly))
      annotation = prokka(polished_assembly.assembly)
      assembly_stats = quast(annotation.fna)
      multiqc_assembly(trimm_out.trim_log.flatten().filter{it =~/quality_read_trimm_info/}.collect(), assembly_stats.stats.collect(), annotation.annot_all.collect())
      typing_rMLST = rMLST(annotation.fna, db_rMLST)
      rmlst_out = call_rMLST(typing_rMLST, bigsdb_rMLST)
      metaphlan_out = metaphlan3(trimm_out.trimmed_reads)
      one_contig = make_one_contig(annotation.fna)
      bwa_index_remapping = indexRemapping(one_contig)
      remapping = alignRemapping(trimm_out.trimmed_reads.join(bwa_index_remapping))
      bam_remapping = samtoolsRemapping(remapping)
      insertsize = parse_sam_for_insertsize(remapping)
      remapping_polished = pilon_remapping(bam_remapping.join(one_contig))
      coverage = coverage_pilon_corrected(remapping_polished.vcf)
      typ16S = typing_16S(one_contig, db_16s)
      abricate(annotation.fna)
      single_summary = summary_sample(trimm_out.trim_log.join(coverage).join(insertsize).join(assembly_stats.tsv).join(typ16S).join(metaphlan_out.profile).join(rmlst_out))
      summary = merge_summaries(single_summary.sample_quality.collect())
      links_for_transfer(one_contig)
    }

/*  else if (params.input_type == "fasta") {
    annotation = prokka(genome)
    assembly_stats = quast(annotation.fna)
    //multiqc_assembly(trimm_out.trim_log.flatten().filter{it =~/quality_read_trimm_info/}.collect(), assembly_stats.stats, annotation.annot_all)
    typing_rMLST = rMLST(annotation.fna, db_rMLST)
    rmlst_out = call_rMLST(typing_rMLST, bigsdb_rMLST)
    //metaphlan_out = metaphlan3(trimm_out.trimmed_reads)
    one_contig = make_one_contig(annotation.fna)
    bwa_index_remapping = indexRemapping(one_contig)
    remapping = alignRemapping(trimm_out.trimmed_reads.join(bwa_index_remapping))
    bam_remapping = samtoolsRemapping(remapping)
    insertsize = parse_sam_for_insertsize(remapping)
    remapping_polished = pilon_remapping(bam_remapping.join(one_contig))
    coverage = coverage_pilon_corrected(remapping_polished.vcf)
    typ16S = typing_16S(one_contig, db_16s)
    abricate(annotation.fna)
    //single_summary = summary_sample(trimm_out.trim_log.join(coverage).join(insertsize).join(assembly_stats.tsv).join(typ16S).join(metaphlan_out.profile).join(rmlst_out))
    //summary = merge_summaries(single_summary.sample_quality.collect())
    } */
  }

  if (params.SE == "YES") {
    if (params.input_type == "bcl") {
      bcl2fastq_out = bcl2fastq(rundir, samplesheet)

      bcl2fastq_out.raw_fastq.flatten().branch{
        undet: it =~ /Undetermined/
        other: true}.set{ for_fastqc }
      fastqc_out = fastqc(for_fastqc.other)

      linked_reads = link_reads(fastqc_out.collect())

      bcl2fastq_out.fastq.flatten().branch{
        sarscov2: it =~ /sarscov-2/
        undet: it =~ /Undetermined/
        other: true}.set{ fastqs }
      trimm_out = trimmomaticSE(fastqs.other.map{ file -> tuple(file.simpleName.replaceAll(/_R1|_R2$/,''), file)}.groupTuple(sort:true), illuminaclip)

      multiqc_reads(bcl2fastq_out.reports, fastqc_out.collect(), trimm_out.trim_log.flatten().filter{it =~/quality_read_trimm_info/}.collect())
      unicycler_out = unicyclerSE(trimm_out.trimmed_reads)
      bwa_index_polishing = bwaIndex(unicycler_out.assembly)
      mapping = bwaAlignSE(trimm_out.trimmed_reads.join(bwa_index_polishing))
      bam = samtools(mapping)
      polished_assembly = pilonSE(bam.join(unicycler_out.assembly))
      annotation = prokka(polished_assembly.assembly)
      assembly_stats = quast(annotation.fna)
      multiqc_assembly(trimm_out.trim_log.flatten().filter{it =~/quality_read_trimm_info/}.collect(), assembly_stats.stats.collect(), annotation.annot_all.collect())
      typing_rMLST = rMLST(annotation.fna, db_rMLST)
      rmlst_out = call_rMLST(typing_rMLST, bigsdb_rMLST)
      metaphlan_out = metaphlan3SE(trimm_out.trimmed_reads)
      one_contig = make_one_contig(annotation.fna)
      bwa_index_remapping = indexRemapping(one_contig)
      remapping = alignRemappingSE(trimm_out.trimmed_reads.join(bwa_index_remapping))
      bam_remapping = samtoolsRemapping(remapping)
      insertsize = parse_sam_for_insertsize(remapping)
      remapping_polished = pilon_remappingSE(bam_remapping.join(one_contig))
      coverage = coverage_pilon_corrected(remapping_polished.vcf)
      typ16S = typing_16S(one_contig, db_16s)
      abricate(annotation.fna)
      single_summary = summary_sample(trimm_out.trim_log.join(coverage).join(insertsize).join(assembly_stats.tsv).join(typ16S).join(metaphlan_out.profile).join(rmlst_out))
      summary = merge_summaries(single_summary.sample_quality.collect())
      links_for_transfer(one_contig)
    }

    else if (params.input_type == "fastq") {
      trimm_out = trimmomaticSE(reads_for_trimming.other, illuminaclip)
      unicycler_out = unicyclerSE(trimm_out.trimmed_reads)
      bwa_index_polishing = bwaIndex(unicycler_out.assembly)
      mapping = bwaAlignSE(trimm_out.trimmed_reads.join(bwa_index_polishing))
      bam = samtools(mapping)
      polished_assembly = pilonSE(bam.join(unicycler_out.assembly))
      annotation = prokka(polished_assembly.assembly)
      assembly_stats = quast(annotation.fna)
      multiqc_assembly(trimm_out.trim_log.flatten().filter{it =~/quality_read_trimm_info/}.collect(), assembly_stats.stats.collect(), annotation.annot_all.collect())
      typing_rMLST = rMLST(annotation.fna, db_rMLST)
      rmlst_out = call_rMLST(typing_rMLST, bigsdb_rMLST)
      metaphlan_out = metaphlan3SE(trimm_out.trimmed_reads)
      one_contig = make_one_contig(annotation.fna)
      bwa_index_remapping = indexRemapping(one_contig)
      remapping = alignRemappingSE(trimm_out.trimmed_reads.join(bwa_index_remapping))
      bam_remapping = samtoolsRemapping(remapping)
      insertsize = parse_sam_for_insertsize(remapping)
      remapping_polished = pilon_remappingSE(bam_remapping.join(one_contig))
      coverage = coverage_pilon_corrected(remapping_polished.vcf)
      typ16S = typing_16S(one_contig, db_16s)
      abricate(annotation.fna)
      single_summary = summary_sample(trimm_out.trim_log.join(coverage).join(insertsize).join(assembly_stats.tsv).join(typ16S).join(metaphlan_out.profile).join(rmlst_out))
      summary = merge_summaries(single_summary.sample_quality.collect())
      links_for_transfer(one_contig)
    }
  }

  workflow.onComplete {
    println "Pipeline completed!"
  }
}
