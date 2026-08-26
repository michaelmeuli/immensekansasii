#!/usr/bin/env python
# Written by Aitana Neves

import pandas as pd
import glob
import csv
import argparse

parser = argparse.ArgumentParser(description='sample id')
parser.add_argument('--sample_id', type=str, required=True, help='REQUIRED. sample id.')
args = parser.parse_args()
sample = [args.sample_id]
file_path = glob.glob(f'*_resistance.tab')

# Create a DataFrame with sample names and a column for Resistance, initially filled with NA
dat_out = pd.DataFrame({'Sample ID': sample, 'Resistance': pd.NA})

# Check if the file exists
if file_path:
    # Read the relevant columns from the file
    myres = pd.read_csv(file_path[0], sep="\t", usecols=['GENE','%COVERAGE','%IDENTITY'])
    print(myres)

    # Only proceed if the file contains rows
    if not myres.empty:
        # Process each row to generate the 'out' column based on conditions
        myres['out'] = myres.apply(lambda row: f"{row['GENE']} ({row['%IDENTITY']}%)" if row['%COVERAGE'] == 100 and row['%IDENTITY'] != 100 else row['GENE'] if row['%COVERAGE'] == 100 else pd.NA, axis=1)
        
        # Update the Resistance column in the dat_out DataFrame for the current sample
        resistance_values = "; ".join(myres['out'].dropna())
        print(resistance_values)
        dat_out.loc[dat_out['Sample ID'] == sample, 'Resistance'] = resistance_values

# Write the dat_out DataFrame to a tab-separated file, without quoting the values
dat_out.to_csv("resistances.tsv", sep="\t", index=False, quoting=csv.QUOTE_NONE)
