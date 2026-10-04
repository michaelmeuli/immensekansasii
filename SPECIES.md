# Species calls: when GTDB and hsp65 MLSA disagree

`screening_map_results.csv` carries two independent species calls per isolate:
`species` (GTDB-Tk on the assembly) and `species_mlsa1/2/ref` (hsp65 Sanger reads).
They normally agree. A disagreement can mean a mixed culture, so check
`contamination_flag` first.

## Contamination flag

`scripts/screening_map_results.py` adds `checkm_contamination` (CheckM, %) and
`contamination_flag` (`contaminated` if > `--max-contamination`, default 10; also
printed as a warning on each run). Isolates flagged in the mkan329 run:

| PROBENNUMMER | CheckM contamination | species (GTDB) | Notes |
|---|---|---|---|
| Mkan329-035 | 113.4 % | kansasii | mixed kansasii + ostraviense, see below |
| Mkan329-113 | 61.4 % | persicum | 11.0 Mb assembly, MetaPhlAn4 persicum |
| Mkan329-106 | 20.4 % | kansasii | 7.4 Mb assembly |

Only 035 shows a species disagreement; 106 and 113 are flagged but GTDB and
MetaPhlAn4 agree, and I did not check their hsp65 calls. Mkan329-010 and -021 (about 7.7 %) are below the threshold.

## Case: Mkan329-035 (GTDB kansasii vs hsp65 ostraviense)

The isolate is a mixed culture of *M. kansasii* and *M. ostraviense*; each method
reports one of the two species present.

- Assembly: 13.05 Mb in 1712 contigs (a single genome is about 6.4 Mb), 89.3 % duplicated
  BUSCOs, CheckM contamination 113.4 %.
- GTDB-Tk: kansasii (ANI 99.66 to GCF_000157895.3, AF 0.953); not reliable for a mixed
  assembly of two close species.
- MetaPhlAn4: ostraviense.
- hsp65 (5 reads, 2 usable): ostraviense, distance 0.0053 (second: gastri 0.0214).
  16S: kansasii but ambiguous (margin 0.0011), as 16S does not separate these species.

Not yet done: separating the two genomes (binning by coverage/GC or ANI to both
references, mapping reads to both references) or re-streaking and re-sequencing from
single colonies. Until then, treat the species of 035 as undetermined (mixed).
