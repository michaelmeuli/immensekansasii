#!/usr/bin/env nextflow

nextflow.enable.dsl=2

/*
 * Define the pipeline parameters
 */

def currentUser = System.getenv('USER')
params.skip_gtdb = false
params.skip_checkm = false
params.skip_busco = false

// this prints the input parameters
log.info """
IMMENSE  ~  version ${workflow.manifest.version}

Anything you have to do repeatedly
may be ripe for automation.
— Doug McIlroy

=============================================
Pipeline Directory         : ${workflow.projectDir}
run ID                     : ${params.run_id}
input type                 : ${params.input_type}
input directory            : ${params.input}
input directory (absolute) : ${params.input_absolutePath}
single_sample              : ${params.single_sample}
single-end reads           : ${params.SE}
User                       : ${currentUser}
Launch Directory           : ${workflow.launchDir}
singularity_container_cache: ${params.singularity_container_cache}
Email                      : ${params.email}

"""

/*
* check the input type and create relevant channels
*/

if (params.single_sample.contains('{')) {
  println "--single_sample: ${params.single_sample}"
  error "ERROR: The `--single_sample` argument must not contain curly brackets, this breaks the fromFilePairs() grouping. You can only define a single sample or a prefix of multiple samples."
}

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
      Channel
        .fromFilePairs( "${params.input}/**${params.single_sample}*_{R1,R2,1,2}.fastq.gz")
        .ifEmpty { error "Cannot find any reads matching: ${params.input}/**${params.single_sample}*_{R1,R2,1,2}.fastq.gz" }
        // .view { "Identified files: $it" }
        .branch{
          sarscov2: it =~ /sarscov-2/
          undet: it =~ /Undetermined/
          other: true}.set{ reads_for_trimming }
  }
  
  else if (params.SE == "YES") {
        Channel
        .fromFilePairs( "${params.input}/**${params.single_sample}*_{R1,1}.fastq.gz")
        .ifEmpty { error "Cannot find any reads matching: ${params.input}/**${params.single_sample}*_{R1,1}.fastq.gz" }
        //.view { "Identified files: $it" }
        .branch{
          sarscov2: it =~ /sarscov-2/
          undet: it =~ /Undetermined/
          other: true}.set{ reads_for_trimming }
  }
  }

