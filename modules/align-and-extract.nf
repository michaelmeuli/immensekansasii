/*
*  bwa-mem module
*/

//params.CONTAINER = "quay.io/biocontainers/bwa:0.7.17--h5bf99c6_8"
// TODO: finish this!
// params.OUTPUT = ""

process bwaAlign_insertsize_coverage{
    publishDir("${params.output_dir_sample}/${sample_id}/3_quality/remapping", pattern: "${sample_id}.insertions.tab",mode: 'copy')
    publishDir("${params.output_dir_sample}/${sample_id}/3_quality/remapping", pattern: "${sample_id}_coverage.tab", mode: 'copy')
    tag { sample_id }

    input:
    // Input needs to contain the assembly file
    tuple val(sample_id), path(fasta), path(fastq_r1), path(fastq_r2)

    output:
    path "bwa_index_version.txt", emit: version_bwa_index
    path "bwa_mem_version.txt", emit: version_bwa_mem
    path "samtools_version.txt", emit: version_samtools
    tuple val (sample_id), env(INSERTSIZE), emit: insert_size
    path "pilon_version.txt", emit: version_pilon
    tuple val (sample_id), env(READ_DEPTH), emit: read_depth
    tuple val (sample_id), env(DEPTH_MEAN), emit: depth_mean
    tuple val (sample_id), env(DEPTH_SD), emit: depth_sd
    tuple val (sample_id), env(ALT_BASES), emit: alt_bases

    script:
    """
    # 1) Do indexRemapping based on `one contig` output (fasta file) (bwaIndex process)
    echo "Indexing the assembly with bwa index"
    bwa index ${fasta} 2> bwa_index.err

    echo "bwa index \$(bwa 2>&1 | grep Version | cut -f2 -d " ")" > bwa_index_vers.txt
    echo ${task.container} > bwa_index_singularity.txt
    cat bwa_index_vers.txt bwa_index_singularity.txt | tr "\\n" "\\t" > bwa_index_version.txt

    # ========================================================================================
    # ========================================================================================
    # 2) Trimmed reads + indexRemapping are used in bwaAlign to create alignment SAM file (bwaAlign process)
    echo "Aligning the raw reads to the assembly with bwa mem"
    bwa mem -t ${task.cpus} ${fasta} ${fastq_r1} ${fastq_r2} > ${sample_id}_alignment.sam

    echo "bwa mem \$(bwa 2>&1 | grep Version | cut -f2 -d " ")" > bwa_mem_vers.txt
    echo ${task.container} > bwa_mem_singularity.txt
    cat bwa_mem_vers.txt bwa_mem_singularity.txt | tr "\\n" "\\t" > bwa_mem_version.txt

    # ========================================================================================
    # ========================================================================================
    # 3) SAM file is used with Python script to get insertsizes (parse_sam_for_insertsize process)
    echo "Parsing the sam file to get insertion sizes"
    parse_sam_for_insertsize_updated_P3.py ${sample_id}_alignment.sam > ${sample_id}.insertions.tab
    # Extracting Insertion Size information
    INSERTSIZE=`grep -v Insert_size ${sample_id}.insertions.tab | sort -n  | awk ' { a[i++]=\$1; } END { print a[int(i/2)]; }'`
    
    # ========================================================================================
    # ========================================================================================
    # 4) SAM file is transformed to a sorted BAM file (samtoolsRemapping process)
    echo "Converting SAM to BAM and sorting it with samtools"
    samtools sort -@ ${task.cpus} -T ${sample_id} -o ${sample_id}_alingnment.bam ${sample_id}_alignment.sam
    
    # Sort by name
    samtools sort -n -@ ${task.cpus} -o ${sample_id}_alingnment_sorted.bam ${sample_id}_alingnment.bam
    # Fix paired reads
    samtools fixmate -m -@ ${task.cpus} ${sample_id}_alingnment_sorted.bam ${sample_id}_alingnment_fixed.bam
    # Sort by coordinate again as expected by markdup
    samtools sort -@ ${task.cpus} -o ${sample_id}_alingnment_fixed_coord.bam ${sample_id}_alingnment_fixed.bam
    # Remove duplicates
    samtools markdup -r -@ ${task.cpus} ${sample_id}_alingnment_fixed_coord.bam ${sample_id}_alingnment.removed_duplicates.bam
    # Index the bam file for pilon
    samtools index -@ ${task.cpus} ${sample_id}_alingnment.removed_duplicates.bam

    # Delete all intermediate files that we don't need further
    rm ${sample_id}_alingnment_fixed_coord.bam \
            ${sample_id}_alingnment_fixed.bam \
            ${sample_id}_alingnment_sorted.bam \
            ${sample_id}_alingnment.bam \
            ${sample_id}_alignment.sam

    samtools --version | head -1 > samtools_vers.txt
    echo ${task.container} > samtools_singularity.txt
    cat samtools_vers.txt samtools_singularity.txt | tr "\\n" "\\t" > samtools_version.txt

    # ========================================================================================
    # ========================================================================================
    # 5) Pilon is used to remap the BAM file to the assembly (pilon_remapping process)
    echo "Mapping the BAM file to the assembly to get VCF file"
    export _JAVA_OPTIONS="-Xmx10g"
    pilon --threads ${task.cpus} --genome ${fasta} --frags ${sample_id}_alingnment.removed_duplicates.bam \
    --changes --vcf --fix snps --outdir ./ --output ${sample_id}

    pilon --version | cut -d\\  -f1-3 > pilon_vers.txt
    echo ${task.container} > pilon_singularity.txt
    cat pilon_vers.txt pilon_singularity.txt | tr "\\n" "\\t" > pilon_version.txt

    rm ${sample_id}_alingnment.removed_duplicates.bam

    # ========================================================================================
    # ========================================================================================
    # 6) The Pilon output is used to estimate read_depth and alternative bases (coverage_pilon_corrected process)
    echo "Get read-depth and alternative bases from VCF file"
    make_coverage_pilon_corrected_updated_P3.py ${sample_id}.vcf > ${sample_id}_coverage.tab
    rm ${sample_id}.vcf

    # Exracting the key information
    READ_DEPTH=`awk '/read_depth/{print \$3}' ${sample_id}_coverage.tab | sort -n  | awk ' { a[i++]=\$1; } END { print a[int(i/2)]; }'`

    # Calculating mean & standard deviation:
    awk '/read_depth/{print \$3}' ${sample_id}_coverage.tab | sort -n | awk '
                                                                                {
                                                                                    a[i++] = \$1;
                                                                                    sum += \$1;
                                                                                    sumsq += \$1 * \$1;
                                                                                } 
                                                                                END {
                                                                                    mean = sum / i;
                                                                                    stddev = sqrt((sumsq / i) - (mean * mean));
                                                                                    print mean;
                                                                                    print stddev;
                                                                                }' > mean_and_sd.tsv

    DEPTH_MEAN=`head -n 1 mean_and_sd.tsv`
    DEPTH_SD=`tail -n 1 mean_and_sd.tsv`
    ALT_BASES=`grep -c alternative_base ${sample_id}_coverage.tab`



    """
}

