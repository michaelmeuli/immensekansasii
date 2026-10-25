# kansasii repos

| Repo | Purpose |
|---|---|
| `immensekansasii` | IMMENSE pipeline (Nextflow, branch `kansasii`) and the project scripts that link, run and summarise it |
| `kansasii-mic` | MIC outlier analysis (MHK broth microdilution and MGIT) |
| `mlsa-kansasii` | species-complex differentiation by MLSA / Sanger / reference alignment |
| `hsp65-refalign` | check that sanger_refalign reference alignment of the Sanger hsp65 reads gives the genome species per isolate; atypical (persicum-like) hsp65 in project and public assemblies |
| `gyrA-refalign` | gyrA from the assemblies vs the 72 public genomes: is any sample persicum-like or another species at gyrA (project and public kept apart) |
| `kansasii-amr-marker-screen` | literature AMR-marker screen on assemblies and reads |
| `kansasii-mst` | core-SNP minimum spanning tree figures (complex, kansasii, pseudokansasii, persicum) |
| `kansasii-cgmlst` | chewBBACA cgMLST scheme for the complex + Ridom-style allele MST figures (pairwise deletion) |
| `sanger-microsynth` | routine: fetch Microsynth Sanger results by mail, identify, report |
| `kansasii-docs` | project index, data flow, provenance, shared constants (`templates/kansasii_paths.{py,sh}`), `check_sync.sh`, overview and atypical-sample tables |

**Run order:** `immensekansasii/WORKFLOW.md`, section "Run order". Scripts carry the number of their
step (`01_...`, `02_...`), so within one repo they sort in the order they are called.

After the IMMENSE pipeline runs (days, step 5b) everything else is one dependency chain:

```bash
bash immensekansasii/scripts/run_downstream.sh --dry-run    # print the sbatch commands
bash immensekansasii/scripts/run_downstream.sh [--with-bam] # link -> MIC -> MLSA -> cgMLST -> results table -> hsp65/gyrA/mst/arm -> overview
```

`check_sync.sh` reports uncommitted or unpushed work in every repo here, and drift of the shared files (`.gitattributes`,
`.vscode/settings.json`, `kansasii_paths.py`, `.gitignore` lines) and of the layout (sbatch files only at the root as `submit_*.sbatch`,
no literal project root in code). Layout of every repo: `kansasii-docs/README.md`, section "Repo layout".
