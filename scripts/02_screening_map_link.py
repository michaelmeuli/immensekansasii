#!/usr/bin/env python
"""Build screening_map_link.csv: link project samples to LNR, MHK (AST) and NGS numbers.

Usage (conda activate kansasii_mic):
    python 02_screening_map_link.py [--indir DIR] [--out FILE] [--copy-to DIR]

Sources of truth: screening_map_project.csv and screening_map_strains.csv (agree on TNR).
NGS ids come from screening_map_ngs_jc.csv (reads in kansasii_jc, numeric ids) and
screening_map_ngs_mm.csv (reads in kansasii, Mkan329-NNN). Each source keeps its own
TNR_xx / NGS_xx column pair so an NGS id stays traceable to the TNR it was sequenced under.
TNR_MHK is the TNR the MHK (AST order) was made under (the strains TNR whose LNR is the order's
AUFTRAGSNUMMER). If that LNR is not in strains (case reopened only for the MHK: new LNR, same TNR)
it is the project TNR when BESCHREIBUNG names the follow-up order or the row was verified by hand
in the LIS (LIS_VERIFIED_OWN_TNR), else empty (LNR2 holds the LNR).
MHK_TNR_DIFFERS = "yes" when TNR_MHK is another TNR than TNR: the MHK belongs to a different culture
than the one sequenced under TNR. Informational flag; consumers decide whether to use that MHK (see WORKFLOW.md).
MIC_JC = "JC_<NR_JC>" when one of the row's TNRs is in screening_map_ast_jc.csv (wide MIC table of the
jc-sequenced isolates, NR_JC = its row number). kansasii-mic uses that table only where mic.csv has no
MHK-panel values; for those isolates MHK is set to the same JC_<NR_JC> (replacing an MGIT-only id), so
MIC_JC and MHK of a row never name two different panel sources.
Links are made via
  - LNR (strains) == AUFTRAGSNUMMER (ast)
  - numbers hidden in BESCHREIBUNG (follow-up LNR2 / TNR, e.g. "Resi unter: 3386016 / tbm-2026311083")
  - DATEOFBIRTH as fallback (reopened cases get a new LNR/TNR)
Afterwards the result is compared with screening_map.csv.
"""
from __future__ import annotations

import os
import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))  # kansasii_paths.py sits next to this script

from kansasii_paths import IMM_DIR, MANIFEST_SCRIPT, OUTPUT_ROOT, REPOS  # noqa: E402

# Rows whose follow-up AST order was matched by DOB + received date only (no reference in BESCHREIBUNG).
# Checked by hand in the LIS (M/LAB): after the file was closed the missing information was added
# as "Bleistift", so the order was made under the isolate's own TNR (TNR_MHK = TNR).
LIS_VERIFIED_OWN_TNR = frozenset({"Mkan329-028", "Mkan329-047", "Mkan329-071", "Mkan329-162"})

TNR_RE = re.compile(r"(?<!\d)(20\d{8})(?!\d)")
LNR_RE = re.compile(r"(?<!\d)(\d{7,8})(?!\d)")


def warn(msg: str) -> None:
    print(f"WARNING: {msg}", file=sys.stderr)


def read(path: Path, encoding: str = "utf-8") -> pd.DataFrame:
    df = pd.read_csv(path, dtype=str, encoding=encoding, keep_default_na=False)
    df.columns = [c.strip() for c in df.columns]
    return df.drop(columns=[c for c in df.columns if c == "" or c.startswith("Unnamed")])


def load(indir: Path) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    project = read(indir / "screening_map_project.csv")
    project = project[project["NR"] != ""].reset_index(drop=True)
    strains = read(indir / "screening_map_strains.csv", encoding="latin-1")
    ast = read(indir / "screening_map_ast.csv").drop_duplicates().reset_index(drop=True)
    ngs_jc = read(indir / "screening_map_ngs_jc.csv").drop_duplicates().reset_index(drop=True)
    ngs_mm = read(indir / "screening_map_ngs_mm.csv").drop_duplicates().reset_index(drop=True)
    old = read(indir / "screening_map.csv")

    assert strains["TNR"].is_unique, "TNR not unique in strains"
    missing = set(project["TNR"]) - set(strains["TNR"]) - {""}
    assert not missing, f"project TNR missing in strains: {missing}"
    return project, strains, ast, ngs_jc, ngs_mm, old


