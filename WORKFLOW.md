# M. kansasii project workflow

How the project-specific scripts around the IMMENSE pipeline fit together
(the pipeline itself is described in `README.md`). Everything runs on the s3it cluster. Paths in the
tables and text are relative to `/shares/sander.imm.uzh/MM/kansasii/` (`K`) unless
absolute; **code blocks use full paths** and can be pasted as they are (only
`<placeholders>` need filling in).

## Directory layout

| Path | Content |
|---|---|
| `repos/immensekansasii` | this repo: pipeline + project scripts in `scripts/` |
| `repos/mlsa-kansasii` | MLSA / Sanger differentiation (reads `data/imm/screening_map_link.csv`) |
| `data/imm/` | screening map sources and derived tables |
| `data/immensekansasii/gtdb/gtdb232/` | GTDB r232 `bac120_*` metadata/taxonomy only (downloaded if missing) |
| `data/gtdb_genomes/` | genomes downloaded from NCBI, plus symlink dirs for runs |
| `data/illumina/Mkan329/reads/kansasii/` | delivered paired-end fastq `Mkan329-NNN_r1/_r2.fastq.gz` (lower case; 133 isolates, NR 1-133; NR 134-186 are in `reads/kansasii_jc`) |
| `data/illumina/Mkan329/batches/<batch>/` | per-batch input from `04_mkan329_batches.sh`: `Mkan329-NNN_R1/_R2.fastq.gz` symlinks + `id_map.tsv` |
| `runs/<run_name>/` | working dir of a pipeline run (contains large, temporary `work/`) |
| `output/<run_name>/` | end results of a run (no `work/`); downloaded to local `kansasii_C` |
| `output/immensekansasii/gtdb/gtdb232/` | accession lists and type strains derived from the GTDB metadata |
| `output/iTOL/<run_name>/` | iTOL tree + annotation files per run |
| `output/mlsa/` | MLSA outputs |

**Rule:** scripts read only from `data/` and `runs/`. `output/` only receives copies made by
the scripts (results, iTOL files, lists) for convenience and download.

## Run order (whole project)

Everything is called in this order. Numbers are the file prefixes; `repo:` scripts in other repos
carry their own numbers. A step may start once everything above it that it reads has finished.
`scripts/run_downstream.sh` submits the whole post-pipeline part (steps 2 and 6-14, every repo except the routine
sanger-microsynth) as a Slurm dependency chain. Every path below is a constant of `kansasii_paths.{py,sh}`
(`kansasii-docs/templates/`, one copy per repo) and a flag of the script.

