# M. kansasii project workflow

How the project-specific scripts around the IMMENSE pipeline fit together
(the pipeline itself is described in `README.md`). This replaces the README of
the former `kansasii-lit` repo. Everything runs on the s3it cluster; paths are
relative to `/shares/sander.imm.uzh/MM/kansasii/` (`K`) unless absolute.

## Directory layout

| Path | Content |
|---|---|
| `repos/immensekansasii` | this repo: pipeline + project scripts in `scripts/` |
| `repos/mlsa-kansasii` | MLSA / Sanger differentiation (reads `data/imm/screening_map_link.csv`) |
| `data/imm/` | screening map sources and derived tables |
| `data/lit/gtdb/gtdb232/` | GTDB r232 metadata (downloaded if missing) |
| `data/gtdb_genomes/` | genomes downloaded from NCBI, plus symlink dirs for runs |
| `data/illumina/Mkan329/reads/kansasii/` | delivered paired-end fastq `Mkan329-NNN_r1/_r2.fastq.gz` (lower case; 131 of 183 isolates so far) |
| `data/illumina/Mkan329/batches/<batch>/` | per-batch input from `mkan329_batches.sh`: `<NR>_R1/_R2.fastq.gz` symlinks + `id_map.tsv` |
| `runs/<run_name>/` | working dir of a pipeline run (contains large, temporary `work/`) |
| `output/<run_name>/` | end results of a run (no `work/`); downloaded to local `kansasii_C` |
| `output/lit/gtdb/gtdb232/` | accession lists, type strains, iTOL files |
| `output/mlsa/` | MLSA outputs |

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
bash repos/immensekansasii/scripts/gtdb_mycobacteria_genomes.sh
```

- Reads `data/lit/gtdb/gtdb232/bac120_metadata_r232.tsv`.
- Downloads all Mycobacteriaceae genomes to
  `data/gtdb_genomes/Mycobacteriaceae/ncbi_dataset/data/` (existing ones are skipped).
- Writes to `output/lit/gtdb/gtdb232/`:
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
  `software/pipelines/IMMense/IMMense_dependencies/databases/kansasii_complex/`).

```bash
mkdir -p runs/<run_name> && cd runs/<run_name>
bash repos/immensekansasii/run_IMMENSE.sh -j <job_name> -t <input_type> -r <run_name> \
     -x "--kansasii_snippy_db <dir>" -i <input_dir>
rsync -a --exclude work --exclude .nextflow --exclude '*_transfer_result/genomes/' \
     runs/<run_name>/ output/<run_name>/
