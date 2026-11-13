"""Recover vertical Han text using Tesseract TSV coordinates, not guessed names."""
import csv
import io
import re
import subprocess
from collections import defaultdict

HAN = re.compile(r'^[\u3400-\u9fff]+$')


def reconstruct(tsv, gap_factor=2.8):
    groups = defaultdict(list)
    for row in csv.DictReader(io.StringIO(tsv), delimiter='\t'):
        if row['level'] != '5' or not HAN.fullmatch(row['text'].strip()):
            continue
        key = tuple(row[k] for k in ('page_num', 'block_num', 'par_num', 'line_num'))
        groups[key].append((int(row['top']), int(row['height']),
                            row['text'].strip(), float(row['conf'])))
    sequences = []
    for key, words in groups.items():
        words.sort()
        current, heights, previous_end = [], [], None
        for top, height, text, confidence in words:
            if (previous_end is not None and
                    top - previous_end > gap_factor * max(
                        1, sorted(heights)[len(heights) // 2])):
                if current:
                    sequences.append((''.join(current), key))
                current, heights = [], []
            current.append(text)
            heights.append(height)
            previous_end = top + height
        if current:
            sequences.append((''.join(current), key))
    return sequences


def recognize(image, psm=5, language='HanT_vert'):
    process = subprocess.run(
        ['tesseract', image, 'stdout', '-l', language, '--psm', str(psm), 'tsv'],
        capture_output=True, text=True, timeout=60)
    if process.returncode:
        raise RuntimeError(process.stderr)
    return reconstruct(process.stdout)
