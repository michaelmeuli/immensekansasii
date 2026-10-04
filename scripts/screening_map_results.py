#!/usr/bin/env python3
"""Add pipeline/MLSA results to screening_map_link.csv -> screening_map_results.csv.

screening_map_link.csv (built by screening_map_link.py) stays the input; this
script never modifies it. Added columns:

  species, gtdb_ani, gtdb_af, gtdb_reference
      GTDB-Tk call from the immensekansasii run (species is the epithet only,
      e.g. "kansasii", like the species_mlsa*/species_ref columns). Read per sample from
      <results-dir>/<id>/3_quality/summary/<id>.tab (complete; preferred), else
      from the merged <run>_quality.tsv (--quality; may be stale/partial).
      <id> is the short id (NR) used as fasta name by scripts/run.sh, or
      Mkan329-NNN if not renamed; --id-map resolves it.
  resistance_abricate
      <id>/4_resistance_virulence/01_Abricate/<id>_resistances_summary.tsv
      ("gene (identity%)", 100%-coverage hits only). Empty = no hit or no result.
  resistance_amrfinder
      <id>/4_resistance_virulence/02_AMRfinderplus/<id>.tsv: Element symbol(s)
      joined by "; ", "none" if AMRFinderPlus ran without a hit, empty if no file.
  species_mlsa1, species_mlsa2, species_ref
      hsp65-only species calls of the Sanger data (optional cross-checks; empty
      if the file is missing or the isolate has no hsp65 read / call is NA):
      species_mlsa1  nearest_species, mlsa-kansasii main2 (all reference genomes)
      species_mlsa2  nearest_species, main2_excluded (3 Korean genomes removed)
      species_ref    closest_species, main3 reference alignment, of the isolate's
                     representative hsp65 read (representative_reads.tsv);
                     only if main3 status is "ok" (else empty)
  TNR_MLSA
      TNR(s) of the representative Sanger reads (representative_reads.tsv) of
      that isolate that differ from the row's TNR. Several -> comma-joined.
      Empty if all reads carry the row's TNR or the isolate has no reads.
      (Replaces the need for TNR6, e.g. 2023500268 for Mkan329-183.)

Usage: python scripts/screening_map_results.py  (in immensekansasii) [--results-dir ...] [--id-map ...]
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


def hsp65_calls(path):
    """Return {probennummer: nearest_species} for the hsp65 rows of an isolate_classification.tsv."""
    sc = read_tsv(path)
    sc = sc[sc["locus"] == "hsp65"]
    return dict(zip(sc["probennummer"], sc["nearest_species"]))


def sample_dir_results(sdir, sid):
    """Return (gtdb row dict or None, abricate str, amrfinder str) from one per-sample result dir."""
    gtdb = None
    tab = sdir / "3_quality/summary" / f"{sid}.tab"
    if tab.exists():
        t = read_tsv(tab)
        if len(t):
            gtdb = t.iloc[0].to_dict()
    abr = ""
    f = sdir / "4_resistance_virulence/01_Abricate" / f"{sid}_resistances_summary.tsv"
    if f.exists():
        r = read_tsv(f)
        abr = "; ".join(v for v in r["Resistance"] if v and v != "NA") if "Resistance" in r else ""
    amr = ""
    f = sdir / "4_resistance_virulence/02_AMRfinderplus" / f"{sid}.tsv"
    if f.exists():
        r = read_tsv(f)
        amr = "; ".join(r["Element symbol"]) if len(r) else "none"
    return gtdb, abr, amr


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
    ap.add_argument("--results-dir", type=Path, default=K / "runs/mkan329/assembly/results",
                    help="per-sample result dirs of the immensekansasii run (<id>/3_quality, <id>/4_resistance_virulence)")
    ap.add_argument("--quality", type=Path,
                    default=K / "runs/mkan329/mkan329_transfer_result/mkan329_quality.tsv",
                    help="merged quality table, fallback for samples without a per-sample summary")
    ap.add_argument("--id-map", type=Path, default=None,
                    help="id_map.tsv from run.sh (NR, PROBENNUMMER, original_path); "
                         "default: <data/mkan329_short>/id_map.tsv if present")
    ap.add_argument("--reads", type=Path,
                    default=K / "output/mlsa/main2_sanger_differentiation/representative_reads.tsv")
    ap.add_argument("--mlsa1", type=Path,
                    default=K / "output/mlsa/main2_sanger_differentiation/isolate_classification.tsv")
    ap.add_argument("--mlsa2", type=Path,
                    default=K / "output/mlsa/main2_sanger_differentiation_excluded/isolate_classification.tsv")
    ap.add_argument("--refalign", type=Path,
                    default=K / "output/mlsa/main3_reference_alignment/reference_alignment.tsv")
    ap.add_argument("--copy-to", type=Path, default=K / "output",
                    help="directory to also copy the output to")
    args = ap.parse_args()
    link_path = args.link or args.indir / "screening_map_link.csv"
    out = args.out or args.indir / "screening_map_results.csv"
    id_map_path = args.id_map or K / "data/mkan329_short/id_map.tsv"

    link = read_tsv(link_path, ",")
    res = link.copy()
    for c in ("species", "gtdb_ani", "gtdb_af", "gtdb_reference",
              "species_mlsa1", "species_mlsa2", "species_ref", "TNR_MLSA",
              "resistance_abricate", "resistance_amrfinder"):
        res[c] = ""

    # --- GTDB species + resistance from the pipeline run ---
    sample_to_pnr = {}
    if id_map_path.exists():
        m = read_tsv(id_map_path)
        sample_to_pnr = dict(zip(m.iloc[:, 0], m.iloc[:, 1]))
    by_nr = dict(zip(link["NR"], link["PROBENNUMMER"]))
    pnrs = set(link["PROBENNUMMER"])
    cols = {"gtdb_species": "species", "gtdb_fastani_ani": "gtdb_ani",
            "gtdb_fastani_af": "gtdb_af", "gtdb_fastani_reference": "gtdb_reference"}
    idx = res.set_index("PROBENNUMMER").index

    def set_gtdb(sample, row):
        """Write the GTDB columns of `row` to the link row of `sample`; return False if unlinked."""
        pnr = sample_to_pnr.get(sample) or (sample if sample in pnrs else by_nr.get(sample))
        if pnr is None:
            return False
        rows = res.index[idx == pnr]
        for src, dst in cols.items():
            v = row.get(src, "")
            if dst == "species":  # genus-less: "Mycobacterium kansasii" -> "kansasii"
                v = v.split(" ", 1)[-1]
            res.loc[rows, dst] = v
        return True

    # merged quality table first (fallback; may be partial), per-sample dirs override
    if args.quality.exists():
        unmatched = [r["Sample"] for _, r in read_tsv(args.quality).iterrows()
                     if not r["Sample"].startswith("analysed_samples") and not set_gtdb(r["Sample"], r)]
        if unmatched:
            warn(f"{len(unmatched)} quality.tsv samples not linked to a PROBENNUMMER: {unmatched[:5]}...")
    else:
        warn(f"{args.quality} not found")
    if args.results_dir.is_dir():
        unmatched = []
        for sdir in sorted(d for d in args.results_dir.iterdir() if d.is_dir()):
            gtdb, abr, amr = sample_dir_results(sdir, sdir.name)
            pnr = sample_to_pnr.get(sdir.name) or (sdir.name if sdir.name in pnrs else by_nr.get(sdir.name))
            if pnr is None:
                unmatched.append(sdir.name)
                continue
            if gtdb:
                set_gtdb(sdir.name, gtdb)
            rows = res.index[idx == pnr]
            res.loc[rows, "resistance_abricate"] = abr
            res.loc[rows, "resistance_amrfinder"] = amr
        if unmatched:
            warn(f"{len(unmatched)} result dirs not linked to a PROBENNUMMER: {unmatched[:5]}...")
    else:
        warn(f"{args.results_dir} not found; resistance columns left empty")

    # --- hsp65 species calls: main2 (mlsa1), main2_excluded (mlsa2) ---
    for col, path in (("species_mlsa1", args.mlsa1), ("species_mlsa2", args.mlsa2)):
        if path.exists():
            calls = hsp65_calls(path)
            res[col] = res["PROBENNUMMER"].map(lambda p: calls.get(p, ""))
        else:
            warn(f"{path} not found; {col} left empty")

    # --- species_ref: main3 call for the representative hsp65 read ---
    if args.refalign.exists() and args.reads.exists():
        reads = read_tsv(args.reads)
        reads = reads[reads["locus"] == "hsp65"]
        rep = dict(zip(reads["probennummer"], reads["read"]))
        ra = read_tsv(args.refalign)
        closest = {}
        for name, sp, st in zip(ra["read"], ra["closest_species"], ra["status"]):
            if st != "ok":  # ambiguous / divergent / no_hit: no reliable call
                sp = ""
            closest[name] = sp
            closest.setdefault(Path(name).stem, sp)
        missing = [p for p, r in rep.items() if r not in closest and Path(r).stem not in closest]
        if missing:
            warn(f"{len(missing)} representative hsp65 reads not in {args.refalign.name}: {missing[:5]}...")
        res["species_ref"] = res["PROBENNUMMER"].map(
            lambda p: closest.get(rep.get(p, ""), closest.get(Path(rep.get(p, "")).stem, "")) if p in rep else "")
    else:
        warn(f"{args.refalign} or {args.reads} not found; species_ref left empty")

    # --- TNR_MLSA ---
    if args.reads.exists():
        res["TNR_MLSA"] = res["PROBENNUMMER"].map(tnr_mlsa(link, args.reads))
    else:
        warn(f"{args.reads} not found; TNR_MLSA left empty")

    res.to_csv(out, index=False)
    print(f"wrote {out} ({len(res)} rows): {(res['species'] != '').sum()} with species, "
          f"{(res['resistance_abricate'] != '').sum()}/{(res['resistance_amrfinder'] != '').sum()} "
          f"with resistance_abricate/amrfinder, "
          f"{(res['TNR_MLSA'] != '').sum()} with TNR_MLSA, "
          f"{(res['species_mlsa1'] != '').sum()}/{(res['species_mlsa2'] != '').sum()}/"
          f"{(res['species_ref'] != '').sum()} with species_mlsa1/mlsa2/ref")
    args.copy_to.mkdir(parents=True, exist_ok=True)
    shutil.copy2(out, args.copy_to / out.name)
    print(f"copied to {args.copy_to / out.name}")


if __name__ == "__main__":
    main()
