"""MIC threshold calls and patient selection of scripts/12_generate_itol_ast.py."""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

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