| # | Step | Script | Env | Reads | Writes |
|---|---|---|---|---|---|
| 0 | tool/db install (once, notes) | `scripts/install_notes.txt` | - | - | pipeline dbs, containers |
| 1 | GTDB r232 metadata, lists, genomes | `scripts/01_gtdb_mycobacteria_genomes.sh` | `env_immense` | GTDB web | `data/immensekansasii/gtdb/gtdb232/`, `data/gtdb_genomes/`, `output/immensekansasii/gtdb/gtdb232/` |
| 2 | screening map link | `scripts/02_screening_map_link.py` | `env_mic` | `data/imm/screening_map_*.csv` | `data/imm/screening_map_link.csv` |
| 3 | reference-tree run (7 GTDB representatives) | `scripts/03_run_gtdb_tree.sh` | none | step 1 | `runs/kansasii_complex_gtdb_representatives/` |
| 4 | Mkan329 batches (mm reads) | `scripts/04_mkan329_batches.sh` | none | step 2, reads | `data/illumina/Mkan329/batches/` |
| 5 | Mkan329 batches (jc reads, resequenced) | `scripts/05_mkan329_batch_jc.sh` | none | step 2, reads | `batches/b05`, `b06` |
| 5b | pipeline runs, one batch after another | `run_IMMENSE.sh` (commands printed by 4/5) | none | batches | `runs/mkan329/`, `runs/mkan329_jc/` |
| 5c | public reads: ENA metadata, download, batches | `scripts/09_public_fetch_metadata.sh`, `10_public_select_and_download.py` (sbatch), `11_public_batches.sh` | `env_mic` (10) | `PROJECTS.md` BioProjects, ENA | `data/illumina/public/<BioProject>/{metadata.tsv,selected.tsv,reads/,batches/}`, then `run_IMMENSE.sh` -> `runs/public_<BioProject>/` |
| 6 | MIC analysis | `kansasii-mic: submit_mic.sbatch` (`scripts/01_run_analysis.py`) | `env_mic` | `mic.csv`, step 2 | `output/mic/{mhk,mgit}/` |
| 7 | MLSA inputs (links, filtered GTDB list) | `mlsa-kansasii: scripts/01..04_*` | `env_mlsa` | steps 1, 2 | `data/gtdb_genomes/.../mlsa-kansasii/`, `data/sanger/seq_kansasii/` |
| 8 | MLSA analysis | `mlsa-kansasii: scripts/04_locus_discovery -> 08_sanger_mlsa` (+ `--exclude-atypical`), `09_sanger_refalign`, `05_genome_identity_check`, `06_make_hsp65_references`; `10_sanger_vs_wgs` after step 9 | `env_mlsa` | step 7 | `output/mlsa/` |
| 9 | results table | `scripts/06_screening_map_results.py` | `env_mic` | steps 2, 5b, 6, 8 | `data/imm/screening_map_results.csv` |
| 9b | hsp65 / gyrA of project and public samples | `hsp65-refalign: submit_validate.sbatch, submit_korean_check.sbatch, submit_public.sbatch [ctl\|persicum]`; `gyrA-refalign: submit_gyrA.sbatch` | `env_mlsa` | steps 5b, 8, 9 | `output/hsp65_refalign/`, `output/gyrA_refalign/{project,public}/` |
| 10 | iTOL files | `scripts/07_generate_itol_species_labels.sh` | none | steps 3, 5b, 9 | `output/iTOL/<run>/` |
| 11 | samples report | `scripts/08_mkan329_samples_report.py` | `env_mic` | steps 5b, 9 | `SAMPLES.md` |
| 12a | cgMLST scheme, allele calls, per-genome QC | `kansasii-cgmlst: submit_all.sbatch` (steps 00-07) | `env_cgmlst` | steps 2, 5b | `output/cgmlst/sample_qc.tsv`, `runs/cgmlst/` |
| 12b | cgMLST distances, MSTs, Ridom export; core-SNP MSTs | `kansasii-cgmlst: submit_all.sbatch` (steps 08-10), `kansasii-mst: submit_all.sbatch` | `env_cgmlst`, `env_mst` | steps 5b, 9 | `output/cgmlst/`, `output/ridom_assemblies.tar.gz`, `output/mst/` |
| 13 | AMR marker screen | `kansasii-amr-marker-screen: submit_arm.sbatch`, then `submit_arm_bam.sbatch` (optional) and `submit_arm_reannot.sbatch` | `env_amr` | steps 5b, 6, 9 | `output/arm/`, `output/amr_bam/` |
| 14 | atypical gyrA / hsp65 samples, output overview | `kansasii-docs: bin/make_atypical_table.py`, `bin/make_summary.py` | `env_mlsa` | step 9b | `output/atypical_samples/`, `output/SUMMARY.html` |
| - | Sanger Microsynth mail (independent, routine) | `sanger-microsynth: submit_fetch_analyse.sbatch` | `env_sanger_ms` | mail, step 8 refs | `output/sanger-microsynth/` |

Step 9 needs steps 6, 8 and 12a (`cgmlst_called_pct`) and steps 8 and 12b need step 9 for the `species`/`excluded` columns of the previous table; for the first run the
cgMLST pool uses the species of the previous results table. Step 9 needs step 8 for the `species_sanger_mlsa`, `species_sanger_mlsa_excl` and `species_sanger_refalign` columns, and step 8 needs the link
table of step 2, so the link table is always built first and the results table last.
`gtdb232` metadata is downloaded by step 1.

Step 5b is the only long step (days of CPU). The downstream steps are cheap and deterministic:
rerun them whenever step 2, 5b or the MIC inputs change, so that the tables stay consistent.

Scripts (`repos/immensekansasii/scripts/`):

| Script | Conda env | Purpose |
|---|---|---|
| `01_gtdb_mycobacteria_genomes.sh` | `env_immense` | GTDB representative lists + genome download |
| `02_screening_map_link.py` | `env_mic` | link TNR / LNR / MHK / NGS -> `screening_map_link.csv` |
| `03_run_gtdb_tree.sh` | none | link the 7 representatives and submit the reference-tree run (section 2a) |
| `04_mkan329_batches.sh` | none | split the Mkan329 reads into a test batch + NR-ordered batches, print the run commands |
| `05_mkan329_batch_jc.sh` | none | build `batches/b05` (53 jc isolates, NR 134-186) and `b06` (resequenced `Mkan329-056-jc`, `-009-jc`, run id `mkan329_jc`) from the jc reads (`reads/kansasii_jc`, named by NGS TNR) via `NGS_JC` in `screening_map_link.csv` |
| `06_screening_map_results.py` | `env_mic` | add species + `TNR_MLSA` + MIC -> `screening_map_results.csv` |
| `07_generate_itol_species_labels.sh` | none | iTOL labels and colour strips for trees |
| `08_mkan329_samples_report.py` | `env_mic` | `SAMPLES.md` from the per-sample summary tables |
| `09_public_fetch_metadata.sh` | none | ENA run metadata of public BioProjects -> `data/illumina/public/<BioProject>/metadata.tsv` |
| `10_public_select_and_download.py` | `env_mic` | all runs -> `selected.tsv` (no species/host filtering; single-end or non-Illumina runs go to `not_runnable.tsv`), md5-checked download to `reads/` |
| `11_public_batches.sh` | none | test batch + batches of 45 per BioProject, prints the `run_IMMENSE.sh` commands (run id `public_<BioProject>`) |
| `run_downstream.sh` | none | submit steps 6-13 as a Slurm dependency chain |
| `install_notes.txt`, `worktree-branching.txt` | - | notes (not runnable) |