else if (params.input_type == "fasta") {
  Channel
      .fromFilePairs( "${params.input}/**${params.single_sample}*.{fasta,fna}", size: 1 )
      .ifEmpty { error "Cannot find any fasta matching: ${params.input}/**${params.single_sample}*.{fasta,fna}" }
      .map {sample_id, fasta -> return [sample_id, fasta[0]]}
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

include { bcl2fastq }                                        from "./modules/bcl2fastq"
include { link_reads; links_for_transfer }                   from "./modules/create_links"
include { fastqc_raw_reads; fastqc_trimmed_reads }           from "./modules/fastqc"
include { multiqc_bcl; multiqc_raw_fastqc; 
          multiqc_trimmed_fastqc; multiqc_assembly }         from "./modules/multiqc"
include { trimmomaticPE; trimmomaticSE }                     from "./modules/trimmomatic"
include { unicycler; unicyclerSE }                           from "./modules/unicycler"
include { pilon_remapping; pilon_remappingSE }               from "./modules/pilon"
include { prokka }                                           from "./modules/prokka"
include { busco; get_busco_lineages; busco_plot }            from "./modules/busco"
include { checkm }                                           from "./modules/checkm"
include { quast }                                            from "./modules/quast"
include { gtdbtk_classify_wf; extract_gtdb_output }          from "./modules/gtdbtk"
include { rMLST; rMLST_call }                                from "./modules/rMLST"
include { metaphlan4; metaphlan4SE; classify_metaphlan4_results } from "./modules/metaphlan"
include { make_one_contig; parse_sam_for_insertsize; 
          coverage_pilon_corrected }                         from "./modules/python_functions"
include { bwaIndex as indexRemapping }                       from "./modules/bwa_index"
include { bwaAlign; 
          bwaAlignSE }                                       from "./modules/bwa-mem"
include { samtools as samtoolsRemapping}                     from "./modules/samtools"
include { typing_16S }                                       from "./modules/typing_16S.nf"
include { abricate }                                         from "./modules/abricate"
include { summary_sample; merge_summaries }                  from "./modules/summary"
include { write_software_versions }                          from "./modules/write_software_versions"
include { generate_resistance_table; merge_run_resistances }  from "./modules/resistance_table"
include { pymlst_add_strain; pymlst_distance; pymlst_subgraph} from "./modules/pymlst"
include { amrfinderplus  }                                    from  "./modules/amrfinderplus"
include { bakta         }                                      from "./modules/bakta"


/*
* main workflow
*/

workflow {

  if (params.input_type != "fasta") {
  // if starting from bcl files, first generate fastq
  if (params.input_type == "bcl") { 
    bcl2fastq_out = bcl2fastq(rundir, samplesheet)

    // send raw reads to trimmomatic
    bcl2fastq_out.fastq.flatten().branch{
                                  undet:    it =~ /Undetermined/
                                  other:    true
                                  }
                                 .set{ fastqs }

    // Send reads to trimmomatic, format it the exact same as if input were fastq files
    reads_for_trimming          = [:]
    reads_for_trimming['other'] = fastqs.other.map{ file -> tuple(file.simpleName.replaceAll(/_R1|_R2$/,''), file)}.groupTuple(sort:true)
    // wait for all files to be converted and then put reads in demultiplex subfolder
    linked_reads                = link_reads(bcl2fastq_out.finished.collect())
    multiqc_bcl_out             = multiqc_bcl(bcl2fastq_out.reports) 
    // End of BCL-specific pipeline
  }
  
  // Running fastQC on fastq reads before trimming and generating multiQC report
  fastqc_raw_reads_out   = fastqc_raw_reads(reads_for_trimming.other) // extract only the reads without sample_id
  multiqc_raw_fastqc_out = multiqc_raw_fastqc(fastqc_raw_reads_out.output.collect())

  // TODO: Deterministic GTDBtk batches (to allow resume to work)
  // Assign sample_ids to batches for processes that do batch processing (ie. GTDBtk)
  // This way, the batches are deterministic based on input files which is important for --resume to work


  // Trimming reads with trimmomatic
  if (params.SE == "NO") {  
      trimm_out = trimmomaticPE(reads_for_trimming.other)
    } else if (params.SE == "YES") {
      trimm_out = trimmomaticSE(reads_for_trimming.other)
    }
  
  // Run fastQC on trimmed reads & create multiQC report
  fastqc_trimmed_reads_out   = fastqc_trimmed_reads(trimm_out.fastqc) // extract only the reads without sample_id
  multiqc_trimmed_fastqc_out = multiqc_trimmed_fastqc(fastqc_trimmed_reads_out.output.collect(), trimm_out.trim_log.flatten().filter{it =~/quality_read_trimm_info/}.collect())

  // Checking that input files have enough data (otherwise processes fail)
  // After trimming, check that reads are still at least 1MB: if too small then put in failed channel to track them in output file but skip processing.
  if (params.SE == "NO") {  
      trimm_out.trimmed_reads.branch { // check paired-end reads
        failed: (file(it[1]).size() <  1.MB && file(it[2]).size() <  1.MB) //it[1] is read_r1 and it[2] is read_r2
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

    qc_size_passed    = trimm_out_checked.passed.map { sample ->
                                                       // Assuming the first element of each tuple is sample_id
                                                       return [sample[0], ""]
                                                     }
    qc_size_failed    = trimm_out_checked.failed.map { sample ->
                                                       // the note to put into the quality.csv file
                                                       return [sample[0], "Fastq below 1MB after trimming - Assembly skipped"] 
                                                     }

    // Collect warning if files are not large enough - gets included in summary output file
    qc_size_warning   = qc_size_passed.concat(qc_size_failed)

    // Debug: View how files are passed on
    //trimm_out_checked.passed.view{ item -> "Passed Reads Key: ${item[0]}, read1: ${item[1]}, read2: ${item[2]}, read1_size: ${file(item[1]).size()}, read2_size: ${file(item[2]).size()}" }
    //trimm_out_checked.failed.view{ item -> "Failed Reads Key: ${item[0]}, read1: ${item[1]}, read2: ${item[2]}, read1_size: ${file(item[1]).size()}, read2_size: ${file(item[2]).size()}" }
      
      // Different assembly depending on single-end or paired-end reads
      if (params.SE == "NO") {  
        unicycler_out = unicycler(trimm_out_checked.passed)
      } else if (params.SE == "YES") {
        unicycler_out = unicyclerSE(trimm_out_checked.passed)
      }
  // End of pipeline to get to assemblies
  } 
  if (params.input_type == "fasta") {
    // Define an empty unicycler_out object
    unicycler_out = [:]
    // Add the genome fasta files in the "assembly" channel within unicycler_out
    unicycler_out.assembly = genome
  }

      // These processes are the same for single-end and paired-end datasets:
      annotation          = bakta(unicycler_out.assembly)
      busco_out           = busco(params.skip_busco? Channel.empty() : unicycler_out.assembly)
      busco_lineages      = get_busco_lineages(params.skip_busco? Channel.empty() :busco_out.version.collect())
      busco_plot(params.skip_busco? Channel.empty() : busco_out.summary_specific)
      assembly_stats      = quast(unicycler_out.assembly)
      mqc_assembly_out    = multiqc_assembly( assembly_stats.stats.collect(), 
                                              annotation.annot_all.collect(), 
                                              params.skip_busco? Channel.empty() : busco_out.summary_specific.flatten().filter{it =~/short_summary/}.collect()
                                              )
      
      // If GTDB is run, it's run on 25 samples at one time and then afterwards the results are pulled apart again
      if (!params.skip_gtdb) {  
      // Remove sample_id from tuple so that the fasta files can be put into batches
      batched_samples_temp = unicycler_out.assembly.map{sample_id, fasta -> return fasta}
      // Assign a batch number so that log files can be tracked per batch
      def gtdb_batch_number = 0
      batched_samples = batched_samples_temp.toSortedList().collate(25, remainder = true).map { assemblies -> gtdb_batch_number += 1 
                                                                          return [gtdb_batch_number, assemblies]}
      
      // batched_samples.view()                                                                    
      // Run GTDB on batched assemblies
      gtdb_out_batched            = gtdbtk_classify_wf(batched_samples)
      // Make tuple with sample_id derived from filenames
      gtdb_out_batched_argumented = gtdb_out_batched.summary_files.flatten().map {it -> return [it.getSimpleName(), it ] }
      // gtdb_out_batched_argumented.view()
      // Extract GTDB results for each individual assembly
      gtdb_out = extract_gtdb_output( gtdb_out_batched_argumented )
      }
      
      typing_rMLST        = rMLST(unicycler_out.assembly)
      rmlst_out           = rMLST_call(typing_rMLST.blast_tabs)
      one_contig          = make_one_contig(annotation.fna)
      bwa_index_remapping = indexRemapping(one_contig)

      // Run pyMLST based on rMLST species identification
      pymlst_out          = pymlst_add_strain(rmlst_out.rmlst.join(unicycler_out.assembly))
      distance            = pymlst_distance(pymlst_out.summary_specific.join(rmlst_out.rmlst))
      pymlst_subgraph(pymlst_out.summary_specific.join(rmlst_out.rmlst).join(distance.pymlst_distance))
      
      if (params.input_type != "fasta") {
      // These processes cannot run if the input was finished assemblies
      // Different metaphlan4 & alignment depending on single-end or paired-end reads
      if (params.SE == "NO") {  
        metaphlan_out      = metaphlan4(trimm_out_checked.passed.concat(trimm_out_checked.failed))
        remapping          = bwaAlign(trimm_out_checked.passed.join(bwa_index_remapping.index))
        insertsize         = parse_sam_for_insertsize(remapping.sam)
        bam_remapping      = samtoolsRemapping(remapping.sam)
        remapping_polished = pilon_remapping(bam_remapping.bam.join(one_contig))

      } else if (params.SE == "YES") {
        metaphlan_out      = metaphlan4SE(trimm_out_checked.passed.concat(trimm_out_checked.failed))
        remapping          = bwaAlignSE(trimm_out_checked.passed.join(bwa_index_remapping.index))
        insertsize         = parse_sam_for_insertsize(remapping.sam)
        bam_remapping      = samtoolsRemapping(remapping.sam)
        remapping_polished = pilon_remappingSE(bam_remapping.bam.join(one_contig))
      }

      metaphlan4_classified = classify_metaphlan4_results(metaphlan_out.profile)
      // Only run checkM it it's a bacterium (checkM only works for prokaryotes)
      samples_to_run_checkM_ch = unicycler_out.assembly
                        .join(metaphlan4_classified.bacteria, remainder: false)
                        // Only samples where assembly & bacterial classification is true will remain in channel
                        .map { item -> return [item[0], item[1]]} // Return only the first two elements of the tuple (sample_id, assembly)
      
      checkm_out          = checkm(params.skip_checkm? Channel.empty() : samples_to_run_checkM_ch)      // if --skip_checkm flag is set, the input channel will be empty
      coverage     = coverage_pilon_corrected(remapping_polished.vcf)
      // End of processes that require input reads
      }

      typ16S       = typing_16S(one_contig)
      abricate_out = abricate(annotation.fna)
      amrfinderplus_out = amrfinderplus(annotation.fna)

      // Summarize Abricate output and create summary for run
      summarized_resistances = generate_resistance_table(abricate_out.sample_id, abricate_out.resistance)
      merge_run_resistances(summarized_resistances.output_file.collect(sort: true))

      // Preparing empty channels for summary results and versions in case a process was not run
      empty_channel_per_sample = unicycler_out.assembly.map {
                                                                sample_id, value -> return [sample_id, "skipped"]
                                                                }
      empty_version_channel = channel.fromPath( "${workflow.projectDir}/bin/empty_version_channel.txt")

      // Collecting all channels into a variable so we can check which channels exist.
      // If a channel does not exist, that process was not executed and summary files 
      // should say "skipped" by using 'empty_channel_per_sample'
      def all_channels = getVariables()
      
      // the `remainder: true` ensures that if some result doesn't exist, it will 
      // be replaced by `NA` in the output summary file. Therefore each value must 
      // represent 1 column in the summary output.
      summary_channel = empty_channel_per_sample.map { sample_id, value -> return [sample_id]}
                                                .join(all_channels.trimm_out? trimm_out.passed_reads_percentage : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.trimm_out? trimm_out.passed_reads_number : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.coverage? coverage.read_depth : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.coverage? coverage.alt_bases : empty_channel_per_sample, remainder: true)  
                                                .join(all_channels.insertsize? insertsize.insert_size : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.assembly_stats? assembly_stats.number_contigs : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.assembly_stats? assembly_stats.total_length : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.assembly_stats? assembly_stats.n50 : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.assembly_stats? assembly_stats.gc_percent : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.typ16S? typ16S.taxa : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.typ16S? typ16S.aln_length : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.typ16S? typ16S.aln_identity : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.metaphlan_out? metaphlan_out.taxa : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.metaphlan_out? metaphlan_out.purity : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.rmlst_out? rmlst_out.taxa : empty_channel_per_sample, remainder: true)    
                                                .join(all_channels.rmlst_out? rmlst_out.best_rST : empty_channel_per_sample, remainder: true)    
                                                .join(all_channels.rmlst_out? rmlst_out.alleles_missing : empty_channel_per_sample, remainder: true)    
                                                .join(all_channels.busco_out? busco_out.complete_busco : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.busco_out? busco_out.busco_groups : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.busco_out? busco_out.busco_lineage : empty_channel_per_sample, remainder: true)           
                                                .join(all_channels.checkm_out? checkm_out.checkm_completeness : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.checkm_out? checkm_out.checkm_contamination: empty_channel_per_sample, remainder: true)
                                                .join(all_channels.checkm_out? checkm_out.checkm_heterogeneity : empty_channel_per_sample, remainder: true)    
                                                .join(all_channels.gtdb_out? gtdb_out.species : empty_channel_per_sample, remainder: true)                                           
                                                .join(all_channels.gtdb_out? gtdb_out.ani_ref : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.gtdb_out? gtdb_out.ani_ani : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.gtdb_out? gtdb_out.ani_af : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.gtdb_out? gtdb_out.placement_ref : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.gtdb_out? gtdb_out.gtdb_notes : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.qc_size_warning? qc_size_warning : empty_channel_per_sample, remainder: true)
      // summary_channel.view() // To see what gets passed to the summary processes

      single_summary  = summary_sample(summary_channel)
      summary         = merge_summaries(single_summary.sample_quality.collect(sort: true))

      links_for_transfer(one_contig)

      // collecting the versions of the various software
      software_version_channel = Channel.empty().concat(
                                  all_channels.trimm_out? trimm_out.version.first() : empty_version_channel,
                                  all_channels.fastqc_raw_reads_out? fastqc_raw_reads_out.version.first() : empty_version_channel,
                                  all_channels.unicycler_out.version? unicycler_out.version.first() : empty_version_channel,
                                  all_channels.annotation? annotation.version.first() : empty_version_channel,
                                  all_channels.checkm_out? checkm_out.version.first() : empty_version_channel,
                                  all_channels.busco_lineages? busco_lineages : empty_version_channel, // first() not needed - only runs once
                                  all_channels.assembly_stats? assembly_stats.version.first() : empty_version_channel,
                                  all_channels.mqc_assembly_out? mqc_assembly_out.version : empty_version_channel, // first() not needed - only runs once
                                  all_channels.gtdb_out_batched? gtdb_out_batched.version.first() : empty_version_channel,
                                  all_channels.bwa_index_remapping? bwa_index_remapping.version.first() : empty_version_channel,
                                  all_channels.typing_rMLST? typing_rMLST.version.first() : empty_version_channel,
                                  all_channels.metaphlan_out? metaphlan_out.version.first() : empty_version_channel,
                                  all_channels.typ16S? typ16S.version.first() : empty_version_channel,
                                  all_channels.abricate_out? abricate_out.version.first() : empty_version_channel,
                                  all_channels.amrfinderplus_out? amrfinderplus_out.version.first() : empty_version_channel,
                                  all_channels.pymlst_out? pymlst_out.version.first() : empty_version_channel,
                                  all_channels.bcl2fastq_out? bcl2fastq_out.version.first() : empty_version_channel,
                                 ).collect()

      write_software_versions(software_version_channel)

}


workflow.onError {
    println ""
    println "Pipeline execution stopped with the following message: ${workflow.errorMessage}"
    println ""
    println "${workflow.errorReport}"
}

workflow.onComplete {
    println ""
    println "Pipeline finished!"
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
    println ""

    if (params.email != "yourmail@yourdomain" && params.email != "") {
        log.info "Preparing to send completion email to ${params.email}"

        def msg = """\
            IMMENSE ${params.run_id} execution summary
            ---------------------------
            Pipeline Directory : ${workflow.projectDir}
            Completed at: ${workflow.complete}
            Duration    : ${workflow.duration}
            Success     : ${workflow.success}
            User        : ${currentUser}
            workDir     : ${workflow.launchDir}
            exit status : ${workflow.exitStatus}
            Error report: ${workflow.errorReport ?: '-'}
            """.stripIndent()

        quality_tab = file("${params.output_dir_run}/${params.run_id}_quality.tsv")
        //dashb = file("${params.run_id}_transfer_result/QC_dashboard.html")
        mulQC_ass = file("${params.output_dir_run}/${params.run_id}_multiqc_assembly.html")
        //mulQC_reads = file("${params.run_id}_transfer_result/${params.run_id}_multiqc_trimmed.html")
        

        try {
            sendMail{
                to "${params.email}"
                subject "IMMENSE ${params.run_id} complete"
                
                if (quality_tab.exists()) { attach "${params.output_dir_run}/${params.run_id}_quality.tsv" }
                //if (dashb.exists()) { attach "${params.run_id}_transfer_result/QC_dashboard.html" }
                if (mulQC_ass.exists()) { attach "${params.output_dir_run}/${params.run_id}_multiqc_assembly.html", fileName: "multiqc_report_assembly.html" }
                //if (mulQC_reads.exists()) { attach "${params.run_id}_transfer_result/${params.run_id}_multiqc_trimmed.html", fileName: "multiqc_report_reads.html" }

                body msg
        }
        } catch (Exception e) {
            log.error "Failed to send completion email: ${e.message}"
        }
    } else {
        log.info 'Skipping the email'
    }
}