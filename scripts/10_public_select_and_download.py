#!/usr/bin/env python
"""Select and download the reads of public BioProjects for the IMMENSE pipeline.

Reads <public_dir>/<BioProject>/metadata.tsv (09_public_fetch_metadata.sh) and writes
  selected.tsv      one row per pipeline sample: sample_id, runs, biosample, species as
                    submitted, strain, country, host, date, overlap flag, read paths
  not_runnable.tsv  runs that the fq_PE input cannot take (not Illumina / not PAIRED /
                    no _1 + _2 fastq), with the reason
  reads/<sample_id>_R1.fastq.gz, _R2.fastq.gz   (unless --no-download)

Nothing is filtered on species or host: the projects are about M. kansasii, so every
run goes into the pipeline and GTDB-Tk sorts out the species afterwards. A BioSample
that occurs in more than one of the given projects is kept in each and flagged in the
`overlap` column (deduplicate downstream). Runs of the same BioSample within a project
are concatenated; the sample id is the lowest run accession of that BioSample (never a
bare number: checkm.nf greps the sample id in the CheckM log).

Downloads use curl (resumable) and are verified against the ENA md5. Existing,
verified reads are skipped. This can be hundreds of GB: run it with sbatch, not on
the login node.

Usage: 10_public_select_and_download.py [-o public_dir] [-j jobs] [--no-download] BioProject [BioProject ...]
"""
import argparse
import csv
import hashlib
import subprocess
import sys
import time
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))  # kansasii_paths.py sits next to this script

from kansasii_paths import PUBLIC_READS  # noqa: E402

Row = dict[str, Any]
SELECTED_COLS = ["sample_id", "bioproject", "runs", "biosample", "scientific_name", "strain", "isolate",
                 "country", "host", "collection_date", "platform", "instrument_model", "read_count", "base_count",
                 "overlap", "R1", "R2"]
NOT_RUNNABLE_COLS = ["run_accession", "bioproject", "biosample", "scientific_name", "platform", "layout", "reason"]


def md5(path: Path) -> str:
    h = hashlib.md5()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def pair_files(row: Row) -> "tuple[tuple[str, str], tuple[str, str]] | None":
    """((url1, md5_1), (url2, md5_2)) from fastq_ftp/fastq_md5, or None if there is no _1/_2 pair."""
    urls = [u for u in row["fastq_ftp"].split(";") if u]
    sums = [s for s in row["fastq_md5"].split(";") if s]
    if len(urls) != len(sums):
        return None
    by_suffix = {}
    for u, s in zip(urls, sums):
        for tag in ("_1.fastq.gz", "_2.fastq.gz"):
            if u.endswith(tag):
                by_suffix[tag] = (u, s)
    if len(by_suffix) != 2:
        return None
    return by_suffix["_1.fastq.gz"], by_suffix["_2.fastq.gz"]


def fetch(url: str, want_md5: str, dest: Path) -> None:
    """Download url to dest (resuming), verify md5, leave no partial file under the final name."""
    if dest.exists():  # only ever renamed from .part after the md5 matched
        return
    part = dest.with_name(dest.name + ".part")
    for attempt in range(1, 6):
        # ENA's ftp mirror sometimes answers with an empty reply (curl 52): retry any error, resuming
        proc = subprocess.run(["curl", "-sfL", "-C", "-", "--retry", "3", "--retry-all-errors", "--retry-delay", "5",
                               "-o", str(part), "https://" + url])
        if proc.returncode == 0 and md5(part) == want_md5:
            part.rename(dest)
            return
        if proc.returncode == 0:
            part.unlink(missing_ok=True)  # corrupt: restart from scratch
        time.sleep(10 * attempt)
    raise RuntimeError(f"download or md5 failed after 5 attempts: {url}")


