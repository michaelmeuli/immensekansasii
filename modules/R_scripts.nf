/*
*  R scripts module
*/

params.CONTAINER = "r-base-4.3.3"   // docker://r-base:4.1.3

process generate_resistance_table {
    tag { "${params.run_id}" }
    container params.CONTAINER

    input:
    path (quality)

    output:


    script:
    """
    cd $PWD/assembly
    Rscript resistance_table.R
    mv resistances.txt ../${params.run_id}_transfer_result
    """
}
