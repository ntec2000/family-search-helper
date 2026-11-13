"""Audit existing OCR runs with strict engine-diversity and exact provenance."""
import json
from collections import defaultdict
from pathlib import Path
from jokbo_ocr_consensus import han_sequences


def audit(runs, min_configs=2, min_languages=2):
    votes = defaultdict(lambda: {'configs': set(), 'languages': set(), 'sources': set()})
    for index, run in enumerate(runs):
        if run.get('ok') is False or run.get('error'):
            continue
        job = run.get('job', [index, 'unknown'])
        if not isinstance(job, (list, tuple)):
            raise ValueError('job must be list or tuple')
        language = next((x for x in job if isinstance(x, str) and ('vert' in x or x.startswith('chi_'))), 'unknown')
        for line_number, line in enumerate(han_sequences(run.get('raw', ''))):
            for length in (2, 3):
                for start in range(len(line) - length + 1):
                    text = line[start:start + length]
                    record = votes[text]
                    record['configs'].add(tuple(job))
                    record['languages'].add(language)
                    record['sources'].add((index, line_number, start))
    return sorted(({'text': word, 'config_count': len(v['configs']),
                    'language_count': len(v['languages']),
                    'source_count': len(v['sources'])}
                   for word, v in votes.items()
                   if len(v['configs']) >= min_configs and len(v['languages']) >= min_languages),
                  key=lambda item: (-item['language_count'], -item['config_count'], item['text']))


if __name__ == '__main__':
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument('runs_json')
    p.add_argument('--output', required=True)
    args = p.parse_args()
    data = json.loads(Path(args.runs_json).read_text(encoding='utf-8'))
    runs = data if isinstance(data, list) else data['runs']
    results = audit(runs)
    Path(args.output).write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'runs': len(runs), 'audited_candidates': len(results), 'top': results[:10]}, ensure_ascii=False))