```

### 2a. `kansasii_complex_gtdb_representatives` (reference tree, `-t fasta`)

`run.sh` symlinks the 7 genomes from step 1 as `<accession>_query.fasta` into
`data/gtdb_genomes/Mycobacteriaceae/kansasii_complex_gtdb_representatives/` and runs the
pipeline on that directory. The sample id is the fasta file stem, so tree tips are
`GCF_xxx_query` (plus a `Reference` tip). `kansasii_phylo.nf` writes
`<run>_transfer_result/kansasii_phylogeny/kansasii_complex_tree.treefile`.

iTOL annotation for this tree (upload the `.treefile` to iTOL, drag the files onto it):

```bash
bash repos/immensekansasii/scripts/generate_itol_species_labels.sh
```

Writes `itol_species_labels.txt` (`Species [accession]`) and `itol_species_colorstrip.txt`
(kansasii complex / MTBC / MAC / *M. simiae* complex / other) to
`output/iTOL/kansasii_complex_gtdb_representatives/`, together with a copy of the run's
`.treefile` and `.iqtree`. `-a` selects another accessions file (e.g. the 20-genome list),
`-n` another run name.

Getting the files into iTOL (the script only writes them on the server):

1. Copy to your computer, run from your laptop (not on the server):
   ```bash
   scp "<user>@<server-hostname>:/shares/sander.imm.uzh/MM/kansasii/output/iTOL/kansasii_complex_gtdb_representatives/*" ~/Downloads/
   ```
   For the mkan329 tree use `output/iTOL/mkan329/*` instead. A GUI
   client (WinSCP, Cyberduck, MobaXterm) works too. The `.treefile` is in the same directory for the GTDB tree.
2. At <https://itol.embl.de> upload the `.treefile`, open the tree, then drag
   `*_itol_species_labels.txt` and `*_itol_species_colorstrip.txt` onto the tree view.

### 2b. `mkan329` (real isolates, `-t fq_PE`)

Input: the delivered paired-end fastq in `data/illumina/Mkan329/reads/kansasii/`
(`Mkan329-NNN_r1.fastq.gz`, 68.8 GB zip from SWITCH FileSender, 131 isolates: NR 1-133
without 100 and 108; 134-183 not delivered yet). The run goes in batches, a small test
batch first. (The old single-run block in `run.sh` is untested and superseded by this.)

1. **Batches.** `bash repos/immensekansasii/scripts/mkan329_batches.sh` (no conda env;
   options `-r reads_dir -m link_csv -o batches_dir -t test_size -b batch_size`) writes,
   in NR order (first column of `screening_map_link.csv`):
   - `batches/test/`: the first 3 isolates
   - `batches/b01 ... bNN/`: 30 isolates each (starts at NR 1 again, so the test isolates
     are re-run in `b01`)

   Each batch dir is flat: `<NR>_R1.fastq.gz` / `<NR>_R2.fastq.gz` symlinks (sample id =
   `NR`; **upper-case `_R1/_R2`**, because the `{R1,R2,1,2}` glob in `main.nf` is
   case-sensitive and would not find the delivered lower-case names) plus `id_map.tsv`
   (`NR`, `PROBENNUMMER`, original paths). Isolates without a complete pair are skipped
   with a warning; after the next delivery rerun the script **before** submitting (batch
   membership can shift). It only builds links and prints the commands below, it submits
   nothing.

   Output with the current 131 isolates:
   ```
   test: 3 samples (NR 1..3)
   b01: 30 samples (NR 1..30)
   b02: 30 samples (NR 31..60)
   b03: 30 samples (NR 61..90)
   b04: 30 samples (NR 91..122)
   b05: 11 samples (NR 123..133)
   ```
2. **Snippy db.** `--kansasii_snippy_db` is required (`main.nf` stops without it).
   `kansasii_phylo.nf` copies every sample into that dir and runs `snippy-core` over all of
   it, so the test batch gets its own db (`.../kansasii_complex/mkan329_test`) and `b01..bNN`
   share one (`.../kansasii_complex/mkan329`): the tree of the last batch to finish covers
   all of them. `.../` is
   `/shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases`.
3. **Run the test batch first**, check it (all 3 isolates finish, species call and gyrA
   plausible), only then the others. The script prints one command per batch, each from its
   own `runs/mkan329_<batch>/`:
   ```bash
   mkdir -p runs/mkan329_test && cd runs/mkan329_test \
     && bash repos/immensekansasii/run_IMMENSE.sh -j job_mkan329_test -t fq_PE -r mkan329_test \
          -x "--kansasii_snippy_db <databases>/kansasii_complex/mkan329_test" \
          -i data/illumina/Mkan329/batches/test
   # real batches (b01 ... b05), same pattern:
   mkdir -p runs/mkan329_b01 && cd runs/mkan329_b01 \
     && bash repos/immensekansasii/run_IMMENSE.sh -j job_mkan329_b01 -t fq_PE -r mkan329_b01 \
          -x "--kansasii_snippy_db <databases>/kansasii_complex/mkan329" \
          -i data/illumina/Mkan329/batches/b01
   ```
   (the script prints them with absolute paths). When a batch has finished and been
   checked, rsync it to `output/mkan329_<batch>/` as in the rules above.
4. **Results table** (`conda activate kansasii_mic`), per batch:
   ```bash
   python repos/immensekansasii/scripts/screening_map_results.py \
     --quality output/mkan329_b01/mkan329_b01_transfer_result/mkan329_b01_quality.tsv \
     --id-map data/illumina/Mkan329/batches/b01/id_map.tsv
   ```
   **Open:** `--quality` and `--id-map` each take a single file and the script writes one
   `screening_map_results.csv`, so batches can not be combined yet (it needs a merge of the
   `*_quality.tsv` / `id_map.tsv` files or multi-file options). Not tested.
5. **iTOL labels** for the sample tree:
   `bash scripts/generate_itol_species_labels.sh -m samples -p mkan329_` writes
   `mkan329_itol_species_labels.txt` (`Species [Mkan329-NNN]`) and
   `mkan329_itol_species_colorstrip.txt` and a copy of the tree to `output/iTOL/mkan329/`.
   Copy them to your computer and load them into iTOL as described in section 2a. Use the
   tree of the last batch (covers all isolates in the shared db); not tested with the batch
   run names.

Where results are: species is **not** in `assembly/results/<s>/5_typing/` (that holds
`mlst/`, `pyMLST/`, `kansasii_snippy/`). It is in `3_quality/GTDB/<s>.tsv_gtdb_summary.tsv`
and in the run table `<run>_transfer_result/<run>_quality.tsv` (`gtdb_species`,
`gtdb_fastani_*`, `rMLST_best_species`, `16S_species`, ...).

## 3. Screening map

Sources in `data/imm/`: `screening_map_project.csv`, `screening_map_strains.csv`
(latin-1), `screening_map_ast.csv`, `screening_map_ngs_jc.csv`, old `screening_map.csv`.

```bash
conda activate kansasii_mic
python repos/immensekansasii/scripts/screening_map_link.py [--indir DIR] [--out FILE] [--copy-to DIR]
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
- `species_sanger`: `nearest_species` from `isolate_classification.tsv` (mlsa)
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