## 1. GTDB reference genomes

```bash
srun --pty -n 1 -c 6 --time=01:00:00 --mem=16G bash -l   # compute node
conda activate env_immense                                # provides the NCBI `datasets` CLI
bash /shares/sander.imm.uzh/MM/kansasii/repos/immensekansasii/scripts/01_gtdb_mycobacteria_genomes.sh
```

- Reads `data/immensekansasii/gtdb/gtdb232/bac120_metadata_r232.tsv`.
- Downloads all Mycobacteriaceae genomes to
  `data/gtdb_genomes/Mycobacteriaceae/ncbi_dataset/data/` (existing ones are skipped).
- Writes to `output/immensekansasii/gtdb/gtdb232/`:
  - `mycobacterium_relevant_species_representative_accessions_renamed.txt`:
    20 GTDB representatives of the kansasii complex, MTBC, MAC and *M. simiae*
  - `kansasii_complex_gtdb_representative_accessions_renamed.txt`: the 7 kansasii-complex
    representatives (input of the tree run in step 2)
  - `kansasii_complex_type_strains.tsv`, `mycobacterium_type_strains.tsv`
  - Both lists have two columns, `accession` and `accession_query`. The `_query` suffix is
    needed because every accession is itself a GTDB-Tk reference genome, and
    `gtdbtk_classify_wf` rejects query genomes whose ids match its references.
- `mlsa-kansasii/scripts/02_link_gtdb_kansasii_complex.sh` symlinks the downloaded
  kansasii-complex genomes by species.

## 2. Pipeline runs

Rules for every run:
- Start in its own `runs/<run_name>/`, never in `output/`: Nextflow writes `work/` into the
  start directory, it is large and temporary and must not reach `output/` (which is
  downloaded to local).
- `run_IMMENSE.sh` only submits a SLURM job. When it has finished and been checked, rsync
  the end results (without `work/`) to `output/<run_name>/` and delete `work/`.
- `--kansasii_snippy_db <dir>` is required (one db dir per run under
  `/shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/kansasii_complex/`) and the
  dir must exist before the run (`mkdir -p`).

```bash
mkdir -p /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/kansasii_complex/<db_name> /shares/sander.imm.uzh/MM/kansasii/runs/<run_name>
cd /shares/sander.imm.uzh/MM/kansasii/runs/<run_name>
bash /shares/sander.imm.uzh/MM/kansasii/repos/immensekansasii/run_IMMENSE.sh -j <job_name> -t <input_type> -r <run_name> \
     -x "--kansasii_snippy_db /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/kansasii_complex/<db_name>" -i <input_dir>
rsync -a --exclude work --exclude .nextflow --exclude '*_transfer_result/genomes/' \
     /shares/sander.imm.uzh/MM/kansasii/runs/<run_name>/ /shares/sander.imm.uzh/MM/kansasii/output/<run_name>/
```

### 2a. `kansasii_complex_gtdb_representatives` (reference tree, `-t fasta`)

`03_run_gtdb_tree.sh` symlinks the 7 genomes from step 1 as `<accession>_query.fasta` into
`data/gtdb_genomes/Mycobacteriaceae/kansasii_complex_gtdb_representatives/` and runs the
pipeline on that directory. The sample id is the fasta file stem, so tree tips are
`GCF_xxx_query` (plus a `Reference` tip). `kansasii_phylo.nf` writes
`<run>_transfer_result/kansasii_phylogeny/kansasii_complex_tree.treefile`.

iTOL files for this tree: see section 2c (default mode, no arguments).

### 2b. `mkan329` (real isolates, `-t fq_PE`)

Input: the delivered paired-end fastq in `data/illumina/Mkan329/reads/kansasii/`
(`Mkan329-NNN_r1.fastq.gz`, 68.8 GB zip from SWITCH FileSender, 133 isolates: NR 1-133)
and, for NR 134-186, the jc reads in `reads/kansasii_jc` (see the jc batch below). The run goes in
batches, a small test batch first. 

