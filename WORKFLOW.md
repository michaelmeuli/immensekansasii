# M. kansasii project workflow

How the project-specific scripts around the IMMENSE pipeline fit together
(the pipeline itself is described in `README.md`). This replaces the README of
the former `kansasii-lit` repo. Everything runs on the s3it cluster. Paths in the
tables and text are relative to `/shares/sander.imm.uzh/MM/kansasii/` (`K`) unless
absolute; **code blocks use full paths** and can be pasted as they are (only
`<placeholders>` need filling in).

## Directory layout

| Path | Content |
|---|---|
| `repos/immensekansasii` | this repo: pipeline + project scripts in `scripts/` |
| `repos/mlsa-kansasii` | MLSA / Sanger differentiation (reads `data/imm/screening_map_link.csv`) |
| `data/imm/` | screening map sources and derived tables |
| `data/lit/gtdb/gtdb232/` | GTDB r232 metadata (downloaded if missing), accession lists, type strains |
| `data/gtdb_genomes/` | genomes downloaded from NCBI, plus symlink dirs for runs |
| `data/illumina/Mkan329/reads/kansasii/` | delivered paired-end fastq `Mkan329-NNN_r1/_r2.fastq.gz` (lower case; 131 of 183 isolates so far) |
| `data/illumina/Mkan329/batches/<batch>/` | per-batch input from `mkan329_batches.sh`: `Mkan329-NNN_R1/_R2.fastq.gz` symlinks + `id_map.tsv` |
| `runs/<run_name>/` | working dir of a pipeline run (contains large, temporary `work/`) |
| `output/<run_name>/` | end results of a run (no `work/`); downloaded to local `kansasii_C` |
| `output/lit/gtdb/gtdb232/` | convenience copy of the accession lists and type strains |
| `output/iTOL/<run_name>/` | iTOL tree + annotation files per run |
| `output/mlsa/` | MLSA outputs |

**Rule:** scripts read only from `data/` and `runs/`. `output/` only receives copies made by
the scripts (results, iTOL files, lists) for convenience and download.

Scripts (`repos/immensekansasii/scripts/`):

| Script | Conda env | Purpose |
|---|---|---|
| `gtdb_mycobacteria_genomes.sh` | `env_immense` | GTDB representative lists + genome download |
| `generate_itol_species_labels.sh` | none | iTOL labels and colour strips for trees |
| `screening_map_link.py` | `kansasii_mic` | link TNR / LNR / MHK / NGS -> `screening_map_link.csv` |
| `screening_map_results.py` | `kansasii_mic` | add species + `TNR_MLSA` -> `screening_map_results.csv` |
| `mkan329_batches.sh` | none | split the Mkan329 reads into a test batch + NR-ordered batches, print the run commands |
| `run.sh` | `env_immense` | the two pipeline runs below (copy blocks, not run as a whole) |

## 1. GTDB reference genomes

```bash
srun --pty -n 1 -c 6 --time=01:00:00 --mem=16G bash -l   # compute node
conda activate env_immense                                # provides the NCBI `datasets` CLI
bash /shares/sander.imm.uzh/MM/kansasii/repos/immensekansasii/scripts/gtdb_mycobacteria_genomes.sh
```

- Reads `data/lit/gtdb/gtdb232/bac120_metadata_r232.tsv`.
- Downloads all Mycobacteriaceae genomes to
  `data/gtdb_genomes/Mycobacteriaceae/ncbi_dataset/data/` (existing ones are skipped).
- Writes to `data/lit/gtdb/gtdb232/` (and copies to `output/lit/gtdb/gtdb232/`):
  - `mycobacterium_relevant_species_representative_accessions_renamed.txt`:
    20 GTDB representatives of the kansasii complex, MTBC, MAC and *M. simiae*
  - `kansasii_complex_gtdb_representative_accessions_renamed.txt`: the 7 kansasii-complex
    representatives (input of the tree run in step 2)
  - `kansasii_complex_type_strains.tsv`, `mycobacterium_type_strains.tsv`
  - Both lists have two columns, `accession` and `accession_query`. The `_query` suffix is
    needed because every accession is itself a GTDB-Tk reference genome, and
    `gtdbtk_classify_wf` rejects query genomes whose ids match its references.
