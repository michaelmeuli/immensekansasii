#!/usr/bin/env python3
"""Add pipeline/MLSA results to screening_map_link.csv -> screening_map_results.csv.

screening_map_link.csv (built by 02_screening_map_link.py) stays the input; this
script never modifies it. Added columns:

  NGS_USED  (inserted right after NGS_MM)
      The NGS id whose sequencing data is used for the isolate: NGS_MM if there is one,
      else NGS_JC (i.e. NGS_MM for Mkan329-001..133, NGS_JC for the rest). If NGS_MM was
      done it is the one used, never NGS_JC: Mkan329-009 and -056 have both, and use NGS_MM
      (their resequenced -jc reads, run mkan329_jc, are not used).
  species, gtdb_ani, gtdb_af, gtdb_reference
      GTDB-Tk call from the immensekansasii run (species is the epithet only,
      e.g. "kansasii", like the species_sanger_* columns). Read per sample from
      <results-dir>/<id>/3_quality/summary/<id>.tab (complete; preferred), else
      from the merged <run>_quality.tsv (--quality; may be stale/partial).
      <id> is Mkan329-NNN (PROBENNUMMER); a bare NR or an --id-map are still
      resolved for older runs.
  checkm_contamination, contamination_flag
      CheckM contamination (%) from the same quality table/summary as the GTDB call;
      contamination_flag = "contaminated" if it exceeds --max-contamination
      (default 5), else empty (also empty if no value). Flagged isolates are
      mixed cultures/assemblies (e.g. Mkan329-035: kansasii + ostraviense, 13 Mb),
      so GTDB and hsp65 species calls may legitimately disagree.
  cgmlst_called_pct, excluded  (inserted right after contamination_flag)
      cgmlst_called_pct: % of the cgMLST95 loci with an allele call (kansasii-cgmlst step 07,
      output/cgmlst/sample_qc.tsv; --cgmlst-qc); empty for isolates that are not allele-called
      (contaminated, not in the complex) or if the file is missing.
      excluded: "true"/"false" on every row; true if contamination_flag is "contaminated",
      cgmlst_called_pct < --min-cgmlst-pct (default 90, like Ridom's good-target threshold), or the
      row is a clinical sample (LABEL empty) whose GTDB species is outside the M. kansasii complex
      (e.g. NR 184, M. avium). Non-complex control strains (LABEL set) are not excluded by this.
      The genome-based repos (kansasii-cgmlst, kansasii-mst, kansasii-amr-marker-screen) skip excluded isolates.
      Order: kansasii-cgmlst 07 -> this script -> kansasii-cgmlst 08-10.
  resistance_abricate
      <id>/4_resistance_virulence/01_Abricate/<id>_resistances_summary.tsv
      ("gene (identity%)", 100%-coverage hits only). Empty = no hit or no result.
  resistance_amrfinder
      <id>/4_resistance_virulence/02_AMRfinderplus/<id>.tsv: Element symbol(s)
      joined by "; ", "none" if AMRFinderPlus ran without a hit, empty if no file.
  amr_mut
      Markers called MUT by kansasii-amr-marker-screen (marker_calls.pass.tsv, aa_call == MUT, qc ok),
      "<gene>-<marker>" comma-joined, e.g. "rpsL-K43R,rrs-A514C". Includes non-discriminating
      markers (discriminating = no: the ATCC 12478 reference carries the mutant allele, MUT then
      only means "same as the reference"), so rrs-A514C is in nearly every isolate. Empty = no MUT.
  species_sanger_mlsa, species_sanger_mlsa_excl, species_sanger_refalign
      hsp65-only species calls of the Sanger data (optional cross-checks; empty
      if the file is missing or the isolate has no hsp65 read / call is NA):
      species_sanger_mlsa  nearest_species, mlsa-kansasii sanger_mlsa (all reference genomes)
      species_sanger_mlsa_excl  nearest_species, sanger_mlsa_excluded (3 Korean genomes removed)
      species_sanger_refalign    closest_species, sanger_refalign reference alignment, of the isolate's
                     representative hsp65 read (representative_reads.tsv);
                     only if sanger_refalign status is "ok" (else empty)
  TNR_MLSA
      TNR(s) of the representative Sanger reads (representative_reads.tsv) of
      that isolate that differ from the row's TNR. Several -> comma-joined.
      Empty if all reads carry the row's TNR or the isolate has no reads.
      (Replaces the need for TNR6, e.g. 2023500268 for Mkan329-183.)

  <ABBR>_mic, <ABBR>_modified_z, <ABBR>_clsi_category   (13 antibiotics, see MIC_ABBR)
      Broth microdilution MIC as reported (mhk_raw, e.g. "<=1", "0.12-0.25"), the
      per-antibiotic cohort modified z-score of log2 MIC and the CLSI category
      (S/I/R; empty where no M. kansasii breakpoint exists: EMB, INH, STR, ETO),
      from kansasii-mic outliers_per_antibiotic.csv (--mic-file). Empty if the
      isolate was not tested.

Usage: python scripts/06_screening_map_results.py  (in immensekansasii) [--results-dir ...] [--id-map ...]
"""
from __future__ import annotations

