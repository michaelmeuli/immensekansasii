/*
*  write software versions module
*/

//params.OUTPUT = "write_software_versions"

process write_software_versions {
    publishDir("${params.output_dir_run}", mode: 'copy')
    tag { "${params.run_id}" }

    input:
    path ("version_files??.txt") // ensures that no filenames are the same

    output:
    path ("${params.run_id}_software_versions.txt"), emit: versions_file

    script:
    """
    #!/bin/bash
    echo -e "Tool - version\\tSingularity image\\tDatabase version" > ${params.run_id}_software_versions.txt
    echo "${workflow.manifest.name} version ${workflow.manifest.version}" >> ${params.run_id}_software_versions.txt
    echo "Nextflow ${workflow.nextflow.version}" >> ${params.run_id}_software_versions.txt
    for sample in version_files*.txt; do cat \$sample >> ${params.run_id}_software_versions.txt; printf "\\n" >> ${params.run_id}_software_versions.txt; done
    """
}
