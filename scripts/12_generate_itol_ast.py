#!/usr/bin/env python3
"""iTOL inputs for the patient isolates of the M. kansasii complex: midpoint-rooted tree, AST dots, species ring.

Reads the snippy-core / IQ-TREE tree of mkan329 (tips are PROBENNUMMER, plus the snippy `Reference`) and
screening_map_results.csv, keeps the patient isolates of the complex (no `Reference`, no control / type strains
with a LABEL, no `excluded` isolates, species in the complex) and writes to --out-dir:

  kansasii_patients_midpoint.nwk  pruned tree, rooted at its midpoint
  itol_1_ast_dots.txt             DATASET_BINARY, one circle ring per antibiotic: black (filled) = resistant,
                                  white (hollow) = susceptible or intermediate, no dot = no MIC
  itol_2_species_ring.txt         DATASET_COLORSTRIP of the species (load last: it becomes the outermost ring)
  itol_leaf_labels.txt            LABELS: tip id -> "species [id]"
  MANIFEST.txt

Resistance call per drug: the CLSI category (<DRUG>_clsi_category, R -> resistant, S and I -> white) where
there is one; for the drugs without a CLSI M. kansasii breakpoint (NON_CLSI_THRESHOLDS_MG_L) the MIC in
<DRUG>_mic against the threshold. Upload the .nwk to iTOL, then drag the three dataset files onto it.
"""
from __future__ import annotations

import argparse
import csv
import re
import subprocess
import sys
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parent))
import kansasii_paths as kp  # noqa: E402

# antibiotics in ring order, innermost first
DRUGS = ("AMK", "CIP", "CLR", "DOX", "EMB", "ETO", "INH", "LZD", "MXF", "RFB", "RIF", "STR", "SXT")
# drugs with no CLSI breakpoint for M. kansasii: MIC threshold in mg/L (configurable)
NON_CLSI_THRESHOLDS_MG_L = {"EMB": 8.0, "INH": 8.0, "ETO": 0.6, "STR": 16.0}
# True: resistant if MIC > threshold (MIC == threshold is susceptible); False: resistant if MIC >= threshold
NON_CLSI_RESISTANT_IF_ABOVE = True
COMPLEX_SPECIES = tuple(kp.SPECIES_COLORS)
RESISTANT, SUSCEPTIBLE, NO_DATA = 1, 0, -1
DRUG_SHAPE_CIRCLE = "2"
BLACK = "#000000"

_NUM = r"\d+(?:\.\d+)?"


def _is_resistant(mic: float, threshold: float) -> bool:
    return mic > threshold if NON_CLSI_RESISTANT_IF_ABOVE else mic >= threshold


def call_by_threshold(mic: str, threshold: float) -> int:
    """MIC string (`2`, `2.0`, `<0.5`, `<=0.3`, `>64`, `2-4`) against a threshold -> RESISTANT / SUSCEPTIBLE / NO_DATA.

    A censored or range value gets a call only if every value it can stand for falls on the same side.
    """
    s = mic.strip().replace(" ", "")
    if not s:
        return NO_DATA
    if m := re.fullmatch(rf"({_NUM})", s):
        return RESISTANT if _is_resistant(float(m[1]), threshold) else SUSCEPTIBLE
    if m := re.fullmatch(rf">=?({_NUM})", s):  # true MIC is above (or at) the bound
        return RESISTANT if _is_resistant(float(m[1]), threshold) else NO_DATA
    if m := re.fullmatch(rf"<=?({_NUM})", s):  # true MIC is below (or at) the bound
        return SUSCEPTIBLE if not _is_resistant(float(m[1]), threshold) else NO_DATA
    if m := re.fullmatch(rf"({_NUM})-({_NUM})", s):
        low, high = float(m[1]), float(m[2])
        if _is_resistant(low, threshold):
            return RESISTANT
        if not _is_resistant(high, threshold):
            return SUSCEPTIBLE
    return NO_DATA


def call_drug(row: dict[str, str], drug: str) -> int:
    if drug in NON_CLSI_THRESHOLDS_MG_L:
        return call_by_threshold(row.get(f"{drug}_mic", ""), NON_CLSI_THRESHOLDS_MG_L[drug])
    category = row.get(f"{drug}_clsi_category", "").strip().upper()
    if not category:
        return NO_DATA
    return RESISTANT if category == "R" else SUSCEPTIBLE


def is_patient_isolate(row: dict[str, str]) -> bool:
    """Clinical isolate of the complex: no LABEL (control / type strain), not excluded."""
    return (
        not row["LABEL"].strip()
        and row["excluded"].strip().lower() != "true"
        and row["species"].strip() in COMPLEX_SPECIES
    )


def read_patients(results_csv: Path) -> dict[str, dict[str, str]]:
    with results_csv.open(encoding="utf-8", newline="") as fh:
        return {r["PROBENNUMMER"]: r for r in csv.DictReader(fh) if is_patient_isolate(r)}


