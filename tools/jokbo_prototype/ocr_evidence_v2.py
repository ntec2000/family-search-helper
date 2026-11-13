"""Conservative OCR evidence scoring; never edits OCR using verified names."""
import json
import re
from pathlib import Path

HAN = re.compile(r'[\u3400-\u9fff\U00020000-\U0002fa1f]')

def load_runs(path):
    data = json.loads(Path(path).read_text(encoding='utf-8'))
    runs = data if isinstance(data, list) else data['runs']
    return list(runs.values()) if isinstance(runs, dict) else runs

def canonical_lines(raw):
    if not isinstance(raw, str):
        return []
    return [''.join(HAN.findall(line)) for line in raw.splitlines() if HAN.search(line)]

def score(runs, gold, min_length=2):
    if (not isinstance(gold, list) or not gold or len(set(gold)) != len(gold)
            or any(not isinstance(name, str) or len(name) < min_length
                   or any(not HAN.fullmatch(char) for char in name) for name in gold)):
        raise ValueError('Gold must contain unique, Han-only names of sufficient length')
    evidence = {name: [] for name in gold}
    successful = 0
    for index, run in enumerate(runs):
        if (not isinstance(run, dict) or run.get('ok') is False
                or run.get('error') or run.get('returncode', 0)):
            continue
        successful += 1
        for line_index, line in enumerate(canonical_lines(run.get('raw', ''))):
            for name in gold:
                start = 0
                while (position := line.find(name, start)) != -1:
                    evidence[name].append({'run_index': index, 'line_index': line_index,
                                           'offset': position, 'job': run.get('job')})
                    start = position + 1
    matched = [name for name in gold if evidence[name]]
    return {'runs': len(runs), 'successful_runs': successful,
            'gold_count': len(gold), 'matched_count': len(matched),
            'ensemble_exact_name_recall': len(matched) / len(gold),
            'evidence': evidence,
            'metric': 'ensemble exact contiguous multi-Han name recall; NOT CER'}