def load_mic_jc_tnrs(indir: Path) -> dict[str, str]:
    """TNR -> "JC_<NR_JC>" of screening_map_ast_jc.csv (wide jc MIC table); empty if the file is absent."""
    path = indir / "screening_map_ast_jc.csv"
    if not path.exists():
        return {}
    df = read(path)
    return {t: f"JC_{n}" for t, n in zip(df["TNR"], df["NR_JC"]) if t}


def load_panel_tnrs(indir: Path) -> set[str]:
    """TNRs with MHK-panel values (non-empty MHK column) in mic.csv; empty if the file is absent."""
    path = indir / "mic.csv"
    if not path.exists():
        return set()
    df = pd.read_csv(path, dtype=str, keep_default_na=False)
    return {t.strip() for t in df.loc[df["MHK"].str.strip() != "", "TNR"] if t.strip()}


def parse_beschreibung(text: str, lnr: str) -> tuple[list[str], list[str]]:
    """Return (follow-up TNRs, LNR2 candidates) found in BESCHREIBUNG."""
    tnrs = TNR_RE.findall(text)
    lnrs = [n for n in LNR_RE.findall(text) if n != lnr]
    return tnrs, lnrs


def find_mhk(tnr: str, s: pd.Series[str], ast: pd.DataFrame) -> tuple[str | None, pd.Series[str] | None]:
    """Pick the AST TNR (MHK) for a project TNR by priority tiers; return (MHK, AST row) or (None, None)."""
    besch_tnrs, besch_lnrs = parse_beschreibung(s["BESCHREIBUNG"], s["LNR"])
    other = ast["TNR"] != tnr
    tiers = [
        ("BESCHREIBUNG TNR", ast["TNR"].isin(besch_tnrs)),
        ("LNR2", ast["AUFTRAGSNUMMER"].isin(besch_lnrs)),
        ("LNR", (ast["AUFTRAGSNUMMER"] == s["LNR"]) & other),
        ("DOB+date", (ast["DATEOFBIRTH"] == s["DATEOFBIRTH"]) & (s["DATEOFBIRTH"] != "")
         & (ast["EINGANGSDATUM"] == s["EINGANGSDATUM"]) & other),
        ("self", ~other),
    ]
    for name, mask in tiers:
        hits = ast[mask].sort_values("TNR")
        if hits.empty:
            continue
        if hits["TNR"].nunique() > 1:
            warn(f"TNR {tnr}: several MHK candidates via {name}: {sorted(hits['TNR'].unique())}; "
                 f"using {hits.iloc[0]['TNR']}")
        return hits.iloc[0]["TNR"], hits.iloc[0]
    if besch_tnrs:
        warn(f"TNR {tnr}: BESCHREIBUNG mentions {besch_tnrs} but none found in ast")
    return None, None


def mhk_tnr(tnr: str, s: pd.Series[str], arow: pd.Series[str] | None, lnr_tnrs: dict[str, list[str]]) -> str:
    """TNR the AST order was made under: the strains TNR whose LNR is the order's AUFTRAGSNUMMER.

    If that LNR is not in strains (a case reopened only for the MHK gets a new LNR but keeps its TNR,
    see LNR2), the project TNR is returned when BESCHREIBUNG names the follow-up order (its LNR or its
    TNR). Empty otherwise (order found by DOB + date only). Prefers the project TNR if several strains
    rows share the LNR.
    """
    if arow is None:
        return ""
    cands = lnr_tnrs.get(arow["AUFTRAGSNUMMER"], [])
    if not cands:
        besch_tnrs, besch_lnrs = parse_beschreibung(s["BESCHREIBUNG"], s["LNR"])
        named = arow["AUFTRAGSNUMMER"] in besch_lnrs or arow["TNR"] in besch_tnrs
        return tnr if named else ""
    if tnr in cands:
        return tnr
    if len(cands) > 1:
        warn(f"TNR {tnr}: AST LNR {arow['AUFTRAGSNUMMER']} has several strains TNR {sorted(cands)}; using {min(cands)}")
    return min(cands)


