"""Evidence-preserving OCR ensemble: never invent missing Han characters."""
import re
from collections import defaultdict

HAN = re.compile(r'[\u3400-\u9fff]+')


def han_sequences(raw):
    """Retain OCR line boundaries; strip whitespace within a line only."""
    return [s for line in raw.splitlines()
            if (s := ''.join(HAN.findall(line)))]


def candidate_support(runs, minimum=2):
    """Return 2/3-character substrings supported by independent OCR runs."""
    if minimum < 1:
        raise ValueError('minimum must be >= 1')
    support = defaultdict(set)
    for idx, run in enumerate(runs):
        if isinstance(run, dict):
            if run.get('error') or run.get('ok') is False:
                continue
            raw = run.get('raw', '')
            identity = tuple(run.get('job', (idx,)))
        else:
            raw, identity = run, (idx,)
        seen = set()
        for line in han_sequences(raw):
            for n in (2, 3):
                seen.update(line[i:i+n] for i in range(len(line)-n+1))
        for item in seen:
            support[item].add(identity)
    return sorted(({'text': key, 'support': len(ids)}
                   for key, ids in support.items() if len(ids) >= minimum),
                  key=lambda x: (-x['support'], x['text']))