1. **Batches.** (no conda env; options `-r reads_dir -m link_csv -o batches_dir -t test_size
   -b batch_size`)
   ```bash
   bash /shares/sander.imm.uzh/MM/kansasii/repos/immensekansasii/scripts/04_mkan329_batches.sh
   ```
   writes, in NR order (first column of `screening_map_link.csv`):
   - `batches/test/`: the first 3 isolates (pilot)
   - `batches/b01 ... bNN/`: 45 isolates each (`b01` starts at NR 1 again, so the pilot
     isolates are re-run there: ~2% extra compute, and the pilot db stays out of the
     real tree)
   - `batches/all/`: every isolate with a complete pair (**not used**: it re-runs everything, see 2)

   Each batch dir is flat: `Mkan329-NNN_R1.fastq.gz` / `Mkan329-NNN_R2.fastq.gz` symlinks
   (sample id = `PROBENNUMMER`; **upper-case `_R1/_R2`**, because the `{R1,R2,1,2}` glob in
   `main.nf` is case-sensitive and would not find the delivered lower-case names) plus
   `id_map.tsv` (`NR`, `PROBENNUMMER`, original paths). **Do not use the bare `NR` as sample
   id** (as the former `run.sh` did): `checkm.nf` runs `grep ${sample_id}` on the CheckM
   log, a bare number matches nearly every line (timestamps), which garbles
   `<run>_quality.tsv` from `checkm_completeness` on, and `evaluate_QC.py` then crashes in
   `merge_summaries` (found in the first pilot, 2026-10-03). Proper fix would be anchoring
   that grep in `checkm.nf`. Isolates without a complete pair are skipped
   with a warning; after the next delivery rerun the script **before** submitting (batch
   membership can shift; old `bNN` dirs are removed). It only builds links and prints the
   commands below, it submits nothing.

   **jc batch (`b05`).** The reads in `reads/kansasii_jc` are named by NGS TNR, so
   `04_mkan329_batches.sh` does not see them. `scripts/05_mkan329_batch_jc.sh` (options
   `-r reads_dir -m link_csv -c ngs_column -o batch_dir -x "ids to skip" -I "ids to keep" -s id_suffix -R run_id`)
   links them under `Mkan329-NNN` using the `NGS_JC` column of `screening_map_link.csv` into `batches/b05`
   and prints the run command. Mkan329-009 and -056 are skipped by default: they are already
   in b01/b02 and the same id with other reads would clash in `runs/mkan329`. Rerun it after
   `04_mkan329_batches.sh`, which removes all `bNN` dirs.

   **Resequenced samples (`b06`).** `-I "Mkan329-056 Mkan329-009" -x "" -s -jc -R mkan329_jc -o .../batches/b06`
   builds `Mkan329-056-jc` (NGS 2023187866) and `Mkan329-009-jc` (2023187902) and runs them in their
   own run `runs/mkan329_jc` (own snippy db), so they stay out of the shared `runs/mkan329` tree and
   its iTOL files. Results: 056-jc is a clean *M. kansasii* ST38 (CheckM 0.61 %, MetaPhlAn4 purity
   99.1 %, 39x); 009-jc is *M. persicum* (ST `-`).

   Output with the 133 delivered mm isolates plus the jc batch:
   ```
   test: 3 samples (NR 1..3)
   b01: 45 samples (NR 1..45)
   b02: 45 samples (NR 46..90)
   b03: 41 samples (NR 91..133, without 100 and 108 of the first delivery)
   b04:  2 samples (NR 100, 108; delivered later)
   b05: 53 samples (NR 134..186, jc reads; `05_mkan329_batch_jc.sh`)
   ```
2. **One run dir, one run id, one snippy db.** `--kansasii_snippy_db` is required
   (`main.nf` stops without it). `b01..bNN` all run in `runs/mkan329/` with
   `-r mkan329` and `--kansasii_snippy_db /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/kansasii_complex/mkan329`
   (full path in the commands below).
   **Create the db dir first** (`mkdir -p`): the snippy step bind-mounts it into the container
   and fails with "container creation failed ... mount" if it does not exist yet.
   Per-sample results (`assembly/results/<NR>/`) and the snippy db accumulate across batches.
   The tree (`snippy-core` over the whole db) therefore covers every isolate run so far: the
   tree written by the last batch is the cumulative one. The run-level tables
   (`mkan329_transfer_result/mkan329_quality.tsv`, `_quality_QC.csv`, resistance table,
   multiqc) only cover the samples of *that* invocation, so each batch overwrites the
   previous batch's tables; for a table over all isolates use `SAMPLES.md`
   (`scripts/08_mkan329_samples_report.py`, built from the per-sample summary tables).
   **Do not run a final `all` batch to get cumulative tables:** `-resume` only reuses a task
   when its input paths are identical (the hash includes the file path), and `batches/all/`
   has other symlink paths than `b01..b03`, so it re-ran every sample from scratch (0 cache
   hits; cancelled after 2 min, ~2500 CPU-hours otherwise). `-resume` works for the same
   command in the same dir (e.g. the pilot). Only one Nextflow run is allowed per dir, so
   **submit the batches one after another** (wait until a batch has finished), not in
   parallel. If a controller job keeps running after the log says "Goodbye" or the log
   stops moving for hours, check `.nextflow.log` before waiting longer; its cache db can end
   up corrupt (`Can't open cache DB ... Corruption`), then move `.nextflow` aside and start
   fresh (everything of that run is recomputed).