import os
import re
import argparse
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))  # kansasii_paths.py sits next to this script

from kansasii_paths import (ASSEMBLIES, IMM_DIR, MANIFEST_SCRIPT, OUTPUT_ROOT, REPOS, RIDOM_CLUSTERS, RUNS, SPECIES)  # noqa: E402

TNR_COLS_RE = r"^TNR(_JC|_MM|[0-9]+)?$"


# canonical antibiotic name (kansasii_mic loading.py) -> standard abbreviation
MIC_ABBR = {
    "Amikacin": "AMK", "Ciprofloxacin": "CIP", "Clarithromycin": "CLR",
    "Doxycyclin": "DOX", "Ethambutol": "EMB", "Isoniazid": "INH",
    "Linezolid": "LZD", "Moxifloxacin": "MXF", "Rifabutin": "RFB",
    "Rifampicin": "RIF", "Streptomycin": "STR",
    "Sulfamethoxazole/Trimethoprim": "SXT", "Ethionamid": "ETO",
}
MIC_FIELDS = (("mic", "mhk_raw"), ("modified_z", "modified_z"), ("clsi_category", "clsi_category"))


# ridom-clusters.csv column -> screening_map_results column (appended last)
RIDOM_COLS = {"Perc. Good Targets": "ridom_perc_good_targets",
              "Approximated Genome Size (Mbases)": "ridom_genome_size_mb",
              "Species": "ridom_species", "-Group-": "ridom_mst_cluster"}


def ridom_id(pnr: str, label: str) -> str:
    """Sample ID of the Ridom export (kansasii-cgmlst 10_export_ridom.py): Mkan329-081 -> M081, controls -> safe label."""
    if label:
        return re.sub(r"_+", "_", re.sub(r"[^A-Za-z0-9]+", "_", label)).strip("_")
    return pnr.replace("Mkan329-", "M")


COMPLEX = set(SPECIES)  # all 7 species of the complex, gastri included


def is_excluded(contamination_flag: str, cgmlst_called_pct: str, min_pct: float,
                species: str = "", label: str = "") -> bool:
    """Contaminated, a non-complex clinical sample (known species outside COMPLEX, no LABEL), or fewer than min_pct %
    of the cgMLST loci called (an empty percentage never excludes)."""
    if contamination_flag == "contaminated":
        return True
    if species and species not in COMPLEX and not label:
        return True
    try:
        return float(cgmlst_called_pct) < min_pct
    except ValueError:
        return False


def warn(msg: str) -> None:
    print(f"WARNING: {msg}", file=sys.stderr)


