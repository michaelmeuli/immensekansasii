#!/usr/bin/env python

import csv
import pandas as pd
import argparse
import os

# To run:
# evaluate_QC.py --qcfile xxxxx_quality.tsv --rulesfile path/to/aquamis-style/rules.csv

synonyms = {
    'GC_percent':'GC (%)',
    'Read_depth_median':'assembly_coverageDepth',
    'Total_length':'Total length',
    'checkm_contamination':'ContamStatus',
    'Contig_count':'# contigs (>= 0 bp)'
}

def parse_busco_data(busco_str):
    """
    Parse the BUSCO string to extract single-copy and duplicated BUSCO percentages.

    Parameters:
    busco_str (str): BUSCO data string, e.g., "C:99.1%[S:98.9%;D:0.2%]"

    Returns:
    tuple: (single_copy_percentage, duplicated_percentage)
    """
    try:
        # Extract percentages following 'S:' for single-copy and 'D:' for duplicated
        single_str = str(busco_str).split('S:')[1].split('%')[0]
        duplicated_str = str(busco_str).split('D:')[1].split('%')[0]

        # Convert to decimal
        single_copy = float(single_str) / 100.0
        duplicated = float(duplicated_str) / 100.0

        return single_copy, duplicated
    except Exception as e:
        print(f"Error parsing BUSCO data: {e} - Skipped")
        return 0.0, 0.0  # Default return on failure

def add_busco_columns(df):
    """
    Add 'busco_single' and 'busco_duplicates' columns to the DataFrame based on 'Complete_BUSCOs'.

    Parameters:
    df (pd.DataFrame): DataFrame containing the 'Complete_BUSCOs' column.

    Returns:
    pd.DataFrame: Updated DataFrame with new columns.
    """
    # Apply the parse function to each row in 'Complete_BUSCOs' column
    df['Complete_BUSCOs'].apply(parse_busco_data).apply(pd.Series)
    df[['busco_single', 'busco_duplicates']] = df['Complete_BUSCOs'].apply(parse_busco_data).apply(pd.Series)
    return df

def load_strain_data(file_path):
    """
    Load strain data from a TSV file into a DataFrame.

    Parameters:
    file_path (str): The path to the TSV file.

    Returns:
    pd.DataFrame: A DataFrame containing the strain data.
    """
    try:
        strain_data = pd.read_csv(file_path, sep='\t', header = 0,  index_col = False)
        strain_data = strain_data.iloc[:-1] # drop the last row that contains number of analysed samples
        # If 'Complete_BUSCOs' column is expected, add the busco columns
        if 'Complete_BUSCOs' in strain_data.columns:
            strain_data = add_busco_columns(strain_data)
        return strain_data
    except Exception as e:
        print(f"An error occurred while loading the data: {e}")
        return None

def translate_parameter_name(param):
    """Translates parameter names to their canonical form based on predefined synonyms."""
    return synonyms.get(param, param)

def parse_ranges(ranges_str):
    """Parses a string containing multiple range specifications."""
    range_list = []
    # Split the input string by commas to process multiple ranges
    for part in ranges_str.split(','):
        part = part.strip()
        if '<' in part:
            left, right = part.split('<')
            if '≤' in right:
                mid, upper = right.split('≤')
                range_list.append((float(left), float(upper)))
            else:
                range_list.append((float(left), float('inf')))
        elif '≤' in part:
            left, right = part.split('≤')
            if left.strip() == 'x' or not left:
                range_list.append((0.0, float(right)))
            else:
                range_list.append((float(left), float(right)))
        elif '>' in part:
            left, right = part.split('>')
            if left.strip() == 'x' or not left:
                range_list.append((float(right), float('inf')))
            else:
                range_list.append((0.0, float(left)))
    return range_list

def load_rules(filename):
    """Loads rules from a CSV file into a dictionary."""
    rules = {}
    with open(filename, mode='r') as file:
        reader = csv.DictReader(file)
        for row in reader:
            taxon = row['Taxon'].strip()
            parameter = row['Parameter'].strip()
            pass_ranges = parse_ranges(row['PASS'])
            warning_ranges = parse_ranges(row['WARNING'])
            fail_ranges = parse_ranges(row['FAIL'])
            if taxon not in rules:
                rules[taxon] = {}
            rules[taxon][parameter] = {'PASS': pass_ranges, 'WARNING': warning_ranges, 'FAIL': fail_ranges}
    return rules

def evaluate_parameter(value, rules):
    """Evaluate a single parameter value against rules."""
    if value == "skipped":
        return "Undefined"
    for result, range_list in rules.items():
        for min_val, max_val in range_list:
            if min_val == 0.0 and value <= max_val:
                return result
            elif max_val == float('inf') and float(value) >= min_val:
                return result
            elif min_val < value <= max_val:
                return result
    return "Undefined"  # If no rules matched

def evaluate_row(row, all_rules):
    """Evaluates a single row of parameters against given rules."""
    row_results = {}
    for param, value in row.items():
        canonical_param = translate_parameter_name(param)  # Translate to canonical name if synonymous
        rules_for_param = all_rules.get(canonical_param, {})

        # Determine the evaluation status for this parameter
        if canonical_param in all_rules.keys(): #rules_for_param:
            status = evaluate_parameter(value, rules_for_param)
        elif canonical_param in "Sample":
            status = value
        elif canonical_param in "initial_species":
            status = row['MetaPhlAn4_species']
        else:
            continue # If parameter is not defined, then don't output it.
            # status = "NA"
        row_results[canonical_param] = status
    
    return row_results

def evaluate_strain(strain_datafile, rules_file):
    """Evaluates all parameters of a strain based on the rules for its genus and species, including universal rules."""
    
    # Load data and rules
    parameters = load_strain_data(strain_datafile)
    print(parameters)
    rules = load_rules(rules_file)

    # Initialize empty list to store results for each row
    all_results = []

    # Iterate over each row in parameters DataFrame
    for index, row in parameters.iterrows():
        # Extract species information from the current row
        species = row['MetaPhlAn4_species']
        # If it's not a string then its NaN which means the taxa is unknown and just general QC can be applied
        if not isinstance(species, str):
            species = "all Species"
            
        species = species.replace("_", " ")
        genus = species.split(" ")[0]
        
        # Prepare rules for the current species
        global_rules = rules.get("all Species", {})
        genus_rules = rules.get(genus, {})
        species_rules = rules.get(species, {}) if species and species != genus else {}

        # Combine all applicable rules for ease of access
        all_rules = {**global_rules, **genus_rules, **species_rules}

        # Evaluate parameters for the current row based on the rules
        row_results = evaluate_row(row, all_rules)

        # Append results for the current row to the list
        all_results.append(row_results)

    # Convert the list of results into a DataFrame
    results = pd.DataFrame(all_results)

    return results

def main():
    """Specify quality results file, rules file and species"""
    
    ## Arguments
    parser = argparse.ArgumentParser(
        description='Return QC score according to rules.')
    parser.add_argument('--qcfile', type=str, required=True, help='REQUIRED. Strains QC filename (TSV)')
    parser.add_argument('--rulesfile', type=str, required=True, help='REQUIRED. Rules filename (CSV)')
    args = parser.parse_args()

    results = evaluate_strain(args.qcfile, args.rulesfile)
    results.to_csv(os.path.basename(args.qcfile).split(".tsv")[0]+"_QC.csv", sep=",", index=False, quoting=csv.QUOTE_NONE, na_rep='NA')

if __name__ == "__main__":
    main()
