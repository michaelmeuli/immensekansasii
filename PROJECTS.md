# Public *M. kansasii* WGS projects

Published *M. kansasii* WGS / comparative-genomics studies found via PubMed (2026-10-19), with their public read deposits.
SRA counts are experiments on NCBI SRA for the BioProject. BioProjects were matched to papers by title, not from data-availability statements, so verify before use.

| Paper | BioProject | SRA experiments |
|---|---|---|
| Taiwan phylogeography, Emerg Infect Dis 2024 (doi:10.3201/eid3008.240021) | PRJNA1078897 | 243 |
| *M. kansasii* complex phylogenomics, Microb Genom 2024 (doi:10.1099/mgen.0.001266) | PRJNA1048499 | 342 |
| Drug resistance before and after 2 months of treatment, Clin Microbiol Infect 2022 (doi:10.1016/j.cmi.2022.10.002) | PRJNA845115 | 237 |
| Genomic insights into the *M. kansasii* complex, Front Microbiol 2019/20 (doi:10.3389/fmicb.2019.02918) | PRJNA323639 (Global diversity of the *M. kansasii* complex) | 273 |
| Comparative genomic and transcriptomic analysis of subtypes, Front Cell Infect Microbiol 2020 (doi:10.3389/fcimb.2020.00122) | PRJEB32175 | 43 |
| Genomics of the complex, large variations between members (probably Front Microbiol 2019 update) | PRJEB28857 | 37 |
| Taxogenomics / new species, IJSEM 2019 (doi:10.1099/ijsem.0.003378) | PRJEB25525 | 0 (assemblies only) |
| Genomic-based genotype and drug susceptibility, China, Front Microbiol 2025 (doi:10.3389/fmicb.2025.1573448) | 2 BioProjects linked in PubMed, not identified | not checked |
| Brazilian genotype 1 isolates, Mem Inst Oswaldo Cruz 2018 (doi:10.1590/0074-02760180085) | PRJNA374853 (probable) | 0 (assemblies only) |

## Notes

- Not confirmed against the papers: PRJNA323639, PRJEB28857 and PRJNA374853.
- The Tn-seq (mBio 2023), murine model, pharmacology, diagnostics and review papers have no linked BioProject. Their data may be elsewhere (GEO, supplements); not checked.
- Possibly related, unmatched: PRJNA1420165 (2026, 54 SRA experiments), NTM from Chinese hospitals.
- About 1,450 SRA entries on NCBI match "Mycobacterium kansasii", including non-WGS and non-isolate data.
- PubMed→SRA/BioProject elink returned nothing for most of these papers, so search BioProject/SRA directly.

## Running the public reads through IMMENSE

Reads and tables live outside the repo, in `/shares/sander.imm.uzh/MM/kansasii/data/illumina/public/<BioProject>/`
(`metadata.tsv`, `selected.tsv`, `not_runnable.tsv`, `reads/`, `batches/`). Steps 09-11, see `WORKFLOW.md` (step 5c):

```bash
P="PRJNA1078897 PRJNA1048499 PRJNA845115 PRJNA323639"
bash scripts/09_public_fetch_metadata.sh $P
sbatch --wrap "python scripts/10_public_select_and_download.py $P" # all runs, no species/host filtering
bash scripts/11_public_batches.sh PRJNA1078897                      # prints the run_IMMENSE.sh commands
```

Run ids: `public_<BioProject>` (pilot: `public_<BioProject>_test`), one snippy db per BioProject.

| BioProject | Runs | Not runnable (fq_PE) | Reads downloaded | Pipeline |
|---|---|---|---|---|
| PRJNA1078897 | 243 | 0 | yes (87 GB) | pilot OK (3/3 *M. kansasii*, ST38); all 243 done (2026-10-22; 3 stall casualties rerun) |
| PRJNA1048499 | 342 | 0 | yes (90 GB) | all 342 done (2026-10-22) |
| PRJNA845115 | 237 | 0 | yes (174 GB) | all 237 done (2026-10-24; SRR19543452 rerun after the tbprofiler time-limit fix) |
| PRJNA323639 | 273 | 30 (single-end) | yes (92 GB, 243 samples) | all 243 done (2026-10-22) |

Batches of one project run one after another in `runs/public_<BioProject>/` (Slurm `--dependency=afterany`);
the four projects run in parallel. `SBATCH_DEPENDENCY` is ignored here, so `run_IMMENSE.sh` cannot chain:
call `sbatch --dependency=... bin/submit_to_cluster.sh <main_dir> fastq NO <run_id> <batch_dir> "--kansasii_snippy_db <db>"` directly.
Check `slurm-<jobid>.out` of every batch for "Execution status: OK"; the chain continues after a failed batch.

Findings from the runs: the coordinator sometimes stalled with work left (no tasks, no workers) and held the chain until the 24 h limit,
which also corrupts `.nextflow/cache` (moved aside, resume lost for that batch). `bin/nxf_watchdog.sh` now stops a stalled coordinator
and `tbprofiler` has a 2 h x attempt time limit (the 10 min default killed it on large read sets). Stall casualties were rerun, not bad samples.