3. **Pilot first.** The `test` batch has its own run dir (`runs/mkan329_test/`), run id
   (`mkan329_test`) and db (`mkan329_test`), so it can not touch the real run. Check it
   (all 3 isolates finish, species call and gyrA plausible, `mkan329_test_quality.tsv`
   sane), only then start `b01`. The script prints these commands too. If a run dies,
   resubmit the **same** command from the same dir: `-resume` reuses finished tasks.
   ```bash
   # pilot
   mkdir -p /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/kansasii_complex/mkan329_test /shares/sander.imm.uzh/MM/kansasii/runs/mkan329_test
   cd /shares/sander.imm.uzh/MM/kansasii/runs/mkan329_test
   bash /shares/sander.imm.uzh/MM/kansasii/repos/immensekansasii/run_IMMENSE.sh -j job_mkan329_test -t fq_PE -r mkan329_test \
        -x "--kansasii_snippy_db /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/kansasii_complex/mkan329_test" \
        -i /shares/sander.imm.uzh/MM/kansasii/data/illumina/Mkan329/batches/test
   ```
   Real run, one batch after another (wait until `squeue -u $USER` shows no more
   `job_mkan329_*` / `nf-*` jobs before submitting the next one); `run_IMMENSE.sh` only submits the controller job and returns at once, so a loop over several batches would start them all in parallel in the same dir: `b01`, `b02`, `b03`:
   ```bash
   mkdir -p /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/kansasii_complex/mkan329 /shares/sander.imm.uzh/MM/kansasii/runs/mkan329
   cd /shares/sander.imm.uzh/MM/kansasii/runs/mkan329
   b=b01    # then b02, b03: change it and rerun only after the previous one has finished
   bash /shares/sander.imm.uzh/MM/kansasii/repos/immensekansasii/run_IMMENSE.sh -j job_mkan329_$b -t fq_PE -r mkan329 \
        -x "--kansasii_snippy_db /shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/kansasii_complex/mkan329" \
        -i /shares/sander.imm.uzh/MM/kansasii/data/illumina/Mkan329/batches/$b
   ```
   After the last batch has finished and been checked, copy the end results and delete `work/`:
   ```bash
   rsync -a --exclude work --exclude .nextflow --exclude '*_transfer_result/genomes/' \
        /shares/sander.imm.uzh/MM/kansasii/runs/mkan329/ /shares/sander.imm.uzh/MM/kansasii/output/mkan329/
   rm -rf /shares/sander.imm.uzh/MM/kansasii/runs/mkan329/work
   ```
4. **Results table** (`conda activate env_mic`; runs after the MIC analysis and the MLSA
   programs, see "Run order"). `06_screening_map_results.py` reads the per-sample summary tables
   `runs/mkan329/assembly/results/<Mkan329-NNN>/3_quality/summary/` (complete for every isolate run so
   far; the merged `quality.tsv` only covers the last batch and is just a fallback):
   ```bash
   python /shares/sander.imm.uzh/MM/kansasii/repos/immensekansasii/scripts/06_screening_map_results.py
   ```
   Samples are named `Mkan329-NNN`, so no `--id-map` is needed. Check the printed counts
   (186 rows, 186 with species) and the contamination warning.
5. **iTOL labels** for the sample tree:
   ```bash
   bash /shares/sander.imm.uzh/MM/kansasii/repos/immensekansasii/scripts/07_generate_itol_species_labels.sh -m samples -p mkan329_
   ```
   writes `mkan329_itol_species_labels.txt` (`Species [Mkan329-NNN]`) and
   `mkan329_itol_species_colorstrip.txt` and a copy of the tree to `output/iTOL/mkan329/`.
   Copy them to your computer and load them into iTOL as described in section 2c.

   In `samples` mode the script uses `PROBENNUMMER` (`Mkan329-NNN`) as the tree tip id and
   species from `data/imm/screening_map_results.csv`. It keeps only isolates that are tips of the
   tree (the csv also lists undelivered isolates), reads the tree from `runs/<run>/`, and adds the snippy `Reference` tip as "Reference genome"
   (grey). Bare species epithets (`kansasii`) get a `Mycobacterium ` prefix for the colour strip.

   **Tested:** on the current `runs/mkan329` tree (186 isolates + `Reference` = 187 tips, all labeled):
   180 kansasii complex (125 kansasii, 31 persicum, 20 pseudokansasii, 2 attenuatum, 1 innocens,
   1 ostraviense), 2 avium, 1 tuberculosis, 3 other (abscessus, xenopi, marinum). Re-run it after the
   tree is rebuilt.

   **Tested:** `-resume` does not reuse finished samples across batch dirs (see 2).

