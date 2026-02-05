/*
* create_links module
*/

process link_reads {
  // Move all fastq.gz file into a nicely organized 'reads' directory
  tag { "${params.run_id}" }

  input:
  path(demultiplex_ok)

  output:

  shell:
  """
  #!/usr/bin/env bash
  set -euo pipefail

  # Use the directory where Nextflow was launched (NOT the task work dir)
  RUN_DIR="!{workflow.launchDir}"

  # Resolve output_dir_run relative to RUN_DIR if needed
  OUT_RUN="!{params.output_dir_run}"
  [[ "\$OUT_RUN" = /* ]] || OUT_RUN="\$RUN_DIR/\$OUT_RUN"

  src_root="\$RUN_DIR/demultiplexing/reads"
  reads_root="\$RUN_DIR/reads"
  raw_dir="\$reads_root/_raw_reads"

  # Compute path of TARGET relative to BASEDIR
  relpath() {
    local target="\$1"
    local basedir="\$2"
    if command -v realpath >/dev/null 2>&1; then
      realpath --relative-to="\$basedir" "\$target"
    else
      python3 - "\$target" "\$basedir" <<'PY'
import os, sys
target, basedir = sys.argv[1], sys.argv[2]
print(os.path.relpath(os.path.abspath(target), os.path.abspath(basedir)))
PY
    fi
  }

  # Flat collection of links to everything directly under demultiplexing/reads
  mkdir -p "\$raw_dir"
  shopt -s nullglob
  for item in "\$src_root"/*; do
    rel="\$(relpath "\$item" "\$raw_dir")"
    ln -sf "\$rel" "\$raw_dir/"
  done
  shopt -u nullglob

  # Iterate over subdirectories, skipping Reports/Stats, and build normalized reads structure
  shopt -s nullglob
  for dir in "\$src_root"/*/; do
    base="\$(basename "\$dir")"
    case "\$base" in
      Reports|Stats) continue ;;
    esac

    local_dir="\$reads_root/\$base"
    out_dir="\$OUT_RUN/trimmed_reads/\$base"
    mkdir -p "\$local_dir" "\$out_dir"

    # Link demultiplexed FASTQs into local trimmed_reads/<base>/ with relative targets
    for fq in "\$dir"*.fastq.gz; do
      rel="\$(relpath "\$fq" "\$local_dir")"
      ln -sf "\$rel" "\$local_dir/\$(basename "\$fq")"
    done

    # Normalize filenames in local trimmed_reads/<base>/
    pushd "\$local_dir" >/dev/null

    # R1 normalization: *_R1.fastq.gz
    for sample in ./*R1*.fastq.gz; do
      mv "\$sample" "\${sample/_*.fastq.gz/_R1.fastq.gz}"
    done

    # R2 normalization: *_R2.fastq.gz
    for sample in ./*.fastq.gz; do
      if [[ "\$sample" == *R2* ]]; then
        mv "\$sample" "\${sample/_*.fastq.gz/_R2.fastq.gz}"
      fi
    done

    # Populate OUT_RUN/trimmed_reads/<base>/ with relative symlinks pointing to the normalized local links
    for sample in ./*.fastq.gz; do
      rel="\$(relpath "\$local_dir/\$(basename "\$sample")" "\$out_dir")"
      ln -sf "\$rel" "\$out_dir/\$(basename "\$sample")"
    done

    popd >/dev/null
  done
  shopt -u nullglob
  """
}


process links_for_transfer {
  tag { sample_id }

  input:
  tuple val(sample_id), path(one_contig), val(species)

  output:

  shell:
  """
  #!/usr/bin/env bash
  set -euo pipefail

  RUN_DIR="!{workflow.launchDir}"

  OUT_RUN="!{params.output_dir_run}"
  [[ "\$OUT_RUN" = /* ]] || OUT_RUN="\$RUN_DIR/\$OUT_RUN"

  SAMPLE="!{sample_id}"
  SPECIES="!{species}"
  INPUT_TYPE="!{params.input_type}"

  dest_genome_dir="\$OUT_RUN/genomes/\$SPECIES"
  dest_reads_dir="\$OUT_RUN/trimmed_reads/\$SPECIES"
  mkdir -p "\$dest_genome_dir" "\$dest_reads_dir"

  relpath() {
    local target="\$1"
    local basedir="\$2"
    if command -v realpath >/dev/null 2>&1; then
      realpath --relative-to="\$basedir" "\$target"
    else
      python3 - "\$target" "\$basedir" <<'PY'
import os, sys
target, basedir = sys.argv[1], sys.argv[2]
print(os.path.relpath(os.path.abspath(target), os.path.abspath(basedir)))
PY
    fi
  }

  # Assembly link is relative.
  src_genome="!{one_contig}"
  rel_genome="\$(relpath "\$src_genome" "\$dest_genome_dir")"
  ln -srf $PWD/assembly/results/${sample_id}/2_annotation/${sample_id}.fna $PWD/${params.output_dir_run}/genomes/${species}/

  # Reads come from trimming folder and are linked relatively (SE or PE; .fq.gz or .fastq.gz)
  if [[ "\$INPUT_TYPE" != "fasta" ]]; then
    shopt -s nullglob
    for src_read in "\$RUN_DIR/assembly/results/\$SAMPLE/0_trimming/\${SAMPLE}"*.f*q.gz; do
      rel_read="\$(relpath "\$src_read" "\$dest_reads_dir")"
      ln -srf "\$rel_read" "\$dest_reads_dir/\$(basename "\$src_read")"
    done
    shopt -u nullglob
  fi
  """
}
