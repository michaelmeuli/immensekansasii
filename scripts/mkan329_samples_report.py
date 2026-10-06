#!/usr/bin/env python3
"""Write SAMPLES.md: a per-isolate report of the Mkan329 run.

Reads the per-sample summary tables written by the pipeline
(<results>/<Mkan329-NNN>/3_quality/summary/<Mkan329-NNN>.tab) and the
screening map (data/imm/screening_map_link.csv). It does NOT use
<run>_quality.tsv: that table only covers the samples of the latest
invocation of the run dir, the per-sample tables cover every sample ever run.

The flags are heuristics of this report, not the pipeline's QC (the rules file
in QC_bacteria/rules.csv fails the total length of every kansasii isolate).

Usage: python3 scripts/mkan329_samples_report.py [--results DIR] [--link CSV] [--out FILE]
Standard library only, no conda env needed.
"""
from __future__ import annotations

import argparse
import csv
import datetime
import glob
import os
from collections import Counter
from typing import TypedDict

K = "/shares/sander.imm.uzh/MM/kansasii"
COMPLEX = {"kansasii", "persicum", "pseudokansasii", "innocens", "attenuatum", "ostraviense", "gastri"}
# GTDB merged M. ulcerans into M. marinum; MetaPhlAn writes Mycobacteroides_abscessus
ALIAS = {"ulcerans": "marinum"}

# flag thresholds
MAX_CONTAM = 5.0        # CheckM contamination %
MIN_PURITY = 95.0       # MetaPhlAn4 purity %
MIN_AF = 0.90           # GTDB fastANI alignment fraction
MIN_ANI = 98.0
LEN_RANGE = (5.5e6, 7.5e6)   # kansasii complex isolates only
MAX_CONTIGS = 600
MIN_DEPTH = 50.0


class SampleInfo(TypedDict):
    sp: str
    ep: str
    control: bool
    flags: list[str]
    label: str
    tnr: str


def num(x: str | None) -> float | None:
    if x is None:
        return None
    try:
        return float(x)
    except ValueError:
        return None


def epithet(species: str) -> str:
    return species.replace("_", " ").split()[-1].lower() if species else ""