- `mlsa-kansasii/scripts/link_gtdb_kansasii_complex.sh` symlinks the downloaded
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

`run.sh` symlinks the 7 genomes from step 1 as `<accession>_query.fasta` into
`data/gtdb_genomes/Mycobacteriaceae/kansasii_complex_gtdb_representatives/` and runs the
pipeline on that directory. The sample id is the fasta file stem, so tree tips are
`GCF_xxx_query` (plus a `Reference` tip). `kansasii_phylo.nf` writes
`<run>_transfer_result/kansasii_phylogeny/kansasii_complex_tree.treefile`.

iTOL files for this tree: see section 2c (default mode, no arguments).

### 2b. `mkan329` (real isolates, `-t fq_PE`)

Input: the delivered paired-end fastq in `data/illumina/Mkan329/reads/kansasii/`
(`Mkan329-NNN_r1.fastq.gz`, 68.8 GB zip from SWITCH FileSender, 131 isolates: NR 1-133
without 100 and 108; 134-183 not delivered yet). The run goes in batches, a small test
batch first. (The old single-run block in `run.sh` is untested and superseded by this.)

1. **Batches.** (no conda env; options `-r reads_dir -m link_csv -o batches_dir -t test_size
   -b batch_size`)
   ```bash
   bash /shares/sander.imm.uzh/MM/kansasii/repos/immensekansasii/scripts/mkan329_batches.sh
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
   id** (as the old `run.sh` block did): `checkm.nf` runs `grep ${sample_id}` on the CheckM
   log, a bare number matches nearly every line (timestamps), which garbles
   `<run>_quality.tsv` from `checkm_completeness` on, and `evaluate_QC.py` then crashes in
   `merge_summaries` (found in the first pilot, 2026-10-03). Proper fix would be anchoring
   that grep in `checkm.nf`. Isolates without a complete pair are skipped
   with a warning; after the next delivery rerun the script **before** submitting (batch
   membership can shift; old `bNN` dirs are removed). It only builds links and prints the
   commands below, it submits nothing.

   Output with the current 131 isolates:
   ```
   test: 3 samples (NR 1..3)
   b01: 45 samples (NR 1..45)
   b02: 45 samples (NR 46..90)
   b03: 41 samples (NR 91..133)
   all: 131 samples (NR 1..133)
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
   (`scripts/mkan329_samples_report.py`, built from the per-sample summary tables).
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
4. **Results table** (`conda activate kansasii_mic`). `screening_map_results.py` takes a single
   `quality.tsv`, which now only covers the last batch (see 2), so this needs a combined table
   first (not built yet); per batch, e.g. for `b03`:
   ```bash
   python /shares/sander.imm.uzh/MM/kansasii/repos/immensekansasii/scripts/screening_map_results.py \
     --quality /shares/sander.imm.uzh/MM/kansasii/output/mkan329/mkan329_transfer_result/mkan329_quality.tsv \
     --id-map /shares/sander.imm.uzh/MM/kansasii/data/illumina/Mkan329/batches/b03/id_map.tsv
   ```
   (its default `--id-map` is still the old `data/mkan329_short/id_map.tsv`, so pass it;
   the quality table's `Sample` is `Mkan329-NNN`, which it matches via `PROBENNUMMER`).
5. **iTOL labels** for the sample tree:
   ```bash
   bash /shares/sander.imm.uzh/MM/kansasii/repos/immensekansasii/scripts/generate_itol_species_labels.sh -m samples -p mkan329_
   ```
   writes `mkan329_itol_species_labels.txt` (`Species [Mkan329-NNN]`) and
   `mkan329_itol_species_colorstrip.txt` and a copy of the tree to `output/iTOL/mkan329/`.
   Copy them to your computer and load them into iTOL as described in section 2c.

   In `samples` mode the script uses `PROBENNUMMER` (`Mkan329-NNN`) as the tree tip id and
   species from `data/imm/screening_map_results.csv`. It keeps only isolates that are tips of the
   tree (the csv also lists undelivered isolates), reads the tree from `runs/<run>/`, and adds the snippy `Reference` tip as "Reference genome"
   (grey). Bare species epithets (`kansasii`) get a `Mycobacterium ` prefix for the colour strip.

   **Tested:** on the current `runs/mkan329` tree (131 isolates + `Reference` = 132 tips):
   126 kansasii complex, 1 avium, 1 tuberculosis, 4 other. Re-run it after the tree is rebuilt
   with the remaining isolates.

   **Tested:** `-resume` does not reuse finished samples across batch dirs (see 2).
   **Not yet tested:** steps 4-5 on the batch outputs.

Where results are: species is **not** in `assembly/results/<s>/5_typing/` (that holds
`mlst/`, `pyMLST/`, `kansasii_snippy/`). It is in `3_quality/GTDB/<s>.tsv_gtdb_summary.tsv`
and in the run table `<run>_transfer_result/<run>_quality.tsv` (`gtdb_species`,
`gtdb_fastani_*`, `rMLST_best_species`, `16S_species`, ...).

### 2c. iTOL files for a run

Every tree run gets its own iTOL files, made independently of the others. A run needs
only its finished tree, `<run>_transfer_result/kansasii_phylogeny/kansasii_complex_tree.treefile`
(read from `runs/<run>/`), plus a table mapping tip ids to species.
`generate_itol_species_labels.sh` (no conda env) writes three files to `output/iTOL/<run>/`
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
| GTDB reference genomes (default `-m gtdb`) | `generate_itol_species_labels.sh [-a ACCESSIONS] [-n RUN]` | `GCF_xxx_query` from the `*_accessions_renamed.txt` file | GTDB metadata `bac120_metadata_r232.tsv` (`s__` token) |
| real isolates (`-m samples`) | `generate_itol_species_labels.sh -m samples -p mkan329_ [-n RUN]` | `Mkan329-NNN` (`PROBENNUMMER`), only isolates that are tips of the tree | `species` column of `data/imm/screening_map_results.csv` (`LABEL` as fallback) |

Defaults: `-n kansasii_complex_gtdb_representatives` (gtdb) or `mkan329` (samples); `-a` defaults
to the 7-genome kansasii complex list, use
`mycobacterium_relevant_species_representative_accessions_renamed.txt` for the 20-genome set,
whose run is `runs/relevant_species_tree_run/` (copied from `output-old/` without `work/` and
`.nextflow`, so it cannot be resumed; 21 tips = 20 genomes + `Reference`):
```bash
bash /shares/sander.imm.uzh/MM/kansasii/repos/immensekansasii/scripts/generate_itol_species_labels.sh \
  -a mycobacterium_relevant_species_representative_accessions_renamed.txt -n relevant_species_tree_run
```
`-o` output dir, `-p` file prefix.

To make files for a new run: (1) finish the run, so the `.treefile` exists; (2) make sure
every tip id is in the mapping (gtdb: accessions file, samples: `screening_map_results.csv`
via `screening_map_results.py`); (3) run the script with `-n <run>` (plus `-m`/`-a`/`-p`);
(4) check there is no `WARNING: n/m entries have a species`, which means some tips are unlabeled.
Re-run after the tree is rebuilt, because the files are only valid for the tree they were made with.

Current outputs: `output/iTOL/kansasii_complex_gtdb_representatives/` (8 tips),
`output/iTOL/relevant_species_tree_run/` (21 tips), `output/iTOL/mkan329/` (132 tips).

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
(latin-1), `screening_map_ast.csv`, `screening_map_ngs_jc.csv`, old `screening_map.csv`.

```bash
conda activate kansasii_mic
python /shares/sander.imm.uzh/MM/kansasii/repos/immensekansasii/scripts/screening_map_link.py [--indir DIR] [--out FILE] [--copy-to DIR]
```

Writes `data/imm/screening_map_link.csv` (copy in `output/`): one row per isolate,
key `PROBENNUMMER` (`Mkan329-NNN`), with `LNR`, `LNR2`, `TNR`, `TNR_NGS`, `TNR3..`, `NGS`,
`MHK`, `LABEL` (reference strains, NR 126-133). Extra TNR columns exist because a case can
be re-opened under a new TNR; their number follows the isolate with the most (Mkan329-183).
It also prints a comparison with the old `screening_map.csv`.

**`mlsa-kansasii` is a consumer** and reads only the TNR columns and `PROBENNUMMER`:
`scripts/link_sanger_kansasii.sh` selects the columns by regex `^TNR(_NGS|[0-9]+)?$`
and links the `.ab1` files whose path contains one of the 10-digit TNRs;
`main2_sanger_differentiation/run_sanger_differentiation.py` maps every TNR to its
`PROBENNUMMER` and pools reads per isolate. `mlsa/__init__.py` has the hand-maintained
`SCREENING_MAP_TNR_COLUMNS` tuple, which must match the columns produced here.

### Results table

`screening_map_results.py` reads `screening_map_link.csv` (never modifies it) and writes
`data/imm/screening_map_results.csv` (copy in `output/`): all link columns plus
- `species`, `gtdb_ani`, `gtdb_af`, `gtdb_reference`: GTDB-Tk call from the run's `quality.tsv`
- `checkm_contamination`, `contamination_flag`: CheckM contamination (%) of the assembly; flag = `contaminated` above `--max-contamination` (default 10). Flagged samples are mixed cultures, see `SPECIES.md`
- `species_mlsa1`, `species_mlsa2`: hsp65 `nearest_species` from `isolate_classification.tsv` of mlsa main2 and main2_excluded
- `species_ref`: `closest_species` of main3 `reference_alignment.tsv` for the representative hsp65 read, only if status is `ok` (empty for ambiguous/divergent/no_hit or until main3 is run)
- `TNR_MLSA`: TNR(s) of the representative Sanger reads (`representative_reads.tsv`)
  that differ from the row's `TNR`. Currently only Mkan329-183 (`2023500268`).

## 4. Uploading input tables from local

Copy the screening map source tables from the local project folder to the cluster, from a
local PowerShell terminal:

```powershell
scp A:\projects\kansasii\input\* mimeul@cluster.s3it.uzh.ch:/shares/sander.imm.uzh/MM/kansasii/data/imm/
```

(Copy a single file by naming it instead of `*`; add `-r` only if the folder has subfolders.)
Afterwards rerun `screening_map_link.py` (section 3) so `screening_map_link.csv` is rebuilt.

## 5. Downloading results to local `kansasii_C`

From a local PowerShell terminal:

```powershell
New-Item -ItemType Directory -Path "$env:USERPROFILE\kansasii_C\downloads\" -Force
scp -r mimeul@cluster.s3it.uzh.ch:/shares/sander.imm.uzh/MM/kansasii/output/* "$env:USERPROFILE\kansasii_C\downloads\"
```

## Remaining in `kansasii-lit`

Only exploratory / one-off scripts (`lit_download.sh`, `lit_gtdb_226.sh`, `lit_gtdb_232.sh`,
`lit_gtdb_ref_check.sh`, `get_mkc_type_strains.sh`, `gtdb-adv-search-genomes.sh`,
`gtdb_adv_search_accessions/`). The workflow above no longer depends on them.
