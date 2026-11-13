# GTDB-Tk reference data on the s3it cluster

The pipeline uses **GTDB release R232**: `gtdb_db` in `conf/profiles/s3it.config` is
`/shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/gtdbtk_r232/release232`
(`conf/profiles/imm.config` points to `release_r232` as well).

How GTDB / GTDB-Tk versioning works:
- GTDB (Genome Taxonomy Database) publishes numbered taxonomy releases (R207, R214, R220, R226, R232, ...). Each is a full re-classification of all reference genomes.
- A `_v2` suffix (as in `r207_v2`) is a bugfix re-release of the same taxonomy version, not a new release.
- GTDB-Tk (the software) ships reference-data packages matched to one GTDB release, and the package format differs between GTDB-Tk versions, so the software version and the database release have to match.

On disk (`/shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/`):

|  | `gtdbtk_r232` | `gtdbtk_r226` |
|---|---|---|
| Tarball inside | `gtdbtk_r232_data.tar.gz` | `gtdbtk_r207_v2_data.tar.gz` |
| Extracted folder | `release232` | `release207_v2` |
| Used by the pipeline | yes | no |

**`gtdbtk_r226` does not hold R226 data.** Despite its name it contains the r207_v2 package (2022). Do not point `gtdb_db` at it:
the classifications would follow the R207 taxonomy, and a current GTDB-Tk with a 2022 package is not a supported combination.