def read_tab(path: str) -> dict[str, str]:
    with open(path) as fh:
        rows = list(csv.reader(fh, delimiter="\t"))
    return {k: v.strip() for k, v in zip(rows[0], rows[1])}


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--results", default=f"{K}/runs/mkan329/assembly/results")
    ap.add_argument("--link", default=f"{K}/data/imm/screening_map_link.csv")
    ap.add_argument("--out", default=f"{K}/repos/immensekansasii/SAMPLES.md")
    args = ap.parse_args()

    with open(args.link) as fh:
        link: dict[str, dict[str, str]] = {r["PROBENNUMMER"]: r for r in csv.DictReader(fh)}
    samples: dict[str, dict[str, str]] = {}
    for f in sorted(glob.glob(f"{args.results}/Mkan329-*/3_quality/summary/Mkan329-*.tab")):
        r = read_tab(f)
        samples[r["Sample"]] = r

    def nr(sid: str) -> int:
        return int(link[sid]["NR"]) if sid in link else 10**6

    order = sorted(samples, key=nr)
    info: dict[str, SampleInfo] = {}
    for sid in order:
        r, l = samples[sid], link.get(sid, {})
        sp = r["gtdb_species"].replace("Mycobacterium ", "M. ")
        ep = epithet(r["gtdb_species"])
        control = bool(l.get("LABEL"))
        flags: list[str] = []
        if (num(r["checkm_contamination"]) or 0) > MAX_CONTAM:
            flags.append("contamination")
        if (num(r["MetaPhlAn4_purity"]) or 100) < MIN_PURITY:
            flags.append("low purity")
        mp = epithet(r["MetaPhlAn4_species"])
        if mp and mp != ALIAS.get(ep, ep):
            flags.append("MetaPhlAn differs")
        if (num(r["gtdb_fastani_af"]) or 1) < MIN_AF or (num(r["gtdb_fastani_ani"]) or 100) < MIN_ANI:
            flags.append("weak GTDB match")
        if not control and ep in COMPLEX and not LEN_RANGE[0] <= (num(r["Total_length"]) or 0) <= LEN_RANGE[1]:
            flags.append("genome size")
        if (num(r["Contig_count"]) or 0) > MAX_CONTIGS:
            flags.append("fragmented")
        if (num(r["Depth_mean"]) or 999) < MIN_DEPTH:
            flags.append("low depth")
        info[sid] = SampleInfo(sp=sp, ep=ep, control=control, flags=flags, label=l.get("LABEL", ""), tnr=l.get("TNR", ""))

    isolates = [s for s in order if not info[s]["control"]]
    controls = [s for s in order if info[s]["control"]]
    delivered = set(link)
    missing = sorted((int(link[p]["NR"]), p) for p in delivered - set(samples))

    def ranges(nums: list[int]) -> str:
        out: list[tuple[int, int]] = []
        start: int | None = None
        prev: int | None = None
        for n in nums:
            if start is None:
                start = prev = n
            elif prev is not None and n == prev + 1:
                prev = n
            else:
                assert start is not None and prev is not None
                out.append((start, prev)); start = prev = n
        if start is not None and prev is not None:
            out.append((start, prev))
        return ", ".join(str(a) if a == b else f"{a}-{b}" for a, b in out)

    L: list[str] = []
    w = L.append
    w("# Mkan329 samples report\n")
    w(f"Generated {datetime.date.today()} by `scripts/mkan329_samples_report.py` from the per-sample")
    w(f"summary tables in `{args.results}/` and `data/imm/screening_map_link.csv`. Regenerate it after")
    w("every run or delivery; do not edit by hand.\n")
    w("## Coverage\n")
    w(f"- Screening map: {len(link)} isolates (NR 1-{max(int(r['NR']) for r in link.values())}); "
      f"**{len(samples)} have results** ({len(isolates)} clinical isolates + {len(controls)} reference strains).")
    w(f"- Without results ({len(missing)}): NR {ranges([n for n, _ in missing])}"
      " (not delivered yet, or no complete read pair).\n")

    w("## Species (GTDB-Tk, clinical isolates)\n")
    w("| Species | Isolates |\n|---|---|")
    for s, n in Counter(info[i]["sp"] for i in isolates).most_common():
        w(f"| {s} | {n} |")
    w(f"| **Total** | **{len(isolates)}** |\n")

    w("## Reference strains (controls)\n")
    w("| NR | Sample | Expected (screening map) | GTDB-Tk | ANI | Result |\n|---|---|---|---|---|---|")
    for sid in controls:
        i, r = info[sid], samples[sid]
        exp = i["label"].split("(")[0].replace("M. ", "").strip().split()[0]
        ok = ALIAS.get(exp, exp) == i["ep"]
        res = "match" if exp == i["ep"] else (f"match ({exp} is {i['ep']} in GTDB)" if ok else "**MISMATCH**")
        w(f"| {link[sid]['NR']} | {sid} | {i['label']} | {i['sp']} | {r['gtdb_fastani_ani']} | {res} |")
    w("")

    flagged = [s for s in order if info[s]["flags"] and not (info[s]["control"] and info[s]["flags"] == ["genome size"])]
    w("## Isolates to review\n")
    w("Heuristic flags of this report (thresholds below), not the pipeline QC.\n")
    w("| NR | Sample | Species (GTDB) | Flags | CheckM contam. % | MetaPhlAn4 (purity %) | Length Mb | Contigs |\n|---|---|---|---|---|---|---|---|")
    for sid in flagged:
        r, i = samples[sid], info[sid]
        purity = num(r["MetaPhlAn4_purity"])
        w(f"| {link[sid]['NR']} | {sid} | {i['sp']} | {', '.join(i['flags'])} | {r['checkm_contamination']} | "
          f"{r['MetaPhlAn4_species'].replace('_', ' ')} ({purity and round(purity, 1)}) | "
          f"{float(r['Total_length']) / 1e6:.2f} | {r['Contig_count']} |")
    w("")
    w(f"Thresholds: CheckM contamination > {MAX_CONTAM:g} %, MetaPhlAn4 purity < {MIN_PURITY:g} %, "
      f"MetaPhlAn4 species differs from GTDB, GTDB alignment fraction < {MIN_AF:g} or ANI < {MIN_ANI:g}, "
      f"kansasii-complex genome outside {LEN_RANGE[0] / 1e6:g}-{LEN_RANGE[1] / 1e6:g} Mb, "
      f"more than {MAX_CONTIGS} contigs, mean depth < {MIN_DEPTH:g}x.\n")

    w("## All samples\n")
    w("| NR | Sample | TNR | Species (GTDB) | ANI | AF | MetaPhlAn4 | MLST ST | Length Mb | Contigs | N50 kb | Depth | CheckM compl./contam. | Flags |")
    w("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for sid in order:
        r, i = samples[sid], info[sid]
        name = i["sp"] + (" (control)" if i["control"] else "")
        w(f"| {link[sid]['NR']} | {sid} | {i['tnr']} | {name} | {r['gtdb_fastani_ani']} | {r['gtdb_fastani_af']} | "
          f"{r['MetaPhlAn4_species'].replace('Mycobacterium_', 'M. ').replace('_', ' ')} | {r['MLST_sequence_type']} | "
          f"{float(r['Total_length']) / 1e6:.2f} | {r['Contig_count']} | {float(r['N50']) / 1e3:.0f} | "
          f"{float(r['Depth_mean']):.0f} | {r['checkm_completeness']}/{r['checkm_contamination']} | {', '.join(i['flags'])} |")
    w("")

    w("## Caveats\n")
    w("- Species is the GTDB-Tk call (ANI to the GTDB representative). MetaPhlAn4 is a cross-check; its database"
      " has no *M. innocens*, so such isolates show up as *M. kansasii*.")
    w("- `rMLST_best_species` is `species` for every sample (the rMLST step returns no usable result); it is not"
      " reported here. The 16S call is also not reported: it cannot separate the kansasii complex.")
    w("- MLST ST `-` means no sequence type was assigned.")
    w("- The pipeline's own QC (`<run>_quality_QC.csv`) marks the total length of every isolate as FAIL (threshold"
      " not suited to this group), so it is not used for the flags above.")
    w("- A mixed culture or contamination makes the GTDB call unreliable; check the flagged isolates before using"
      " their species or SNP tree position.")

    with open(args.out, "w") as fh:
        fh.write("\n".join(L) + "\n")
    print(f"wrote {args.out}: {len(samples)} samples, {len(flagged)} flagged, {len(missing)} without results")


if __name__ == "__main__":
    main()
