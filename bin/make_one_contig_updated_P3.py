#!/usr/bin/env python

#import numpy as np
import subprocess
import sys
import os


inputOptions = sys.argv[1:]

#usage: file1 name_to_use


def main():
	sequence_name=inputOptions[1]
	sequence=""
	headers=""
	with open(inputOptions[0],'r') as input_file:


		for raw_line in input_file:

			line=raw_line.replace("\n","").replace("\r","")

			if line[0:1]!=">":
				sequence+=line
			else:
				headers+=" seq:"+line[1:]
				if sequence!="":
					sequence+="NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN"


	print (">"+sequence_name) #+headers

	i=0
	while i < len(sequence):
		print (sequence[i:i+60])
		i+=60


main()			
