/*
*  fastqc module
*/

params.OUTPUT = "fastqc_output"

process fastqc_raw_reads {
    // publishDir(params.OUTPUT, mode: 'copy')
    publishDir("${params.output_dir_run}/00_QC/00_fastqc_raw_reads/fastqc", mode: 'copy')
    publishDir("${params.output_dir_sample}/${sample_id}/3_quality/fastQC", mode: 'copy')
    tag { sample_id }

    input:
    tuple val(sample_id), file(fastqs)

    output:
    path("*_fastqc*"), emit: output, optional: true
    path "fastqc_version.txt", emit: version

    script:
    """
    # Below we try to run fastqc but if it doesn't work (ie file corrupted), write failed into log. Trimmomatic might still work
    fastqc -t 2 ${fastqs.join(' ')} && echo "Success" || echo "Failed to run fastqc completely" > fastqc_error.log
    # Record software and container version
    fastqc --version > fastqc_vers.txt
    echo ${task.container} > fastqc_singularity.txt
    cat fastqc_vers.txt fastqc_singularity.txt | tr "\\n" "\\t" > fastqc_version.txt
    """
}

process fastqc_trimmed_reads {
    publishDir("${params.output_dir_run}/00_QC/01_fastqc_after_trimming/fastqc", mode: 'copy')
    publishDir("${params.output_dir_sample}/${sample_id}/3_quality/fastQC", mode: 'copy')
    tag { sample_id }

    input:
    tuple val(sample_id), file(fastqs)

    output:
    path("*_fastqc*"), emit: output
    path "fastqc_version.txt", emit: version

    shell:
    '''
   # Run fastQC
fastqc -t 2 !{ fastqs.join(' ') } \
  && echo "Success" \
  || echo "Failed to run fastqc completely" > fastqc_error.log

# Rename fastQC results so they never mix with pre-trim QC
# Works for paired-end and single-end, and for r1/r2, R1/R2, _1/_2 naming
shopt -s nullglob
for f in *_fastqc.html *_fastqc.zip; do
  read="SE"
  if [[ "$f" == *[Rr]1_fastqc* || "$f" == *_1_fastqc* ]]; then
    read="R1"
  elif [[ "$f" == *[Rr]2_fastqc* || "$f" == *_2_fastqc* ]]; then
    read="R2"
  fi

  ext="${f##*.}"
  new="!{sample_id}_${read}_trimmed_fastqc.${ext}"

  # avoid overwriting if multiple fastqs create multiple FastQC reports
  if [[ -e "$new" ]]; then
    i=2
    while [[ -e "${new%.*}_${i}.${ext}" ]]; do
      ((i++))
    done
    new="${new%.*}_${i}.${ext}"
  fi

  mv -- "$f" "$new"
done

# Record software and container version
fastqc --version > fastqc_vers.txt
echo !{ task.container } > fastqc_singularity.txt
paste -sd '\t' fastqc_vers.txt fastqc_singularity.txt > fastqc_version.txt
    '''
}