Where results are: species is **not** in `assembly/results/<s>/5_typing/` (that holds
`mlst/`, `pyMLST/`, `kansasii_snippy/`). It is in `3_quality/GTDB/<s>.tsv_gtdb_summary.tsv`
and in the run table `<run>_transfer_result/<run>_quality.tsv` (`gtdb_species`,
`gtdb_fastani_*`, `rMLST_best_species`, `16S_species`, ...).

### 2c. iTOL files for a run

Every tree run gets its own iTOL files, made independently of the others. A run needs
only its finished tree, `<run>_transfer_result/kansasii_phylogeny/kansasii_complex_tree.treefile`
(read from `runs/<run>/`), plus a table mapping tip ids to species.
`07_generate_itol_species_labels.sh` (no conda env) writes three files to `output/iTOL/<run>/`
(plus a copy of the mapping input, i.e. the accessions list or `screening_map_results.csv`):

| File | Content |
|---|---|
| `kansasii_complex_tree.treefile` (+ `.iqtree`) | copy of the run's tree; this is what you upload to iTOL |
| `<prefix>itol_species_labels.txt` | iTOL LABELS dataset: tip text becomes `Species [id]` |
| `<prefix>itol_species_colorstrip.txt` | iTOL DATASET_COLORSTRIP: strip per tip by complex: MTBC red, MAC blue, *M. simiae* purple, other grey. The *M. kansasii* complex is green in gtdb mode; in samples mode each of its species gets its own color (*kansasii* green, *persicum* orange, *pseudokansasii* brown, *innocens* pink, *attenuatum* yellow, *ostraviense* cyan, *gastri* teal) |

The two annotation files are display overlays only; the tree and its tip ids are unchanged.
The snippy `Reference` tip of each tree is labelled "Reference genome" (grey).

| Run type | Command | Tip ids | Species from |
|---|---|---|---|
| GTDB reference genomes (default `-m gtdb`) | `07_generate_itol_species_labels.sh [-a ACCESSIONS] [-n RUN]` | `GCF_xxx_query` from the `*_accessions_renamed.txt` file | GTDB metadata `bac120_metadata_r232.tsv` (`s__` token) |
| real isolates (`-m samples`) | `07_generate_itol_species_labels.sh -m samples -p mkan329_ [-n RUN]` | `Mkan329-NNN` (`PROBENNUMMER`), only isolates that are tips of the tree | `species` column of `data/imm/screening_map_results.csv` (`LABEL` as fallback) |

Defaults: `-n kansasii_complex_gtdb_representatives` (gtdb) or `mkan329` (samples); `-a` defaults
to the 7-genome kansasii complex list, use
`mycobacterium_relevant_species_representative_accessions_renamed.txt` for the 20-genome set,
whose run is `runs/relevant_species_tree_run/` (copied from `output-old/` without `work/` and
`.nextflow`, so it cannot be resumed; 21 tips = 20 genomes + `Reference`):
```bash
bash /shares/sander.imm.uzh/MM/kansasii/repos/immensekansasii/scripts/07_generate_itol_species_labels.sh \
  -a mycobacterium_relevant_species_representative_accessions_renamed.txt -n relevant_species_tree_run
```
`-o` output dir, `-p` file prefix.

To make files for a new run: (1) finish the run, so the `.treefile` exists; (2) make sure
every tip id is in the mapping (gtdb: accessions file, samples: `screening_map_results.csv`
via `06_screening_map_results.py`); (3) run the script with `-n <run>` (plus `-m`/`-a`/`-p`);
(4) check there is no `WARNING: n/m entries have a species`, which means some tips are unlabeled.
Re-run after the tree is rebuilt, because the files are only valid for the tree they were made with.

Current outputs: `output/iTOL/kansasii_complex_gtdb_representatives/` (8 tips),
`output/iTOL/relevant_species_tree_run/` (21 tips), `output/iTOL/mkan329/` (132 tips).

#### Patient isolates: midpoint-rooted tree, AST dots, species ring

`12_generate_itol_ast.py` (conda env `biopython`, needs Bio.Phylo) prunes the `mkan329` tree to the 171 patient
isolates of the complex (no `Reference` tip, no control / type strains with a `LABEL`, no `excluded` isolates),
roots it at the midpoint, rotates the branches so species sit together (topology unchanged) and writes to `output/iTOL/mkan329_patients/`: `kansasii_patients_midpoint.nwk`,
`itol_1_ast_dots.txt` (13 circle rings, filled = resistant, hollow = susceptible or intermediate, none = no MIC),
`itol_2_species_ring.txt` (outermost ring, load it last) and `itol_leaf_labels.txt`. Resistance is the CLSI category
(`<DRUG>_clsi_category`); EMB, INH, ETO and STR have no CLSI breakpoint, so `NON_CLSI_THRESHOLDS_MG_L` at the top of
the script (8, 8, 0.6, 16 mg/L; resistant if MIC is above) decides. Tests: `tests/test_itol_ast.py`.

