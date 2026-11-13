"""Exact OCR evidence evaluation without inserting verified names into recognition.

Only intra-line whitespace is removed; different lines are never joined.
"""
import json
import re
from pathlib import Path

HAN = re.compile(r'[\u3400-\u9fff]')


def load_runs(path):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    runs = data if isinstance(data, list) else data["runs"]
    return list(runs.values()) if isinstance(runs, dict) else runs


def canonical_lines(raw):
    if not isinstance(raw, str):
        return []
    return ["".join(HAN.findall(line)) for line in raw.splitlines()
            if HAN.search(line)]


def score(runs, verified_names):
    if (not isinstance(verified_names, list) or not verified_names
            or len(set(verified_names)) != len(verified_names)
            or any(not isinstance(name, str) or not name
                   or any(not HAN.fullmatch(char) for char in name)
                   for name in verified_names)):
        raise ValueError("Expected a nonempty list of unique Han-only names")
    evidence = {name: [] for name in verified_names}
    successful = 0
    for index, run in enumerate(runs):
        if run.get("ok") is False or run.get("error") or run.get("returncode", 0):
            continue
        successful += 1
        for line_index, line in enumerate(canonical_lines(run.get("raw", ""))):
            for name in verified_names:
                start = 0
                while (position := line.find(name, start)) != -1:
                    evidence[name].append({
                        "run_index": index, "line_index": line_index,
                        "offset": position, "job": run.get("job")})
                    start = position + 1
    matched = [name for name in verified_names if evidence[name]]
    return {"runs": len(runs), "successful_runs": successful,
            "gold_count": len(verified_names), "matched_count": len(matched),
            "ensemble_exact_name_recall": len(matched) / len(verified_names),
            "evidence": evidence,
            "warning": "Ensemble name recall is not character accuracy"}
