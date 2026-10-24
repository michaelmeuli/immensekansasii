# Species calls: when GTDB and hsp65 MLSA disagree

`screening_map_results.csv` carries two independent species calls per isolate:
`species` (GTDB-Tk on the assembly) and `species_sanger_mlsa/_mlsa_excl/_refalign` (hsp65 Sanger reads).
They normally agree. A disagreement can mean a mixed culture, so check
`contamination_flag` first.

## Contamination flag

`scripts/06_screening_map_results.py` adds `checkm_contamination` (CheckM, %) and
`contamination_flag` (`contaminated` if > `--max-contamination`, default 5; also
printed as a warning on each run). Isolates flagged in the mkan329 run:

| PROBENNUMMER | CheckM contamination | species (GTDB) | Notes |
|---|---|---|---|
| Mkan329-035 | 113.4 % | kansasii | mixed kansasii + ostraviense, see below |
| Mkan329-113 | 61.4 % | persicum | 11.0 Mb assembly, MetaPhlAn4 persicum |
| Mkan329-106 | 20.4 % | kansasii | 7.4 Mb assembly |

Only 035 shows a species disagreement; 106 and 113 are flagged but GTDB and
MetaPhlAn4 agree, and I did not check their hsp65 calls. Mkan329-010 and -021 (about 7.7 %) are below the threshold.

MIC values of flagged isolates are excluded from the final conclusions (CheckM `contamination_flag` is the
criterion; only 035 has MIC data).

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

## Species coverage (non-contaminated isolates)

`excluded` (same file) = contaminated or < 90 % of the cgMLST loci called; it additionally removes Mkan329-055 (81.5 %, persicum) from the genome-based analyses. The counts below only use `contamination_flag`.

Counts per species in `screening_map_results.csv` for the mkan329 run, excluding the 3
isolates with `contamination_flag == contaminated` (035, 106, 113, and since 2026-10-20 also 010, 021 at CheckM 7.7 %); n = 181.

| Species | GTDB `species` | hsp65 MLSA (`species_sanger_mlsa`) |
|---|---|---|
| kansasii | 123 | 90 |
| persicum | 30 | 11 |
| pseudokansasii | 20 | 4 |
| attenuatum | 2 | 1 |
| innocens | 1 | 1 |
| ostraviense | 1 | 1 |
| gastri | 0 | 0 |
| non-complex (avium 2, tuberculosis, abscessus, xenopi, marinum) | 6 | 0 |

- *M. gastri* is the only species of the complex without an isolate.
- 69 of the 177 complex isolates have no MLSA call. This is probably because no Sanger
  (hsp65) read exists for them; not yet checked against the Sanger sample list.
- Where both calls exist, GTDB and MLSA agree for all 108 isolates.

## Public reads: GTDB kansasii with a non-kansasii hsp65 (2026-10-24)

Question: how many of the 880 GTDB-kansasii assemblies of the four public BioProjects (see `PROJECTS.md`) would be misidentified by Sanger hsp65?
`mlsa-kansasii/sanger_vs_wgs/run_insilico_public.py` (commit 5498d72) cuts the 441 bp hsp65 amplicon (TB-11/TB-12(w) in silico PCR)
out of each `1_unicycler/<id>.fasta` and classifies it against the 72 per-genome hsp65 amplicons of the GTDB complex genomes
(sanger_refalign logic). Output: `output/mlsa/sanger_vs_wgs_public/{insilico_public.tsv,SUMMARY.txt}`.
Positive control: 9 GTDB-persicum samples gave 6 persicum and 3 closest to the atypical kansasii genomes, as expected.

Result: an amplicon was found in all 880; 877 are closest to a typical kansasii reference with 0 differences. Three are not:

| Sample | BioProject | hsp65 closest reference (diffs) | best kansasii reference (diffs) | Notes |
|---|---|---|---|---|
| SRR28038296 | PRJNA1078897 | GCF_002705785.1 (0), kansasii but atypical hsp65 | same | *persicum*-like hsp65, persicum 1 diff behind (ambiguous) |
| SRR27048434 | PRJNA1048499 | *pseudokansasii* GCA_000524055.1 (0) | 11 (atypical genome GCF_002705785.1) | next: gastri 10, persicum 12 |
| SRR27048675 | PRJNA1048499 | *attenuatum* GCA_002086865.1 (0) | 15 (atypical genome GCF_002705785.1) | next: gastri 14, persicum 16, pseudokansasii 16 |

- SRR28038296 is the only sample with a *persicum*-like hsp65 (1 of 880); no sample is closest to a persicum reference. A Sanger hsp65 read of it could be called persicum.
  The 3 atypical-hsp65 kansasii genomes are real kansasii (`mlsa-kansasii/LIT.md`).
- SRR27048434 and SRR27048675 are kansasii by every other measure: GTDB-Tk ANI to GCF_000157895.3 99.59 / 99.88 (AF 0.98 / 0.99, next species < 94 %),
  MetaPhlAn4 kansasii at 100 % purity, 16S kansasii, ST38, CheckM contamination 0.15 %, completeness 100 %. Their hsp65 is identical to
  that of *pseudokansasii* / *attenuatum*; a typical kansasii hsp65 is at least 11 / 15 differences away. Sanger hsp65 would call them
  pseudokansasii / attenuatum.
- Not established: whether this is a real hsp65 transfer or an assembly artefact (misassembled contig). Not checked: reads mapped to the amplicon
  (mixed bases, coverage). Amplicons: `output/mlsa/logs/SRR27048434_hsp65_amplicon.fa`, `SRR27048675_hsp65_amplicon.fa`.
- Not covered: the 184 public samples without a kansasii GTDB call, SRR27048649 (no assembly) and the in-house Mkan329 set
  (`output/mlsa/sanger_vs_wgs/insilico_vs_wgs.tsv`).