The figure `data/imm/midpoint-rooted-tree.{pdf,svg}` is the iTOL render of these files (tree, `itol_1_ast_dots`,
`itol_2_species_ring`, leaf labels), exported by hand from itol.embl.de. No script writes or reads it; re-export it
after the tree or the script is re-run.

Getting the files into iTOL (the script only writes them on the server):

1. Copy to your computer, run from your laptop (not on the server):
   ```bash
   scp "<user>@<server-hostname>:/shares/sander.imm.uzh/MM/kansasii/output/iTOL/<run>/*" ~/Downloads/
   ```
   A GUI client (WinSCP, Cyberduck, MobaXterm) works too.
2. At <https://itol.embl.de> upload the `.treefile`, open the tree, then drag
   `*itol_species_labels.txt` and `*itol_species_colorstrip.txt` onto the tree view.

## 3. Screening map

Sources in `data/imm/`: `screening_map_project.csv`, `screening_map_strains.csv`
(latin-1), `screening_map_ast.csv`, `screening_map_ngs_jc.csv` (reads in `reads/kansasii_jc`),
`screening_map_ngs_mm.csv` (reads in `reads/kansasii`), `screening_map_ast_jc.csv` (wide MIC table of the
jc isolates, `NR_JC` = its row number; only used for `MIC_JC`/`MHK` here), old `screening_map.csv` (comparison only).

```bash
conda activate env_mic
python /shares/sander.imm.uzh/MM/kansasii/repos/immensekansasii/scripts/02_screening_map_link.py [--indir DIR] [--out FILE] [--copy-to DIR]
```

Writes `data/imm/screening_map_link.csv` (copy in `output/`): one row per isolate,
key `PROBENNUMMER` (`Mkan329-NNN`), with `LNR`, `LNR2`, `TNR`, `TNR_JC`/`NGS_JC`, `TNR_MM`/`NGS_MM`, `TNR3..`,
`TNR_MHK`, `MHK`, `MHK_TNR_DIFFERS`, `MIC_JC`, `LABEL` (reference strains, NR 126-133). Extra TNR columns exist because a case can
be re-opened under a new TNR; their number follows the isolate with the most (Mkan329-183, four extra).
`TNR_MHK` is the TNR the `MHK` (AST order) was made under: the strains TNR whose `LNR` equals
the order's `AUFTRAGSNUMMER`. It differs from `TNR` when the AST was done on a follow-up culture (e.g.
Mkan329-056: `TNR` 2022500332, `TNR_MHK` 2022500349). If the order's LNR is not in the strains
table (case reopened only for the MHK: new LNR, same TNR, see `LNR2`), `TNR_MHK` is the isolate's
own `TNR` when BESCHREIBUNG names the follow-up order (its LNR or TNR), else empty. Four rows
(Mkan329-028, -047, -071, -162) have neither a BESCHREIBUNG reference nor the LNR in strains; their
order was matched by DOB + received date only. They were checked by hand in the LIS (M/LAB): after
the file was closed the missing information was added as "Bleistift", so the order was made under the
isolate's own TNR. This is hard-coded as `LIS_VERIFIED_OWN_TNR` in `02_screening_map_link.py`
(`TNR_MHK` = `TNR`); add further rows there only after such a manual check.

`MHK_TNR_DIFFERS` is `yes` when `TNR_MHK` is another TNR than `TNR`: the MHK belongs to a different
culture than the one sequenced under `TNR`. Currently only
Mkan329-056: MHK 2023311034 was made on culture 2022500349 (`TNR_JC`, NGS 2023187866), which was
suspected to be contaminated; it was resequenced (`Mkan329-056-jc`, b06, run `mkan329_jc`) and the new
reads are clean, but they are not part of the shared `runs/mkan329` tree (b05 skips Mkan329-056). The
sequenced reads of Mkan329-056 (`NGS_MM`) are from 2022500332. `NGS_USED` is `NGS_MM` for Mkan329-056 (and -009), not the resequenced `-jc` reads. The flag is informational: `kansasii-mic`
still matches the 13 MIC rows of Mkan329-056 via the `MHK` column (decision: include them). A consumer that
needs a strict MIC/sequence pairing can drop rows with `MHK_TNR_DIFFERS = yes`.
Both the Mkan329-056 genome (CheckM 0.61 %) and the resequenced `-jc` genome (0.61 %, purity 99.1 %) are CheckM-clean, so
`contamination_flag` does not exclude Mkan329-056; its MHK pairing is covered by `MHK_TNR_DIFFERS` only.
`MIC_JC` is `JC_<NR_JC>` when one of the row's TNRs is in `screening_map_ast_jc.csv` (50 isolates, all via
`TNR_JC`). `kansasii-mic --ast-jc` uses that table for the MHK panel only where `mic.csv` has no panel
values for the isolate (37 isolates); for exactly those, `MHK` is set to the same `JC_<NR_JC>` (replacing an
MGIT-only or empty id). The 13 isolates with panel values in `mic.csv` keep their own MHK id (mic.csv wins).
So `MHK` is either an AST order TNR or a `JC_n`, never both.
It also prints a comparison with the old `screening_map.csv`.