def build_sample(sample: Row, reads_dir: Path) -> str:
    """Download all runs of one sample and place R1/R2; concatenate if several runs."""
    sid = sample["sample_id"]
    out = [reads_dir / f"{sid}_R1.fastq.gz", reads_dir / f"{sid}_R2.fastq.gz"]
    done = reads_dir / f".{sid}.ok"
    if done.exists() and all(p.exists() for p in out):
        return f"{sid}: present"
    parts: "list[list[Path]]" = [[], []]
    for run, files in sample["files"]:
        for i in (0, 1):
            dest = reads_dir / f"{run}_{i + 1}.fastq.gz" if len(sample["files"]) > 1 else out[i]
            fetch(files[i][0], files[i][1], dest)
            parts[i].append(dest)
    if len(sample["files"]) > 1:
        for i in (0, 1):
            with out[i].open("wb") as o:
                for p in parts[i]:
                    o.write(p.read_bytes())
                    p.unlink()
    done.touch()
    return f"{sid}: downloaded ({len(sample['files'])} run(s))"


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("projects", nargs="+")
    ap.add_argument("-o", "--public-dir", type=Path, default=PUBLIC_READS)
    ap.add_argument("-j", "--jobs", type=int, default=4)
    ap.add_argument("--no-download", action="store_true", help="write selected.tsv / not_runnable.tsv only")
    args = ap.parse_args()

    # Pass 1: group runs per project and BioSample
    samples: "dict[str, list[list[Row]]]" = {}
    not_runnable: "dict[str, list[Row]]" = {}
    biosample_projects: "dict[str, set[str]]" = defaultdict(set)
    for proj in args.projects:
        meta = args.public_dir / proj / "metadata.tsv"
        if not meta.exists():
            sys.exit(f"ERROR: {meta} missing, run 09_public_fetch_metadata.sh first")
        by_bs: "dict[str, list[Row]]" = defaultdict(list)
        not_runnable[proj] = []
        with meta.open(encoding="utf-8") as f:
            for row in csv.DictReader(f, delimiter="\t"):
                reason = None
                if row["instrument_platform"] != "ILLUMINA":
                    reason = "not Illumina"
                elif row["library_layout"] != "PAIRED":
                    reason = "not PAIRED"
                elif pair_files(row) is None:
                    reason = "no _1/_2 fastq pair on ENA"
                if reason:
                    not_runnable[proj].append({"run_accession": row["run_accession"], "bioproject": proj,
                                               "biosample": row["sample_accession"],
                                               "scientific_name": row["scientific_name"],
                                               "platform": row["instrument_platform"],
                                               "layout": row["library_layout"], "reason": reason})
                    continue
                by_bs[row["sample_accession"]].append(row)
                biosample_projects[row["sample_accession"]].add(proj)
        samples[proj] = [biosample_rows for _, biosample_rows in sorted(by_bs.items())]

    # Pass 2: write tables, then download
    had_failures = False
    for proj in args.projects:
        proj_ids: "set[str]" = set()
        pdir = args.public_dir / proj
        reads_dir = pdir / "reads"
        sel_rows: list[Row] = []
        jobs: list[Row] = []
        for biosample_rows in samples[proj]:
            rows = sorted(biosample_rows, key=lambda r: r["run_accession"])
            first = rows[0]
            sid = first["run_accession"]
            if sid in proj_ids:
                sys.exit(f"ERROR: duplicate sample id {sid} in {proj}")
            proj_ids.add(sid)
            others = sorted(biosample_projects[first["sample_accession"]] - {proj})
            sel_rows.append({
                "sample_id": sid, "bioproject": proj, "runs": ",".join(r["run_accession"] for r in rows),
                "biosample": first["sample_accession"], "scientific_name": first["scientific_name"],
                "strain": first["strain"], "isolate": first["isolate"], "country": first["country"],
                "host": first["host"], "collection_date": first["collection_date"],
                "platform": first["instrument_platform"], "instrument_model": first["instrument_model"],
                "read_count": sum(int(r["read_count"] or 0) for r in rows),
                "base_count": sum(int(r["base_count"] or 0) for r in rows),
                "overlap": ",".join(others), "R1": reads_dir / f"{sid}_R1.fastq.gz",
                "R2": reads_dir / f"{sid}_R2.fastq.gz"})
            jobs.append({"sample_id": sid, "files": [(r["run_accession"], pair_files(r)) for r in rows]})
        pdir.mkdir(parents=True, exist_ok=True)
        for name, cols, table in (("selected.tsv", SELECTED_COLS, sel_rows),
                                 ("not_runnable.tsv", NOT_RUNNABLE_COLS, not_runnable[proj])):
            with (pdir / name).open("w", newline="", encoding="utf-8") as f:
                w = csv.DictWriter(f, fieldnames=cols, delimiter="\t", lineterminator="\n")
                w.writeheader()
                w.writerows(table)
        n_ov = sum(1 for r in sel_rows if r["overlap"])
        print(f"{proj}: {len(sel_rows)} samples ({n_ov} shared with another given project), "
              f"{len(not_runnable[proj])} runs not runnable -> {pdir}")
        if args.no_download:
            continue
        reads_dir.mkdir(exist_ok=True)
        with ThreadPoolExecutor(args.jobs) as ex:
            futs = [(j["sample_id"], ex.submit(build_sample, j, reads_dir)) for j in jobs]
            failed = []
            for sid, fut in futs:
                try:
                    print(fut.result(), flush=True)
                except Exception as e:  # keep going; rerun finishes the missing samples
                    failed.append(sid)
                    print(f"{sid}: FAILED ({e})", flush=True)
        if failed:
            print(f"{proj}: {len(failed)} samples failed, rerun to retry: {' '.join(failed)}", file=sys.stderr)
            had_failures = True
    if had_failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
