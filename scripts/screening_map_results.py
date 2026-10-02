#!/usr/bin/env python3
"""Add pipeline/MLSA results to screening_map_link.csv -> screening_map_results.csv.

screening_map_link.csv (built by screening_map_link.py) stays the input; this
script never modifies it. Added columns:

  species, gtdb_ani, gtdb_af, gtdb_reference
      GTDB-Tk call from the immensekansasii run's <run>_quality.tsv
      (gtdb_species, gtdb_fastani_ani/af/reference). 5_typing holds no species.
      The quality table's Sample is the short id (NR) used as fasta name by
      scripts/run.sh, or Mkan329-NNN if not renamed; --id-map resolves it.
  species_sanger
      nearest_species from mlsa-kansasii isolate_classification.tsv (optional
      cross-check; empty if the file is missing). Multiple loci -> joined by "/"
      when they disagree.
  TNR_MLSA
      TNR(s) of the representative Sanger reads (representative_reads.tsv) of
      that isolate that differ from the row's TNR. Several -> comma-joined.
      Empty if all reads carry the row's TNR or the isolate has no reads.
      (Replaces the need for TNR6, e.g. 2023500268 for Mkan329-183.)

Usage: python scripts/screening_map_results.py  (in immensekansasii) [--quality ...] [--id-map ...]
"""
import argparse
import shutil
import sys
from pathlib import Path

import pandas as pd

K = Path("/shares/sander.imm.uzh/MM/kansasii")
TNR_COLS_RE = r"^TNR(_NGS|[0-9]+)?$"


def warn(msg):
    print(f"WARNING: {msg}", file=sys.stderr)


def read_tsv(path, sep="\t"):
    return pd.read_csv(path, sep=sep, dtype=str, keep_default_na=False)


def tnr_mlsa(link, reads_path):
    """Return {PROBENNUMMER: 'tnr1,tnr2'} for read TNRs differing from row TNR."""
    reads = read_tsv(reads_path)
    # isolate_classification-style comma-joined TNRs are split defensively
    by_pnr = {}
    for pnr, tnr in zip(reads["probennummer"], reads["TNR"]):
        by_pnr.setdefault(pnr, set()).update(t for t in tnr.split(",") if t)
    out = {}
    for _, r in link.iterrows():
        diff = sorted(by_pnr.get(r["PROBENNUMMER"], set()) - {r["TNR"]})
        out[r["PROBENNUMMER"]] = ",".join(diff)
    # a TNR_MLSA value already assigned to another isolate would be ambiguous
    owner = {}
    tnr_cols = [c for c in link.columns if pd.Series([c]).str.match(TNR_COLS_RE)[0]]
    for _, r in link.iterrows():
        for c in tnr_cols:
            if r[c]:
                owner.setdefault(r[c], set()).add(r["PROBENNUMMER"])
    for pnr, v in out.items():
        for t in filter(None, v.split(",")):
            others = owner.get(t, set()) - {pnr}
            if others:
                warn(f"{pnr}: TNR_MLSA {t} is also a TNR of {sorted(others)}")
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--indir", type=Path, default=K / "data/imm")
    ap.add_argument("--link", type=Path, default=None, help="default: <indir>/screening_map_link.csv")
    ap.add_argument("--out", type=Path, default=None, help="default: <indir>/screening_map_results.csv")
    ap.add_argument("--quality", type=Path,
                    default=K / "output/mkan329/mkan329_transfer_result/mkan329_quality.tsv")
    ap.add_argument("--id-map", type=Path, default=None,
                    help="id_map.tsv from run.sh (NR, PROBENNUMMER, original_path); "
                         "default: <data/mkan329_short>/id_map.tsv if present")
    ap.add_argument("--reads", type=Path,
                    default=K / "output/mlsa/main2_sanger_differentiation/representative_reads.tsv")
    ap.add_argument("--sanger-class", type=Path,
                    default=K / "output/mlsa/main2_sanger_differentiation/isolate_classification.tsv")
    ap.add_argument("--copy-to", type=Path, default=K / "output/mlsa",
                    help="directory to also copy the output to")
    args = ap.parse_args()
    link_path = args.link or args.indir / "screening_map_link.csv"
    out = args.out or args.indir / "screening_map_results.csv"
    id_map_path = args.id_map or K / "data/mkan329_short/id_map.tsv"

    link = read_tsv(link_path, ",")
    res = link.copy()
    for c in ("species", "gtdb_ani", "gtdb_af", "gtdb_reference", "species_sanger", "TNR_MLSA"):
        res[c] = ""

    # --- GTDB species from the pipeline run ---
    if args.quality.exists():
        q = read_tsv(args.quality)
        sample_to_pnr = {}
        if id_map_path.exists():
            m = read_tsv(id_map_path)
            sample_to_pnr = dict(zip(m.iloc[:, 0], m.iloc[:, 1]))
        by_nr = dict(zip(link["NR"], link["PROBENNUMMER"]))
        pnrs = set(link["PROBENNUMMER"])
        cols = {"gtdb_species": "species", "gtdb_fastani_ani": "gtdb_ani",
                "gtdb_fastani_af": "gtdb_af", "gtdb_fastani_reference": "gtdb_reference"}
        idx = res.set_index("PROBENNUMMER").index
        unmatched = []
        for _, r in q.iterrows():
            s = r["Sample"]
            pnr = sample_to_pnr.get(s) or (s if s in pnrs else by_nr.get(s))
            if pnr is None:
                unmatched.append(s)
                continue
            rows = res.index[idx == pnr]
            for src, dst in cols.items():
                res.loc[rows, dst] = r.get(src, "")
        if unmatched:
            warn(f"{len(unmatched)} quality.tsv samples not linked to a PROBENNUMMER: {unmatched[:5]}...")
    else:
        warn(f"{args.quality} not found; species columns left empty")

    # --- Sanger species cross-check ---
    if args.sanger_class.exists():
        sc = read_tsv(args.sanger_class)
        sc = sc[sc["locus"].str.contains("hsp65|16S", regex=True)]
        calls = {}
        for pnr, sp in zip(sc["probennummer"], sc["nearest_species"]):
            calls.setdefault(pnr, [])
            if sp not in calls[pnr]:
                calls[pnr].append(sp)
        res["species_sanger"] = res["PROBENNUMMER"].map(lambda p: "/".join(calls.get(p, [])))
    else:
        warn(f"{args.sanger_class} not found; species_sanger left empty")

    # --- TNR_MLSA ---
    if args.reads.exists():
        res["TNR_MLSA"] = res["PROBENNUMMER"].map(tnr_mlsa(link, args.reads))
    else:
        warn(f"{args.reads} not found; TNR_MLSA left empty")

    res.to_csv(out, index=False)
    print(f"wrote {out} ({len(res)} rows): {(res['species'] != '').sum()} with species, "
          f"{(res['TNR_MLSA'] != '').sum()} with TNR_MLSA")
    args.copy_to.mkdir(parents=True, exist_ok=True)
    shutil.copy2(out, args.copy_to / out.name)
    print(f"copied to {args.copy_to / out.name}")


if __name__ == "__main__":
    main()