def build(project: pd.DataFrame, strains: pd.DataFrame, ast: pd.DataFrame,
          ngs_sources: dict[str, pd.DataFrame], mic_jc_tnrs: dict[str, str] | None = None,
          panel_tnrs: set[str] | None = None) -> pd.DataFrame:
    S = strains.set_index("TNR")
    lnr_tnrs: dict[str, list[str]] = {str(k): v for k, v in strains.groupby("LNR")["TNR"].apply(list).items()}
    rows: list[dict[str, Any]] = []
    for _, p in project.iterrows():
        r = {"NR": p["NR"], "PROBENNUMMER": p["PROBENNUMMER"], "LNR": "", "LNR2": "",
             "TNR": p["TNR"], "extra": [], "TNR_MHK": "", "MHK": "", "MHK_TNR_DIFFERS": "", "MIC_JC": "",
             "LABEL": p["LABEL"]}
        for src in ngs_sources:
            r[f"TNR_{src}"] = ""
            r[f"NGS_{src}"] = ""
        if p["TNR"]:
            s = S.loc[p["TNR"]]
            s = s.copy()
            s["TNR"] = p["TNR"]
            r["LNR"] = s["LNR"]
            mhk, arow = find_mhk(p["TNR"], s, ast)
            if mhk:
                r["MHK"] = mhk
                r["TNR_MHK"] = mhk_tnr(p["TNR"], s, arow, lnr_tnrs)
                if not r["TNR_MHK"] and p["PROBENNUMMER"] in LIS_VERIFIED_OWN_TNR:
                    r["TNR_MHK"] = p["TNR"]
                if r["TNR_MHK"] and r["TNR_MHK"] != p["TNR"]:
                    r["MHK_TNR_DIFFERS"] = "yes"
            if arow is not None and arow["AUFTRAGSNUMMER"] != s["LNR"]:
                r["LNR2"] = arow["AUFTRAGSNUMMER"]
            else:
                _, besch_lnrs = parse_beschreibung(s["BESCHREIBUNG"], s["LNR"])
                if besch_lnrs:
                    r["LNR2"] = besch_lnrs[0]
        rows.append(r)

    by_tnr = {r["TNR"]: r for r in rows if r["TNR"]}
    by_probe = {r["PROBENNUMMER"]: r for r in rows}
    for src, ngs in ngs_sources.items():
        for _, n in ngs.iterrows():
            t, nt = n["TNR"], n["NGS TNR"]
            if t in by_tnr:
                target = by_tnr[t]
            elif t == "" and nt in by_probe:
                # no TNR (reference strains): NGS TNR is the PROBENNUMMER
                target = by_probe[nt]
            else:
                # NGS TNR not in project: resolve via DATEOFBIRTH in strains
                if t not in S.index or not S.loc[t, "DATEOFBIRTH"]:
                    warn(f"{src}: NGS TNR {t} ({nt}): not in project and no DATEOFBIRTH in strains; unresolved")
                    continue
                dob = S.loc[t, "DATEOFBIRTH"]
                cands = strains.loc[strains["DATEOFBIRTH"] == dob, "TNR"].tolist()
                hits = [c for c in cands if c in by_tnr]
                if len(hits) != 1:
                    warn(f"{src}: NGS TNR {t} ({nt}): DOB {dob} gives project TNR {hits}; unresolved")
                    continue
                target = by_tnr[hits[0]]
                target["extra"] += [c for c in cands if c not in (t, hits[0]) and c not in target["extra"]]
            if target[f"NGS_{src}"] and target[f"NGS_{src}"] != nt:
                warn(f"TNR {target['TNR']}: NGS_{src} conflict {target[f'NGS_{src}']} vs {nt}")
            target[f"TNR_{src}"] = t
            target[f"NGS_{src}"] = nt

    for r in rows:
        own = {r["TNR"], *(r[f"TNR_{src}"] for src in ngs_sources), *r["extra"]} - {""}
        jc_tnrs = mic_jc_tnrs or {}
        hit = sorted(t for t in own if t in jc_tnrs)
        if hit:
            r["MIC_JC"] = jc_tnrs[hit[0]]
            if not ({r["MHK"], r["TNR_MHK"], *own} - {""}) & (panel_tnrs or set()):
                r["MHK"] = r["MIC_JC"]  # ast_jc is the panel source of this isolate

    n_extra = max(1, max(len(r["extra"]) for r in rows))
    extra_cols = [f"TNR{i + 3}" for i in range(n_extra)]
    for r in rows:
        extra = r.pop("extra")
        for i, c in enumerate(extra_cols):
            r[c] = extra[i] if i < len(extra) else ""
    ngs_cols = [c for src in ngs_sources for c in (f"TNR_{src}", f"NGS_{src}")]
    cols = ["NR", "PROBENNUMMER", "LNR", "LNR2", "TNR", *ngs_cols, *extra_cols, "TNR_MHK", "MHK", "MHK_TNR_DIFFERS", "MIC_JC", "LABEL"]
    return pd.DataFrame(rows)[cols]