def write_tree(tree_file: Path, keep: set[str], out: Path) -> list[str]:
    from Bio import Phylo  # only here, so the call logic can be tested without Biopython

    tree = Phylo.read(str(tree_file), "newick")
    for tip in [t.name for t in tree.get_terminals() if t.name not in keep]:
        tree.prune(tip)
    tree.root_at_midpoint()
    Phylo.write(tree, str(out), "newick")
    return sorted(t.name for t in tree.get_terminals())


def write_ast(patients: dict[str, dict[str, str]], tips: list[str], out: Path) -> dict[str, int]:
    n = len(DRUGS)
    lines = [
        "DATASET_BINARY", "SEPARATOR TAB", "DATASET_LABEL\tAST", f"COLOR\t{BLACK}",
        "FIELD_SHAPES\t" + "\t".join([DRUG_SHAPE_CIRCLE] * n),
        "FIELD_LABELS\t" + "\t".join(DRUGS),
        "FIELD_COLORS\t" + "\t".join([BLACK] * n),
        "SHOW_LABELS\t1", "LABEL_ROTATION\t45", "HEIGHT_FACTOR\t1", "MARGIN\t5",
        "LEGEND_TITLE\tAST (CLSI; EMB, INH, ETO, STR by MIC threshold)",
        "LEGEND_SHAPES\t2\t2", "LEGEND_COLORS\t" + f"{BLACK}\t{BLACK}", "LEGEND_LABELS\tresistant (filled)\tsusceptible/intermediate (hollow)",
        "DATA",
    ]
    resistant = dict.fromkeys(DRUGS, 0)
    for tip in tips:
        calls = [call_drug(patients[tip], d) for d in DRUGS]
        for d, c in zip(DRUGS, calls):
            resistant[d] += c == RESISTANT
        lines.append("\t".join([tip, *map(str, calls)]))
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return resistant


def write_species_ring(patients: dict[str, dict[str, str]], tips: list[str], out: Path) -> dict[str, int]:
    counts: dict[str, int] = {}
    data = []
    for tip in tips:
        sp = patients[tip]["species"].strip()
        counts[sp] = counts.get(sp, 0) + 1
        data.append(f"{tip}\t{kp.SPECIES_COLORS[sp]}\tM. {sp}")
    present = [s for s in COMPLEX_SPECIES if s in counts]
    lines = [
        "DATASET_COLORSTRIP", "SEPARATOR TAB", "DATASET_LABEL\tspecies", f"COLOR\t{BLACK}",
        "COLOR_BRANCHES\t0", "STRIP_WIDTH\t40", "MARGIN\t10", "SHOW_STRIP_LABELS\t0",
        "LEGEND_TITLE\tspecies", "LEGEND_SHAPES\t" + "\t".join(["1"] * len(present)),
        "LEGEND_COLORS\t" + "\t".join(kp.SPECIES_COLORS[s] for s in present),
        "LEGEND_LABELS\t" + "\t".join(f"M. {s} (n={counts[s]})" for s in present),
        "DATA", *data,
    ]
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return counts


def write_labels(patients: dict[str, dict[str, str]], tips: list[str], out: Path) -> None:
    lines = ["LABELS", "SEPARATOR TAB", "DATA", *(f"{t}\tM. {patients[t]['species'].strip()} [{t}]" for t in tips)]
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--tree", type=Path, default=kp.OUTPUT_ROOT / "iTOL" / "mkan329" / "kansasii_complex_tree.treefile")
    ap.add_argument("--results", type=Path, default=kp.SCREENING_MAP_RESULTS)
    ap.add_argument("--out-dir", type=Path, default=kp.OUTPUT_ROOT / "iTOL" / "mkan329_patients")
    args = ap.parse_args()

    patients = read_patients(args.results)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    tips = write_tree(args.tree, set(patients), args.out_dir / "kansasii_patients_midpoint.nwk")
    missing = sorted(set(patients) - set(tips))
    if missing:
        print(f"WARNING: {len(missing)} patient isolates not in the tree: {', '.join(missing)}", file=sys.stderr)
    tips_in = [t for t in tips if t in patients]
    resistant = write_ast(patients, tips_in, args.out_dir / "itol_1_ast_dots.txt")
    counts = write_species_ring(patients, tips_in, args.out_dir / "itol_2_species_ring.txt")
    write_labels(patients, tips_in, args.out_dir / "itol_leaf_labels.txt")
    print(f"{len(tips_in)} patient isolates in the tree")
    print("species:", ", ".join(f"{s} {n}" for s, n in counts.items()))
    print("resistant per drug:", ", ".join(f"{d} {n}" for d, n in resistant.items()))
    if kp.MANIFEST_SCRIPT.is_file():
        repo = Path(__file__).resolve().parents[1]
        subprocess.run(
            ["bash", str(kp.MANIFEST_SCRIPT), str(args.out_dir), str(repo), Path(__file__).name, str(args.tree), str(args.results)],
            check=False,
        )


if __name__ == "__main__":
    main()