**`mlsa-kansasii` is a consumer** and reads only the TNR columns and `PROBENNUMMER`:
`scripts/03_link_sanger_kansasii.sh` selects the columns by regex `^TNR(_JC|_MM|[0-9]+)?$`
and links the `.ab1` files whose path contains one of the 10-digit TNRs;
`mlsa-kansasii/scripts/08_sanger_mlsa.py` maps every TNR to its
`PROBENNUMMER` and pools reads per isolate. `kansasii_paths.TNR_COLUMNS` (and `TNR_COLUMNS_RESULTS`, with `TNR_MLSA`) is the
hand-maintained tuple, which must match the columns produced here.

### Results table

`06_screening_map_results.py` reads `screening_map_link.csv` (never modifies it) and writes
`data/imm/screening_map_results.csv` (copy in `output/`): all link columns plus
- `NGS_USED` (right after `NGS_MM`): the NGS id of the sequencing data that is used. If `NGS_MM` was done it is the one used, not `NGS_JC`; only if there is no `NGS_MM` is `NGS_JC` used. So Mkan329-001..133 = `NGS_MM`, Mkan329-134..186 = `NGS_JC`. Mkan329-009 and -056 have both and use `NGS_MM`; their resequenced `-jc` reads (b06, run `mkan329_jc`) are not used
- `species`, `gtdb_ani`, `gtdb_af`, `gtdb_reference`: GTDB-Tk call from the run's `quality.tsv`
- `checkm_contamination`, `contamination_flag`: CheckM contamination (%) of the assembly; flag = `contaminated` above `--max-contamination` (default 5). Flagged samples are mixed cultures, see `SPECIES.md`. CheckM is the criterion for contaminated cultures: MIC values of flagged isolates are not used for the final conclusion (filter on `contamination_flag`; the MIC columns and `output/mic/*` keep the values). Flagged now: Mkan329-010, -021, -035, -106, -113 (only 035 has MIC data)
- `cgmlst_called_pct`, `excluded` (after `contamination_flag`): `cgmlst_called_pct` = % of the cgMLST95 loci with an allele call (kansasii-cgmlst `output/cgmlst/sample_qc.tsv`, `--cgmlst-qc`; empty if the isolate is not allele-called); `excluded` = `true` if `contamination_flag` is `contaminated` or `cgmlst_called_pct` < `--min-cgmlst-pct` (default 90, Ridom's good-target threshold), or the row is a clinical sample (`LABEL` empty) with a GTDB species outside the complex (NR 184, *M. avium*), else `false`. Non-complex control strains (`LABEL` set) are not excluded by this. Genome-based repos (cgmlst, mst, amr screen) skip `excluded` isolates. Run order: cgmlst `STEPS="07"` -> 06 -> cgmlst `STEPS="08 09 10"`.
- `arm_mut`: markers called `MUT` by kansasii-amr-marker-screen (`output/arm/work/report/marker_calls.pass.tsv`), `<gene>-<marker>` comma-joined (e.g. `rpsL-K43R,rrs-A514C`). Includes non-discriminating markers (`discriminating = no`, reference carries the mutant allele), so `rrs-A514C` is in nearly every isolate. Needs the ARM pipeline to have run before this step
- `species_sanger_mlsa`, `species_sanger_mlsa_excl`: hsp65 `nearest_species` from `isolate_classification.tsv` of mlsa sanger_mlsa and sanger_mlsa_excluded
- `species_sanger_refalign`: `closest_species` of sanger_refalign `reference_alignment.tsv` for the representative hsp65 read, only if status is `ok` (empty for ambiguous/divergent/no_hit or until sanger_refalign is run)
- `TNR_MLSA`: TNR(s) of the representative Sanger reads (`representative_reads.tsv`)
  that differ from the row's `TNR`. Currently only Mkan329-183 (`2023500268`).

## 4. Uploading input tables from local

Copy the screening map source tables from the local project folder to the cluster, from a
local PowerShell terminal:

```powershell
scp A:\projects\kansasii\input\* mimeul@cluster.s3it.uzh.ch:/shares/sander.imm.uzh/MM/kansasii/data/imm/
```

(Copy a single file by naming it instead of `*`; add `-r` only if the folder has subfolders.)
Afterwards rerun `02_screening_map_link.py` (section 3) so `screening_map_link.csv` is rebuilt.

## 5. Downloading results to local `kansasii_C`

From a local PowerShell terminal:

```powershell
New-Item -ItemType Directory -Path "$env:USERPROFILE\kansasii_C\downloads\" -Force
scp -r mimeul@cluster.s3it.uzh.ch:/shares/sander.imm.uzh/MM/kansasii/output/* "$env:USERPROFILE\kansasii_C\downloads\"
```