process bwaAlign_insertsize_coverageSE{
    publishDir("${params.output_dir_sample}/${sample_id}/3_quality/remapping", pattern: "${sample_id}.insertions.tab",mode: 'copy')
    publishDir("${params.output_dir_sample}/${sample_id}/3_quality/remapping", pattern: "${sample_id}_coverage.tab", mode: 'copy')
    tag { sample_id }

    input:
    tuple val(sample_id), path(fasta), path(fastq)

    output:
    path "bwa_index_version.txt", emit: version_bwa_index
    path "bwa_mem_version.txt", emit: version_bwa_mem
    path "samtools_version.txt", emit: version_samtools
    tuple val (sample_id), env(INSERTSIZE), emit: insert_size
    path "pilon_version.txt", emit: version_pilon
    tuple val (sample_id), env(READ_DEPTH), emit: read_depth
    tuple val (sample_id), env(ALT_BASES), emit: alt_bases

    script:
    """
    # 1) Do indexRemapping based on `one contig` output (fasta file) (bwaIndex process)
    echo "Indexing the assembly with bwa index"
    bwa index ${fasta} 2> bwa_index.err

    echo "bwa index \$(bwa 2>&1 | grep Version | cut -f2 -d " ")" > bwa_index_vers.txt
    echo ${task.container} > bwa_index_singularity.txt
    cat bwa_index_vers.txt bwa_index_singularity.txt | tr "\\n" "\\t" > bwa_index_version.txt

    # ========================================================================================
    # ========================================================================================
    # 2) Trimmed reads + indexRemapping are used in bwaAlign to create alignment SAM file (bwaAlign process)
    echo "Aligning the raw reads to the assembly with bwa mem"
    bwa mem -t ${task.cpus} ${fasta} ${fastq} > ${sample_id}_alignment.sam 2> bwa_mem.err

    echo "bwa mem \$(bwa 2>&1 | grep Version | cut -f2 -d " ")" > bwa_mem_vers.txt
    echo ${task.container} > bwa_mem_singularity.txt
    cat bwa_mem_vers.txt bwa_mem_singularity.txt | tr "\\n" "\\t" > bwa_mem_version.txt

    # ========================================================================================
    # ========================================================================================
    # 3) SAM file is used with Python script to get insertsizes (parse_sam_for_insertsize process)
    echo "Parsing the sam file to get insertion sizes"
    parse_sam_for_insertsize_updated_P3.py ${sample_id}_alignment.sam > ${sample_id}.insertions.tab
    # Extracting Insertion Size information
    INSERTSIZE=`grep -v Insert_size ${sample_id}.insertions.tab | sort -n  | awk ' { a[i++]=\$1; } END { print a[int(i/2)]; }'`

    # ========================================================================================
    # ========================================================================================
    # 4) SAM file is transformed to a sorted BAM file (samtoolsRemapping process)
    echo "Converting SAM to BAM and sorting it with samtools"
    samtools sort -@ ${task.cpus} -T ${sample_id} -o ${sample_id}_alingnment.bam ${sample_id}_alignment.sam
    
    # Sort by name
    samtools sort -n -@ ${task.cpus} -o ${sample_id}_alingnment_sorted.bam ${sample_id}_alingnment.bam
    # Fix paired reads
    samtools fixmate -m -@ ${task.cpus} ${sample_id}_alingnment_sorted.bam ${sample_id}_alingnment_fixed.bam
    # Sort by coordinate again as expected by markdup
    samtools sort -@ ${task.cpus} -o ${sample_id}_alingnment_fixed_coord.bam ${sample_id}_alingnment_fixed.bam
    # Remove duplicates
    samtools markdup -r -@ ${task.cpus} ${sample_id}_alingnment_fixed_coord.bam ${sample_id}_alingnment.removed_duplicates.bam
    # Index the bam file for pilon
    samtools index -@ ${task.cpus} ${sample_id}_alingnment.removed_duplicates.bam

    # Delete all intermediate files that we don't need further
    rm ${sample_id}_alingnment_fixed_coord.bam \
            ${sample_id}_alingnment_fixed.bam \
            ${sample_id}_alingnment_sorted.bam \
            ${sample_id}_alingnment.bam \
            ${sample_id}_alignment.sam

    samtools --version | head -1 > samtools_vers.txt
    echo ${task.container} > samtools_singularity.txt
    cat samtools_vers.txt samtools_singularity.txt | tr "\\n" "\\t" > samtools_version.txt


    # ========================================================================================
    # ========================================================================================
    # 5) Pilon is used to remap the BAM file to the assembly (pilon_remapping process)
    echo "Mapping the BAM file to the assembly to get VCF file"
    export _JAVA_OPTIONS="-Xmx10g"
    pilon --threads ${task.cpus} --genome ${fasta} --unpaired ${sample_id}_alingnment.removed_duplicates.bam \
    --changes --vcf --fix snps --outdir ./ --output ${sample_id}

    pilon --version | cut -d\\  -f1-3 > pilon_vers.txt
    echo ${task.container} > pilon_singularity.txt
    cat pilon_vers.txt pilon_singularity.txt | tr "\\n" "\\t" > pilon_version.txt

    rm ${sample_id}_alingnment.removed_duplicates.bam

    # ========================================================================================
    # ========================================================================================
    # 6) The Pilon output is used to estimate read_depth and alternative bases (coverage_pilon_corrected process)
    echo "Get read-depth and alternative bases from VCF file"
    make_coverage_pilon_corrected_updated_P3.py ${sample_id}.vcf > ${sample_id}_coverage.tab
    rm ${sample_id}.vcf
    
    # Exracting the key information
    READ_DEPTH=`awk '/read_depth/{print \$3}' ${sample_id}_coverage.tab | sort -n  | awk ' { a[i++]=\$1; } END { print a[int(i/2)]; }'`
    ALT_BASES=`grep -c alternative_base ${sample_id}_coverage.tab`



    """
}