def compare(link: pd.DataFrame, old: pd.DataFrame) -> None:
    print("\n=== Comparison with screening_map.csv ===")
    m = old.rename(columns={"NGS": "NGS_old"}).merge(link, on="NR", how="outer", suffixes=("_old", ""), indicator=True)
    only = m[m["_merge"] != "both"]
    print(f"rows: old {len(old)}, new {len(link)}, unmatched NR: {len(only)}")
    for col in ["PROBENNUMMER", "TNR", "LABEL"]:
        diff = m[(m["_merge"] == "both") & (m[f"{col}_old"] != m[col])]
        print(f"{col}: {'identical' if diff.empty else f'{len(diff)} differences'}")
        if not diff.empty:
            print(diff[["NR", f"{col}_old", col]].to_string(index=False))
    # old NGS is a single column: keep the new value only if it equals one of NGS_JC / NGS_MM
    m["NGS"] = m["NGS_JC"].where(m["NGS_JC"] != "", m["NGS_MM"])
    in_new = (m["NGS_old"] == m["NGS_JC"]) | (m["NGS_old"] == m["NGS_MM"])
    m.loc[(m["NGS_old"] != "") & in_new, "NGS"] = m["NGS_old"]
    for col in ["MHK", "NGS"]:
        both = m[m["_merge"] == "both"]
        conflict = both[(both[f"{col}_old"] != "") & (both[f"{col}_old"] != both[col])]
        added = both[(both[f"{col}_old"] == "") & (both[col] != "")]
        print(f"{col}: old non-empty {(both[f'{col}_old'] != '').sum()}, new non-empty {(both[col] != '').sum()}, "
              f"conflicts/lost {len(conflict)}, added {len(added)}")
        if not conflict.empty:
            print(conflict[["NR", "TNR", f"{col}_old", col]].to_string(index=False))
        if not added.empty:
            print(added[["NR", "TNR", col]].to_string(index=False))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--indir", type=Path, default=IMM_DIR)
    ap.add_argument("--out", type=Path, default=None, help="default: <indir>/screening_map_link.csv")
    ap.add_argument("--copy-to", type=Path, default=None,
                    help="directory to also copy the output to (default: <root>/output, but only when --out is not given)")
    args = ap.parse_args()
    out = args.out or args.indir / "screening_map_link.csv"

    project, strains, ast, ngs_jc, ngs_mm, old = load(args.indir)
    link = build(project, strains, ast, {"JC": ngs_jc, "MM": ngs_mm}, load_mic_jc_tnrs(args.indir), load_panel_tnrs(args.indir))
    link.to_csv(out, index=False)
    print(f"wrote {out} ({len(link)} rows)")
    copy_to = args.copy_to or (None if args.out else OUTPUT_ROOT)
    if copy_to is not None:
        copy_to.mkdir(parents=True, exist_ok=True)
        shutil.copy2(out, copy_to / out.name)
        print(f"copied to {copy_to / out.name}")
        # provenance (see kansasii-docs/docs/PROVENANCE.md); own file name since output/ is shared
        subprocess.run(["bash", str(MANIFEST_SCRIPT), str(copy_to),
                        str(REPOS / "immensekansasii"), "02_screening_map_link.py", str(args.indir)],
                       env={**os.environ, "MANIFEST_NAME": "screening_map_link.MANIFEST.txt"}, check=True)
    compare(link, old)


if __name__ == "__main__":
    main()
