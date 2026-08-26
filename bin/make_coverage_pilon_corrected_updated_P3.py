#!/usr/bin/env python

# import numpy as np
import subprocess
import sys
import os

inputOptions = sys.argv[1:]

# usage: file1


def main():

    print("Pattern", "position", "depth", sep="\t")
    coverage_sum = 0
    with open(inputOptions[0], 'r') as f:
        print("alternative_base", "0", "0", sep="\t")

        for raw_line in f:
            line = raw_line.replace("\n", "").replace("\r", "")
            if line.find("##contig=") != -1:
                genome_length = int(line.split("length=")[1].replace(">", ""))
                split_factor = int(round(float(genome_length) / 500, 0))

            if line[0:1] != "#" and line.find("DP=") != -1:
                position = int(line.split("\t")[1])
                coverage_sum += int(line.split("DP=")[1].split(";")[0])
                if position % split_factor == 0:
                    mean_cov = coverage_sum / float(split_factor)
                    if mean_cov <= 500:
                        print("read_depth", str(position), str(coverage_sum / float(split_factor)), sep="\t")
                    else:
                        print("read_depth", str(position), "500", sep="\t")
                    coverage_sum = 0

                bases_counts = map(int, line.split(";BC=")[1].split(";")[0].split(","))
                second_abundant_base = sorted(bases_counts, reverse=True)[1]

                depth = int(line.split("DP=")[1].split(";")[0])

                if second_abundant_base != 0:
                    ratio = float(second_abundant_base) / float(depth)
                else:
                    ratio = 0

                if ratio >= 0.2:
                    print("alternative_base", str(position - 0.5), "0", sep="\t")
                    print("alternative_base", str(position), str(ratio * 100), sep="\t")
                    print("alternative_base", str(position + 0.5), "0", sep="\t")

        print("read_depth", str(position), "0", sep="\t")
        print("alternative_base", str(position), "0", sep="\t")


main()