def read_tsv(path: Path, sep: str = "\t") -> pd.DataFrame:
    return pd.read_csv(path, sep=sep, dtype=str, keep_default_na=False)


def hsp65_calls(path: Path) -> dict[str, str]:
    """Return {probennummer: nearest_species} for the hsp65 rows of an isolate_classification.tsv."""
    sc = read_tsv(path)
    sc = sc[sc["locus"] == "hsp65"]
    return dict(zip(sc["probennummer"], sc["nearest_species"]))


def amr_mut_calls(path: Path) -> dict[str, str]:
    """Return {PROBENNUMMER: 'gene-marker,gene-marker'} for the aa_call == MUT rows of marker_calls.pass.tsv."""
    found: dict[str, set[str]] = {}
    for r in read_tsv(path).to_dict("records"):
        if r["aa_call"] == "MUT" and r["qc"] == "ok":
            found.setdefault(r["sample"].split("__", 1)[1], set()).add(f"{r['gene']}-{r['marker']}")
    return {pnr: ",".join(sorted(v)) for pnr, v in found.items()}


def sample_dir_results(sdir: Path, sid: str) -> tuple[dict[str, str] | None, str, str]:
    """Return (gtdb row dict or None, abricate str, amrfinder str) from one per-sample result dir."""
    gtdb: dict[str, str] | None = None
    tab = sdir / "3_quality/summary" / f"{sid}.tab"
    if tab.exists():
        t = read_tsv(tab)
        if len(t):
            gtdb = {str(k): str(v) for k, v in t.iloc[0].to_dict().items()}
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


