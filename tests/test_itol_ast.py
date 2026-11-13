"""MIC threshold calls and patient selection of scripts/12_generate_itol_ast.py."""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path
from typing import Any

scripts = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(scripts))
spec = importlib.util.spec_from_file_location("itol12", scripts / "12_generate_itol_ast.py")
assert spec is not None and spec.loader is not None
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
R, S, NA = mod.RESISTANT, mod.SUSCEPTIBLE, mod.NO_DATA


def test_plain_values_use_strict_threshold() -> None:
    assert mod.call_by_threshold("16", 16.0) == S
    assert mod.call_by_threshold("32", 16.0) == R
    assert mod.call_by_threshold("2.0", 8.0) == S
    assert mod.call_by_threshold("0.6", 0.6) == S


def test_censored_values() -> None:
    assert mod.call_by_threshold(">64", 16.0) == R
    assert mod.call_by_threshold(">8", 16.0) == NA
    assert mod.call_by_threshold("<0.3", 0.6) == S
    assert mod.call_by_threshold("<=0.3", 0.6) == S
    assert mod.call_by_threshold("<0.5", 0.25) == NA


def test_ranges() -> None:
    assert mod.call_by_threshold("4-8", 8.0) == S
    assert mod.call_by_threshold("1.2-2.5", 0.6) == R
    assert mod.call_by_threshold("0.3-0.6", 0.6) == S
    assert mod.call_by_threshold("4-16", 8.0) == NA


def test_empty_is_no_data() -> None:
    assert mod.call_by_threshold("", 8.0) == NA


def test_clsi_drug_intermediate_is_white() -> None:
    assert mod.call_drug({"CIP_clsi_category": "I"}, "CIP") == S
    assert mod.call_drug({"CIP_clsi_category": "R"}, "CIP") == R
    assert mod.call_drug({"CIP_clsi_category": ""}, "CIP") == NA


def test_patient_selection() -> None:
    base = {"LABEL": "", "excluded": "false", "species": "kansasii"}
    assert mod.is_patient_isolate(base)
    assert not mod.is_patient_isolate({**base, "LABEL": "M. kansasii (ATCC 12478)"})
    assert not mod.is_patient_isolate({**base, "excluded": "true"})
    assert not mod.is_patient_isolate({**base, "species": "avium"})


def test_patient_list(tmp_path: Path, monkeypatch: Any) -> None:
    """--patient-list writes the sorted patient isolates only and needs no tree."""
    results = tmp_path / "results.csv"
    results.write_text(
        "PROBENNUMMER,LABEL,excluded,species\n"
        "Mkan329-003,,false,persicum\n"
        'Mkan329-128,"M. kansasii (ATCC 12478)",false,kansasii\n'
        "Mkan329-010,,true,persicum\n"
        "Mkan329-184,,false,avium\n"
        "Mkan329-001,,false,kansasii\n",
        encoding="utf-8",
    )
    out = tmp_path / "sub" / "patients.txt"
    monkeypatch.setattr(sys, "argv", ["12", "--results", str(results), "--patient-list", str(out),
                                      "--tree", str(tmp_path / "no_such_tree"), "--out-dir", str(tmp_path / "itol")])
    mod.main()
    assert out.read_text(encoding="utf-8") == "Mkan329-001\nMkan329-003\n"
    assert not (tmp_path / "itol").exists()
