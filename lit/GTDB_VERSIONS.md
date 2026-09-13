Short answer: gtdbtk_r226 is a real, intended label (GTDB release R226), but the directory doesn't actually contain R226 data — it contains leftover data from a much older release, r207_v2. My earlier fix made GTDB-Tk run, but not against the right database.

How GTDB/GTDB-Tk versioning works:
- GTDB (Genome Taxonomy Database) publishes numbered taxonomy releases — R202, R207, R214, R220, R226, R232, etc. Each is a full re-classification of all reference genomes against updated phylogenomics.
- A _v2 suffix (as in r207_v2) means a bugfix re-release of the same taxonomy version — not a new release.
- GTDB-Tk (the software) ships reference-data "packages" matched to a specific GTDB release, and the package format itself has changed across GTDB-Tk versions — so the software version and the database release both need to line up.

What I actually found on disk (/shares/sander.imm.uzh/software/pipelines/IMMense/IMMense_dependencies/databases/):

┌───────────────────┬────────────────────────────┬─────────────────────────┐
│                   │        gtdbtk_r226         │       gtdbtk_r232       │
├───────────────────┼────────────────────────────┼─────────────────────────┤
│ Directory created │ 2026-08-24                 │ 2026-08-26              │
├───────────────────┼────────────────────────────┼─────────────────────────┤
│ Tarball inside    │ gtdbtk_r207_v2_data.tar.gz │ gtdbtk_r232_data.tar.gz │
├───────────────────┼────────────────────────────┼─────────────────────────┤
│ Tarball date      │ 2022-05-10                 │ 2026-04-14              │
├───────────────────┼────────────────────────────┼─────────────────────────┤
│ Extracted folder  │ release207_v2              │ release232              │
├───────────────────┼────────────────────────────┼─────────────────────────┤
│ Extracted date    │ 2022-05-09                 │ 2026-04-02              │
└───────────────────┴────────────────────────────┴─────────────────────────┘

gtdbtk_r232 is internally consistent — its name matches its contents, and the dates (Apr 2026) look like a genuine, recent GTDB R232 download. gtdbtk_r226, despite its name, holds a tarball and extracted folder that are both literally named and dated as r207_v2 — the old 2022 package, four GTDB releases behind.

Confirmation this is a real gap, not just an odd name: the sibling conf/profiles/imm.config (the lab's other cluster profile) independently sets:
gtdb_db = "/mnt/nfs/ngs/share/software/pipelines/IMMense_dependencies/gtdb/release_r226"
So "R226" is genuinely the release this pipeline is supposed to use — it's just that on the S3IT filesystem, whatever process created gtdbtk_r226 (as part of an Aug 24–26 reorg, by the looks of it) never actually populated it with real R226 data; it's sitting on stale r207_v2 leftovers instead.

Practical implications of the fix I made:
1. It stops gtdbtk_classify_wf from crashing on "missing/corrupted reference data" (it was previously pointed at the un-extracted parent dir).
2. But results will reflect GTDB R207_v2 taxonomy (2022), not R226 — four releases and roughly 4 years of taxonomic revisions out of date.
3. There's also a version-compatibility risk: the pipeline runs GTDB-Tk 2.5.2 (a current release, per modules/gtdbtk.nf), and pairing a modern GTDB-Tk binary with a 2022-era reference package is a combination GTDB-Tk doesn't officially support — it may still work (the release207_v2 folder does have the expected substructure), or it may produce warnings/errors or classifications that don't match what a properly paired R226 database would give.

My recommendation: treat this as "unblocked, not correct." Before trusting any GTDB-Tk classification from this branch, someone should actually download real R226 reference data into gtdbtk_r226 (mirroring whatever real data lives at the imm.config path .../gtdb/release_r226), then repoint gtdb_db at that. I didn't do that myself since it's a multi-hundred-GB download and a data-provisioning decision, not a code fix — want me to look into what that would take (e.g., check if imm.config's path is reachable from S3IT, or find the official GTDB-Tk R226 download URL)?