def tnr_mlsa(link: pd.DataFrame, reads_path: Path) -> dict[str, str]:
    """Return {PROBENNUMMER: 'tnr1,tnr2'} for read TNRs differing from row TNR."""
    reads = read_tsv(reads_path)
    # isolate_classification-style comma-joined TNRs are split defensively
    by_pnr: dict[str, set[str]] = {}
    for pnr, tnr in zip(reads["probennummer"], reads["TNR"]):
        by_pnr.setdefault(pnr, set()).update(t for t in tnr.split(",") if t)
    out: dict[str, str] = {}
    for _, r in link.iterrows():
        diff = sorted(by_pnr.get(r["PROBENNUMMER"], set()) - {r["TNR"]})
        out[r["PROBENNUMMER"]] = ",".join(diff)
    # a TNR_MLSA value already assigned to another isolate would be ambiguous
    owner: dict[str, set[str]] = {}
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


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--indir", type=Path, default=IMM_DIR)
    ap.add_argument("--link", type=Path, default=None, help="default: <indir>/screening_map_link.csv")
    ap.add_argument("--out", type=Path, default=None, help="default: <indir>/screening_map_results.csv")
    ap.add_argument("--results-dir", type=Path, default=ASSEMBLIES,
                    help="per-sample result dirs of the immensekansasii run (<id>/3_quality, <id>/4_resistance_virulence)")
    ap.add_argument("--quality", type=Path,
                    default=RUNS / "mkan329/mkan329_transfer_result/mkan329_quality.tsv",
                    help="merged quality table, fallback for samples without a per-sample summary")
    ap.add_argument("--id-map", type=Path, default=None,
                    help="optional id_map.tsv (NR, PROBENNUMMER, ...) for runs whose sample ids are not "
                         "Mkan329-NNN, e.g. data/illumina/Mkan329/batches/b01/id_map.tsv")
    ap.add_argument("--reads", type=Path,
                    default=OUTPUT_ROOT / "mlsa/sanger_mlsa/representative_reads.tsv")
    ap.add_argument("--mlsa1", type=Path,
                    default=OUTPUT_ROOT / "mlsa/sanger_mlsa/isolate_classification.tsv")
    ap.add_argument("--mlsa2", type=Path,
                    default=OUTPUT_ROOT / "mlsa/sanger_mlsa_excluded/isolate_classification.tsv")
    ap.add_argument("--refalign", type=Path,
                    default=OUTPUT_ROOT / "mlsa/sanger_refalign/reference_alignment.tsv")
    ap.add_argument("--mic-file", type=Path,
                    default=OUTPUT_ROOT / "mic/mhk/outliers_per_antibiotic.csv",
                    help="kansasii-mic long table (PROBENNUMMER, antibiotic, mhk_raw, modified_z, clsi_category)")
    ap.add_argument("--amr-calls", type=Path,
                    default=OUTPUT_ROOT / "amr/work/report/marker_calls.pass.tsv",
                    help="kansasii-amr-marker-screen marker_calls.pass.tsv (aa_call == MUT rows -> amr_mut)")
    ap.add_argument("--cgmlst-qc", type=Path, default=OUTPUT_ROOT / "cgmlst/sample_qc.tsv",
                    help="kansasii-cgmlst sample_qc.tsv (sample, cgmlst_called_pct) -> cgmlst_called_pct")
    ap.add_argument("--ridom-clusters", type=Path, default=RIDOM_CLUSTERS,
                    help="Ridom ridom-clusters.csv (Sample ID, ...) -> ridom_* columns, appended last")
    ap.add_argument("--min-cgmlst-pct", type=float, default=90.0,
                    help="isolates with a lower %% of cgMLST loci called get excluded = true (default 90)")
    ap.add_argument("--max-contamination", type=float, default=5.0,
                    help="CheckM contamination %% above which contamination_flag is set (default 5)")
    ap.add_argument("--copy-to", type=Path, default=None,
                    help="directory to also copy the output to (default: <root>/output, but only "
                         "when --out is not given)")
    args = ap.parse_args()
    link_path = args.link or args.indir / "screening_map_link.csv"
    out = args.out or args.indir / "screening_map_results.csv"
    id_map_path = args.id_map
    copy_to = args.copy_to or (None if args.out else OUTPUT_ROOT)

    link = read_tsv(link_path, ",")
    res = link.copy()
    res.insert(list(res.columns).index("NGS_MM") + 1, "NGS_USED",
               res["NGS_MM"].where(res["NGS_MM"] != "", res["NGS_JC"]))
    if (res["NGS_USED"] == "").any():
        warn("no NGS_MM and no NGS_JC: %s" % ", ".join(res.loc[res["NGS_USED"] == "", "PROBENNUMMER"]))
    for c in ("species", "gtdb_ani", "gtdb_af", "gtdb_reference",
              "checkm_contamination", "contamination_flag",
              "species_sanger_mlsa", "species_sanger_mlsa_excl", "species_sanger_refalign", "TNR_MLSA",
              "resistance_abricate", "resistance_amrfinder", "amr_mut"):
        res[c] = ""

    # --- GTDB species + resistance from the pipeline run ---
    sample_to_pnr: dict[str, str] = {}
    if id_map_path is not None and id_map_path.exists():
        m = read_tsv(id_map_path)
        sample_to_pnr = dict(zip(m.iloc[:, 0], m.iloc[:, 1]))
    by_nr = dict(zip(link["NR"], link["PROBENNUMMER"]))
    pnrs = set(link["PROBENNUMMER"])
    cols = {"gtdb_species": "species", "gtdb_fastani_ani": "gtdb_ani",
            "gtdb_fastani_af": "gtdb_af", "gtdb_fastani_reference": "gtdb_reference",
            "checkm_contamination": "checkm_contamination"}
    idx = res.set_index("PROBENNUMMER").index

    def set_gtdb(sample: str, row: pd.Series[Any] | dict[str, str]) -> bool:
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

    # --- kansasii-amr-marker-screen: markers called MUT, "<gene>-<marker>" comma-joined ---
    if args.amr_calls.exists():
        amr = amr_mut_calls(args.amr_calls)
        not_linked = sorted(set(amr) - pnrs)
        if not_linked:
            warn(f"{len(not_linked)} amr_mut samples not in the link table: {not_linked[:5]}...")
        res["amr_mut"] = res["PROBENNUMMER"].map(lambda p: amr.get(p, ""))
    else:
        warn(f"{args.amr_calls} not found; amr_mut left empty")

    def flag(v: str) -> str:
        try:
            return "contaminated" if float(v) > args.max_contamination else ""
        except ValueError:
            return ""
    res["contamination_flag"] = res["checkm_contamination"].map(flag)
    if (res["contamination_flag"] != "").any():
        warn("contaminated (CheckM > %g%%): %s" % (args.max_contamination, ", ".join(
            f"{p} ({c})" for p, c, f in zip(res["PROBENNUMMER"], res["checkm_contamination"], res["contamination_flag"]) if f)))

    # --- cgmlst_called_pct + excluded (contaminated or poor cgMLST coverage) ---
    pct: dict[str, str] = {}
    if args.cgmlst_qc.exists():
        qc = read_tsv(args.cgmlst_qc)
        pct = dict(zip(qc["sample"], qc["cgmlst_called_pct"]))
    else:
        warn(f"{args.cgmlst_qc} not found; cgmlst_called_pct left empty, excluded = contaminated only")
    after = list(res.columns).index("contamination_flag") + 1
    res.insert(after, "cgmlst_called_pct", res["PROBENNUMMER"].map(lambda p: pct.get(p, "")))
    res.insert(after + 1, "excluded", [
        "true" if is_excluded(f, c, args.min_cgmlst_pct, sp, lb) else "false"
        for f, c, sp, lb in zip(res["contamination_flag"], res["cgmlst_called_pct"],
                                res["species"].fillna(""), res["LABEL"].fillna(""))])
    non_complex = res[(res["excluded"] == "true") & (res["contamination_flag"] == "") & ~res["species"].fillna("").isin(COMPLEX)
                      & (res["species"].fillna("") != "")]
    if len(non_complex):
        warn("excluded (clinical sample outside the complex): %s" % ", ".join(
            f"{p} ({sp})" for p, sp in zip(non_complex["PROBENNUMMER"], non_complex["species"])))
    low = res[(res["excluded"] == "true") & (res["contamination_flag"] == "") & ~res.index.isin(non_complex.index)]
    if len(low):
        warn("excluded (< %g%% cgMLST loci called): %s" % (args.min_cgmlst_pct, ", ".join(
            f"{p} ({c})" for p, c in zip(low["PROBENNUMMER"], low["cgmlst_called_pct"]))))

    # --- hsp65 species calls: sanger_mlsa (mlsa1), sanger_mlsa_excluded (mlsa2) ---
    for col, path in (("species_sanger_mlsa", args.mlsa1), ("species_sanger_mlsa_excl", args.mlsa2)):
        if path.exists():
            calls = hsp65_calls(path)
            res[col] = res["PROBENNUMMER"].map(lambda p: calls.get(p, ""))
        else:
            warn(f"{path} not found; {col} left empty")

    # --- species_sanger_refalign: sanger_refalign call for the representative hsp65 read ---
    if args.refalign.exists() and args.reads.exists():
        reads = read_tsv(args.reads)
        reads = reads[reads["locus"] == "hsp65"]
        rep = dict(zip(reads["probennummer"], reads["read"]))
        ra = read_tsv(args.refalign)
        closest: dict[str, str] = {}
        for name, sp, st in zip(ra["read"], ra["closest_species"], ra["status"]):
            if st != "ok":  # ambiguous / divergent / no_hit: no reliable call
                sp = ""
            closest[name] = sp
            closest.setdefault(Path(name).stem, sp)
        missing = [p for p, r in rep.items() if r not in closest and Path(r).stem not in closest]
        if missing:
            warn(f"{len(missing)} representative hsp65 reads not in {args.refalign.name}: {missing[:5]}...")
        res["species_sanger_refalign"] = res["PROBENNUMMER"].map(
            lambda p: closest.get(rep.get(p, ""), closest.get(Path(rep.get(p, "")).stem, "")) if p in rep else "")
    else:
        warn(f"{args.refalign} or {args.reads} not found; species_sanger_refalign left empty")

    # --- TNR_MLSA ---
    if args.reads.exists():
        res["TNR_MLSA"] = res["PROBENNUMMER"].map(tnr_mlsa(link, args.reads))
    else:
        warn(f"{args.reads} not found; TNR_MLSA left empty")

    # --- per-antibiotic MIC, modified_z, clsi_category ---
    mic_cols = [f"{a}_{f}" for a in MIC_ABBR.values() for f, _ in MIC_FIELDS]
    for c in mic_cols:
        res[c] = ""
    if args.mic_file.exists():
        mic = read_tsv(args.mic_file, ",")
        unknown = sorted(set(mic["antibiotic"]) - set(MIC_ABBR))
        if unknown:
            warn(f"antibiotics without abbreviation, skipped: {unknown}")
        mic = mic[mic["antibiotic"].isin(MIC_ABBR)]
        row_of = {p: i for i, p in zip(res.index, res["PROBENNUMMER"])}
        for _, r in mic.iterrows():
            i = row_of.get(r["PROBENNUMMER"])
            if i is None:
                warn(f"MIC row {r['PROBENNUMMER']} not in link table")
                continue
            for f, src in MIC_FIELDS:
                res.at[i, f"{MIC_ABBR[r['antibiotic']]}_{f}"] = r[src]
    else:
        warn(f"{args.mic_file} not found; MIC columns left empty")

    for c in RIDOM_COLS.values():
        res[c] = ""
    if args.ridom_clusters.exists():
        rid = read_tsv(args.ridom_clusters, ",").set_index("Sample ID")
        keys = [ridom_id(p, l) for p, l in zip(res["PROBENNUMMER"], res["LABEL"])]
        hit = [k in rid.index for k in keys]
        for src, dst in RIDOM_COLS.items():
            res[dst] = [rid.at[k, src].strip() if h else "" for k, h in zip(keys, hit)]
        warn(f"ridom: {sum(hit)}/{len(res)} isolates matched; not in screening table: "
             f"{', '.join(sorted(set(rid.index) - set(keys)))}")
    else:
        warn(f"{args.ridom_clusters} not found; ridom columns left empty")

    res.to_csv(out, index=False)
    print(f"{(res[[f'{a}_mic' for a in MIC_ABBR.values()]] != '').any(axis=1).sum()} isolates with MIC data")
    print(f"wrote {out} ({len(res)} rows): {(res['species'] != '').sum()} with species, "
          f"{(res['resistance_abricate'] != '').sum()}/{(res['resistance_amrfinder'] != '').sum()} "
          f"with resistance_abricate/amrfinder, "
          f"{(res['TNR_MLSA'] != '').sum()} with TNR_MLSA, "
          f"{(res['species_sanger_mlsa'] != '').sum()}/{(res['species_sanger_mlsa_excl'] != '').sum()}/"
          f"{(res['species_sanger_refalign'] != '').sum()} with species_sanger_mlsa/mlsa_excl/refalign")
    if copy_to is not None:
        copy_to.mkdir(parents=True, exist_ok=True)
        shutil.copy2(out, copy_to / out.name)
        print(f"copied to {copy_to / out.name}")
        # provenance (see kansasii-docs/docs/PROVENANCE.md); own file name since output/ is shared
        subprocess.run(["bash", str(MANIFEST_SCRIPT), str(copy_to),
                        str(REPOS / "immensekansasii"), "06_screening_map_results.py", str(args.indir)],
                       env={**os.environ, "MANIFEST_NAME": "screening_map_results.MANIFEST.txt"}, check=True)


if __name__ == "__main__":
    main()
