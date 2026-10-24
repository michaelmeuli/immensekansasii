"""is_excluded of scripts/06_screening_map_results.py: contaminated, non-complex clinical sample, or < min_pct % of the cgMLST loci called."""
from __future__ import annotations

import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("results06", Path(__file__).resolve().parents[1] / "scripts/06_screening_map_results.py")
assert spec is not None and spec.loader is not None
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
is_excluded = mod.is_excluded


def test_threshold() -> None:
    assert is_excluded("", "89.99", 90.0)
    assert not is_excluded("", "90", 90.0)
    assert not is_excluded("", "99.8", 90.0)


def test_contaminated_always_excluded() -> None:
    assert is_excluded("contaminated", "99.8", 90.0)
    assert is_excluded("contaminated", "", 90.0)


def test_missing_percentage_does_not_exclude() -> None:
    assert not is_excluded("", "", 90.0)


def test_non_complex_sample_excluded() -> None:
    assert is_excluded("", "", 90.0, "avium", "")


def test_non_complex_control_not_excluded() -> None:
    assert not is_excluded("", "", 90.0, "avium", "M. avium (ATCC 19421)")


def test_complex_or_unknown_species_not_excluded() -> None:
    assert not is_excluded("", "99.8", 90.0, "persicum", "")
    assert not is_excluded("", "", 90.0, "", "")
