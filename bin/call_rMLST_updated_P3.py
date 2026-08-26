#!/usr/bin/env python

import operator
import subprocess
import sys
import os


inputOptions = sys.argv[1:]

# usage: file1


def main():

    alleles = read_alleles(inputOptions)

    found_allels = assign_rST(alleles, inputOptions)

    best_result = sorted(found_allels.items(), key=operator.itemgetter(1))[0]

    best_species = best_result[0].split("_rST")[0]
    best_rST = "rST" + best_result[0].split("_rST")[1]
    best_score = str(best_result[1])

    print(best_species, best_rST, best_score, sep='\t')


def assign_rST(alleles, inputOptions):

    rSTs = {}
    input_file = [n for n in open(inputOptions[0], 'r').read().replace("\r", "").split("\n") if len(n) > 0]
    genes = input_file[0].split("\t")[1:54]
    for line in input_file:
        rST = line.split("\t")[55].replace(" ", "_") + "_"
        if rST == "":
            rST += line.split("\t")[54].replace(" ", "_") + "_"

        rST += "rST" + line.split("\t")[0]

        rSTs[rST] = []

        for gene, allel in zip(genes, line.split("\t")[1:54]):
            rSTs[rST].append(gene + "_" + allel)

    found_allels = {}

    for rST in rSTs.keys():
        found_allels[rST] = len(list((set(alleles) - set(rSTs[rST]))))

    return found_allels


def read_alleles(inputOptions):

    selected_alleles = []
    for blastfile in inputOptions[1:]:
        best_alleles = {}
        best = 0
        input_file = [n for n in open(blastfile, 'r').read().replace("\r", "").split("\n") if len(n) > 0]

        for line in input_file:
            allel = line.split("\t")[1]
            if int(line.split("\t")[4]) == int(line.split("\t")[5]):
                idendity = float(line.split("\t")[6])

                if idendity >= 99 and idendity >= best:
                    best = float(line.split("\t")[6])
                    best_alleles[allel] = float(line.split("\t")[6])

        selected_alleles.extend(best_alleles.keys())

    selected_alleles.append("N")
    return selected_alleles


main()
