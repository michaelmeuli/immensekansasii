#!/bin/bash

# This script is used to create blastn databases for each individual .fas file that 
# was downloaded for the ribosomal MLST database.
# Run this script as bash make_MLST_blast_database.sh directory/containing/MLST_fast_files

# Directory containing your FASTA files
fasta_dir="$1"
output_dir="$1"

# Loop through each FASTA file in the directory
for fasta_file in $fasta_dir/*.fas*; do
    # Extract the base name for the file to use in naming the database
    base_name=$(basename $fasta_file .fasta)

    # Create a BLAST database for the FASTA file
    makeblastdb -in $fasta_file -dbtype nucl -out $output_dir/$base_name
done



