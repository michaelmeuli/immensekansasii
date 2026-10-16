# kansasii repos

| Repo | Purpose |
|---|---|
| `immensekansasii` | IMMENSE pipeline (Nextflow, branch `kansasii`) and the project scripts that link, run and summarise it |
| `kansasii-mic` | MIC outlier analysis (MHK broth microdilution and MGIT) |
| `mlsa-kansasii` | species-complex differentiation by MLSA / Sanger / reference alignment |
| `kansasii-gwas` | genotype vs MIC (candidate genes, hotspots, lineages, recombination) |
| `hsp65-refalign` | check that main3 reference alignment of the Sanger hsp65 reads gives the genome species per isolate |
| `kansasii-arm` | literature AMR-marker screen on assemblies and reads |
| `kansasii-mst` | core-SNP minimum spanning tree figures (complex, kansasii, pseudokansasii, persicum) |
| `sanger-microsynth` | routine: fetch Microsynth Sanger results by mail, identify, report |
| `kansasii-lit` | exploratory GTDB / type-strain look-ups (not part of the run order) |

**Run order:** `immensekansasii/WORKFLOW.md`, section "Run order". Scripts carry the number of their
step (`01_...`, `02_...`), so within one repo they sort in the order they are called.

After the IMMENSE pipeline runs (days, step 5b) everything else is one dependency chain:

```bash
bash immensekansasii/scripts/run_downstream.sh --dry-run    # print the sbatch commands
bash immensekansasii/scripts/run_downstream.sh [--with-bam] # link table -> MIC -> MLSA -> results table -> gwas, arm
```

`check_sync.sh` reports uncommitted or unpushed work in every repo here.
