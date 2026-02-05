#!/usr/bin/env nextflow

nextflow.enable.dsl=2

/*
 * Define the pipeline parameters
 */

def currentUser = System.getenv('USER')
params.skip_gtdb = false
params.skip_checkm = false
params.skip_busco = false
params.skip_wgmlst = false
params.skip_tbprofiler = false
params.skip_lissero = false

// this prints the input parameters
log.info """
IMMENSE  ~  version ${workflow.manifest.version}

Anything you have to do repeatedly
may be ripe for automation.
— Doug McIlroy

=============================================
Pipeline Directory         : ${workflow.projectDir}
Run Profile                : ${workflow.profile}
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

if (params.single_sample.toString().contains('{')) {
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
        .fromFilePairs( "${params.input}/**${params.single_sample}*_{R1,R2,1,2}*.f*q.gz")
        .ifEmpty { error "Cannot find any reads matching: ${params.input}/**${params.single_sample}*_{R1,R2,1,2}*.fastq.gz" }
        // .view { "Identified files: $it" }
        .branch{
          sarscov2: it =~ /sarscov-2/
          undet: it =~ /Undetermined/
          other: true}.set{ reads_for_trimming }
  }
  
  else if (params.SE == "YES") {
        Channel
        .fromFilePairs( "${params.input}/**${params.single_sample}*_{R1,1}*.f*q.gz")
        .ifEmpty { error "Cannot find any reads matching: ${params.input}/**${params.single_sample}*_{R1,1}.*f*q.gz" }
        //.view { "Identified files: $it" }
        .branch{
          sarscov2: it =~ /sarscov-2/
          undet: it =~ /Undetermined/
          other: true}.set{ reads_for_trimming }
  }
  }


  //TODO: Implement Hybrid sequencing approach:
  // 1. automatically detect which sample names occur 3 times (2 paired-end short reads + 1 long read file)
  // 2. Send the long read to long-read filtering & QC
  // 3. For sampes with intact long-reads, short reads should be re-directed to hybrid assembly strategy
  // 4. Print out how many files will go through which workflow (X short-read-assemblies, Y hybrid-assemblies, Z long-read-assemblies)
  // 5. For hybrid assemblies: Run long-read assembly (long-first vs. short-first!? depends on the long-read quality & amount.)
  // 6. Combine short & long reads to make perfect polished assemblies and then continue with the annotation part of the pipeline (simply concatenate the channels of short-only and hybrids)


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
include { prokka }                                           from "./modules/prokka"
include { busco; get_busco_lineages; busco_plot }            from "./modules/busco"
include { checkm }                                           from "./modules/checkm"
include { quast }                                            from "./modules/quast"
include { gtdbtk_classify_wf; extract_gtdb_output }          from "./modules/gtdbtk"
include { rMLST; rMLST_call }                                from "./modules/rMLST"
include { metaphlan4; metaphlan4SE; classify_metaphlan4_results } from "./modules/metaphlan"
include { make_one_contig }                                  from "./modules/python_functions"
include { typing_16S }                                       from "./modules/typing_16S.nf"
include { abricate }                                         from "./modules/abricate"
include { summary_sample; merge_summaries }                  from "./modules/summary"
include { write_software_versions; write_versions_per_sample } from "./modules/write_software_versions"
include { generate_resistance_table; merge_run_resistances } from "./modules/resistance_table"
include { pymlst_add_strain; pymlst_distance; pymlst_subgraph} from "./modules/pymlst"
include { mlst}                                               from "./modules/mlst"
include { amrfinderplus  }                                    from  "./modules/amrfinderplus"
include { bakta         }                                     from "./modules/bakta"
include { bwaAlign_insertsize_coverage; bwaAlign_insertsize_coverageSE } from "./modules/align-and-extract"
include { tbprofiler         }                                from "./modules/tbprofiler"
include { lissero         }                                   from "./modules/lissero"
include { insilicoseq         }                               from "./modules/insilicoseq"

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
  
  // Get the expected species name from the input reads:
  // reads_for_trimming.other.view()
  expected_species_ch = reads_for_trimming.other.map { sample_id, fq_tuple -> 
                                                          def firstFile = file(fq_tuple[0]).parent  // Access the parent directory of first fastq.gz file (so it works for single & paired-end)
                                                          return [sample_id, firstFile.getName()] // Get the name of parent directory and output as tuple: sample_id, expected_species
                                                          }

  expected_species_ch.map {
                            sample_id, species -> 
                            return tuple(species, sample_id)
                            }.groupTuple(sort:true).map {
                              species, sample_ids ->
                              def length = sample_ids.size() // Get the length of the list of sample_ids
                              println "Species/Project: ${species}, Number of samples: ${length}" // Print the length
                              return tuple(species, length) // Return the species and length tuple if needed
                            }

  // Running fastQC on fastq reads before trimming and generating multiQC report
  fastqc_raw_reads_out   = fastqc_raw_reads(reads_for_trimming.other) // extract only the reads without sample_id
  multiqc_raw_fastqc_out = multiqc_raw_fastqc(fastqc_raw_reads_out.output.collect())

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
  // If input files are fasta format, then pass those into unicycler_out.assembly channel
  if (params.input_type == "fasta") {
    // Define an empty unicycler_out object
    unicycler_out = [:]
    // Add the genome fasta files in the "assembly" channel within unicycler_out
    unicycler_out.assembly = genome
    // Generate artificial illumina reads from an input fasta genome (so that they can be used to run metaphlan4 and downstread species-specific tools)
    insilicoseq_out = insilicoseq(unicycler_out.assembly)
    
    // Get the expected species name from the input fasta files:
    expected_species_ch = genome.map { sample_id, fq_tuple -> 
                                        def parent_name = file(fq_tuple).parent  // Access the parent directory of first fastq.gz file (so it works for single & paired-end)
                                        return [sample_id, parent_name.getName()] // Get the name of parent directory and output as tuple: sample_id, expected_species
                                        }
    
    expected_species_ch.map {
                              sample_id, species -> 
                              return tuple(species, sample_id)
                              }.groupTuple(sort:true).map {
                                species, sample_ids ->
                                def length = sample_ids.size() // Get the length of the list of sample_ids
                                println "Species/Project: ${species}, Number of samples: ${length}" // Print the length
                                return tuple(species, length) // Return the species and length tuple if needed
                              }

  }

      // These processes are the same for single-end and paired-end datasets:
      annotation          = bakta(unicycler_out.assembly)
      // Don't run BUSCO if skip_busco flag was passed
      if (!params.skip_busco) {  
        busco_out           = busco(unicycler_out.assembly)
        busco_lineages      = get_busco_lineages(busco_out.version.collect())
        busco_plot(busco_out.summary_specific)
      }

      assembly_stats      = quast(unicycler_out.assembly)
      
      // If GTDB is run, it's run on 25 samples at one time and then afterwards the results are pulled apart again
      if (!params.skip_gtdb) {  
      // Remove sample_id from tuple so that the fasta files can be put into batches, sort the fasta files by basename (without path)
      collected_assemblies = unicycler_out.assembly
                                        .map{ sample_id, fasta -> return fasta }
                                        .toSortedList{ a,b -> file(a).getBaseName() <=> file(b).getBaseName() }
                                        .flatten()
      
      // Assign a batch number so that log files can be tracked per batch      
      def gtdb_batch_number = 0
      batched_samples = collected_assemblies
                                        .collate(25, remainder = true)
                                        .map { assemblies -> gtdb_batch_number += 1 
                                            return [gtdb_batch_number, assemblies]}
                                                                          
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
      one_contig          = make_one_contig(unicycler_out.assembly)

      if (params.input_type != "fasta") {
      // These processes cannot run if the input was finished assemblies
      // Different metaphlan4 & alignment depending on single-end or paired-end reads
      

      if (params.SE == "NO") {  
        trimm_out_checked_all = trimm_out_checked.passed.concat(trimm_out_checked.failed)
        metaphlan_out      = metaphlan4(trimm_out_checked_all)
        mapping_processes = bwaAlign_insertsize_coverage(one_contig.join(trimm_out_checked.passed))

      } else if (params.SE == "YES") {
        trimm_out_checked_all = trimm_out_checked.passed.concat(trimm_out_checked.failed)
        metaphlan_out      = metaphlan4SE(trimm_out_checked_all)
        mapping_processes = bwaAlign_insertsize_coverageSE(one_contig.join(trimm_out_checked.passed))
      }
      }
      // If the input was fasta genomes, then use artificially created fastq reads for metaphlan4 to determine speciess
      if (params.input_type == "fasta") {
        metaphlan_out      = metaphlan4(insilicoseq_out.artificial_reads)
      }

      metaphlan4_classified = classify_metaphlan4_results(metaphlan_out.profile)
      // Only run checkM it it's a bacterium (checkM only works for prokaryotes)
      // Since we need the metaphlan4 classification, this can't run on fasta input
      samples_to_run_checkM_ch = unicycler_out.assembly
                        .join(metaphlan4_classified.bacteria, remainder: false)
                        // Only samples where assembly & bacterial classification is true will remain in channel
                        .map { item -> return [item[0], item[1]]} // Return only the first two elements of the tuple (sample_id, assembly)
      
      checkm_out          = checkm(params.skip_checkm? Channel.empty() : samples_to_run_checkM_ch)      // if --skip_checkm flag is set, the input channel will be empty

      // Run tb-profiler for tubercolosis genomes (as identified by metaphlan4)
      // TBprofiler works based on reads, so it cannot be run when the input is fasta files
      if (params.input_type != "fasta") {
      samples_to_run_tbprofiler_ch = trimm_out.trimmed_reads
                        .join(metaphlan4_classified.mycobacterium_tubercolosis, remainder: false)
                        // Only samples where assembly & bacterial classification is true will remain in channel
                        .map { item -> return [item[0], item[1], item[2]]} // Return only the first three elements of the tuple (sample_id, reads)
      // samples_to_run_tbprofiler_ch.view()
      
      tbprofiler_out          = tbprofiler(params.skip_tbprofiler? Channel.empty() : samples_to_run_tbprofiler_ch)
      }

      // Run LisSero for Listeria monocytogenes genoems (as identified by metaphlan4)
      samples_to_run_lissero_ch = unicycler_out.assembly
                        .join(metaphlan4_classified.listeria_monocytogenes, remainder: false)
                        // Only samples where assembly & bacterial classification is true will remain in channel
                        .map { item -> return [item[0], item[1]]} // Return only the first two elements of the tuple (sample_id, assembly)
      
      lissero_out          = lissero(params.skip_lissero? Channel.empty() : samples_to_run_lissero_ch)

      // Run pyMLST based on rMLST species identification
      if (!params.skip_wgmlst) {  
      pymlst_out          = pymlst_add_strain(metaphlan_out.taxa.join(unicycler_out.assembly))
      distance            = pymlst_distance(pymlst_out.summary_specific.join(metaphlan_out.taxa))
      pymlst_subgraph(pymlst_out.summary_specific.join(metaphlan_out.taxa).join(distance.pymlst_distance))
      }
      
      mqc_assembly_out    = multiqc_assembly( assembly_stats.stats.collect(), 
                                              annotation.annot_all.collect(), 
                                              params.skip_busco? Channel.empty() : busco_out.summary_specific.flatten().filter{it =~/short_summary/}.collect(),
                                              (params.input_type == "fasta")? Channel.empty() : metaphlan_out.profile.map {item -> return [item[1]]}.collect()
                                              )
      typ16S       = typing_16S(one_contig)
      abricate_out = abricate(unicycler_out.assembly)
      amrfinderplus_out = amrfinderplus(unicycler_out.assembly)

      // Run MLST on the fasta
      mlst_out = mlst(unicycler_out.assembly)

      // Summarize Abricate output and create summary for run
      summarized_resistances = generate_resistance_table(abricate_out.resistance)
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
                                                .join(all_channels.expected_species_ch? expected_species_ch : empty_channel_per_sample, remainder: true)      
                                                .join(all_channels.trimm_out? trimm_out.passed_reads_percentage : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.trimm_out? trimm_out.passed_reads_number : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.mapping_processes? mapping_processes.read_depth : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.mapping_processes? mapping_processes.depth_mean : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.mapping_processes? mapping_processes.depth_sd : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.mapping_processes? mapping_processes.alt_bases : empty_channel_per_sample, remainder: true)  
                                                .join(all_channels.mapping_processes? mapping_processes.insert_size : empty_channel_per_sample, remainder: true)
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
                                                .join(all_channels.busco_out? busco_out.busco_lineage : empty_channel_per_sample, remainder: true)           
                                                .join(all_channels.checkm_out? checkm_out.checkm_completeness : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.checkm_out? checkm_out.checkm_contamination: empty_channel_per_sample, remainder: true)
                                                .join(all_channels.checkm_out? checkm_out.checkm_heterogeneity : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.mlst_out? mlst_out.sequence_type : empty_channel_per_sample, remainder: true)
                                                .join(all_channels.mlst_out? mlst_out.alleles : empty_channel_per_sample, remainder: true)    
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

      links_for_transfer(one_contig.join(expected_species_ch))

      // collecting the versions of the various software
      software_version_channel = Channel.empty().concat(
                                  all_channels.trimm_out? trimm_out.version.first() : empty_version_channel,
                                  all_channels.fastqc_raw_reads_out? fastqc_raw_reads_out.version.first() : empty_version_channel,
                                  all_channels.unicycler_out.version? unicycler_out.version.first() : empty_version_channel,
                                  all_channels.annotation? annotation.version.first() : empty_version_channel,
                                  all_channels.checkm_out? checkm_out.version.first() : empty_version_channel,
                                  all_channels.tbprofiler_out? tbprofiler_out.version.first() : empty_version_channel,
                                  all_channels.lissero_out? lissero_out.version.first() : empty_version_channel,
                                  all_channels.busco_lineages? busco_lineages : empty_version_channel, // first() not needed - only runs once
                                  all_channels.assembly_stats? assembly_stats.version.first() : empty_version_channel,
                                  all_channels.mqc_assembly_out? mqc_assembly_out.version : empty_version_channel, // first() not needed - only runs once
                                  all_channels.gtdb_out_batched? gtdb_out_batched.version.first() : empty_version_channel,
                                  all_channels.mapping_processes? mapping_processes.version_bwa_index.first() : empty_version_channel,
                                  all_channels.mapping_processes? mapping_processes.version_samtools.first() : empty_version_channel,
                                  all_channels.mapping_processes? mapping_processes.version_pilon.first() : empty_version_channel,
                                  all_channels.typing_rMLST? typing_rMLST.version.first() : empty_version_channel,
                                  all_channels.insilicoseq_out? insilicoseq_out.version.first() : empty_version_channel,
                                  all_channels.metaphlan_out? metaphlan_out.version.first() : empty_version_channel,
                                  all_channels.typ16S? typ16S.version.first() : empty_version_channel,
                                  all_channels.abricate_out? abricate_out.version.first() : empty_version_channel,
                                  all_channels.amrfinderplus_out? amrfinderplus_out.version.first() : empty_version_channel,
                                  all_channels.pymlst_out? pymlst_out.version.first() : empty_version_channel,
                                  all_channels.mlst_out? mlst_out.version.first() : empty_version_channel,
                                  all_channels.bcl2fastq_out? bcl2fastq_out.version.first() : empty_version_channel
                                 ).collect()

// build the run-level versions file once
      write_software_versions(software_version_channel)
versions_file_ch = write_software_versions.out.versions_file

// sample ids from the earliest branch
def sample_ids_ch = reads_for_trimming.other
    .map { sample_id, reads -> sample_id }
    .distinct()

// fan-out + publish per sample
write_versions_per_sample( sample_ids_ch.combine(versions_file_ch) )
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
        // mulQC_ass = file("${params.output_dir_run}/${params.run_id}_multiqc_assembly.html")
        

        try {
            sendMail{
                to "${params.email}"
                subject "IMMENSE ${params.run_id} complete"
                
                if (quality_tab.exists()) { attach "${params.output_dir_run}/${params.run_id}_quality.tsv" }
                //if (dashb.exists()) { attach "${params.run_id}_transfer_result/QC_dashboard.html" }
                // if (mulQC_ass.exists()) { attach "${params.output_dir_run}/${params.run_id}_multiqc_assembly.html", fileName: "multiqc_report_assembly.html" }

                body msg
        }
        } catch (Exception e) {
            log.error "Failed to send completion email: ${e.message}"
        }
    } else {
        log.info 'Skipping the email'
    }
}