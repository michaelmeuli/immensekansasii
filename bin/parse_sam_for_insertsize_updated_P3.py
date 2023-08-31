#!/usr/bin/env python

# import numpy as np
import subprocess
import sys
import os


inputOptions = sys.argv[1:]

# usage: file1


def main():

    read_name = ""

    print("Insert_size")
    coverage_sum = 0
    with open(inputOptions[0], 'r') as f:
        for raw_line in f:
            line = raw_line.replace("\n", "").replace("\r", "")
            if line[0:1] != "@":
                if read_name != line.split("\t")[0]:
                    read_name = line.split("\t")[0]
                    scaffold = line.split("\t")[2]
                    read_start = int(line.split("\t")[3])
                    flag = ("0000000000000"[len(bin(int(line.split("\t")[1]))):] + bin(
                        int(line.split("\t")[1]))).replace("b", "")
                    if flag[len(flag) - 5] == "1":  # read is reversed
                        read_start = read_start + len(line.split("\t")[9])

                else:
                    read_name_2 = line.split("\t")[0]
                    scaffold_2 = line.split("\t")[2]
                    read_start_2 = int(line.split("\t")[3])
                    flag_2 = ("0000000000000"[len(bin(int(line.split("\t")[1]))):] + bin(
                        int(line.split("\t")[1]))).replace("b", "")
                    if flag_2[len(flag_2) - 5] == "1":  # read is reversed
                        read_start_2 = read_start_2 + len(line.split("\t")[9])

                    if scaffold == scaffold_2 and flag_2[len(flag_2) - 5] != flag[len(flag) - 5] and flag_2[
                        len(flag_2) - 9] != "1" and flag_2[len(flag_2) - 9] != "1":
                        if flag[len(flag) - 5] != "1":
                            print(read_start_2 - read_start)
                        # if flag_2[len(flag_2)-5]!="1":
                        #	print (read_start-read_start_2)


main()
