"""Reconstruct Han OCR with Tesseract TSV line identifiers and bounding boxes."""
import csv
import io
import re
from collections import defaultdict

HAN = re.compile(r'[\u3400-\u9fff\U00020000-\U0002fa1f]+')

def reconstruct(tsv):
    lines = defaultdict(list)
    for row in csv.DictReader(io.StringIO(tsv), delimiter='\t'):
        if row.get('level') != '5':
            continue
        value = ''.join(HAN.findall(row.get('text') or ''))
        if not value:
            continue
        try:
            x,y,w,h = [int(row[k]) for k in ('left','top','width','height')]
            conf = float(row['conf'])
        except (KeyError, ValueError, TypeError):
            continue
        if w <= 0 or h <= 0 or conf < 0:
            continue
        key = tuple(row.get(k) for k in ('page_num','block_num','par_num','line_num'))
        lines[key].append((y,x,w,h,value,conf))
    results=[]
    for key, tokens in lines.items():
        ordered=sorted(tokens,key=lambda t:(t[0],-t[1]))
        results.append({'group':key,
                        'text':''.join(t[4] for t in ordered),
                        'box':[min(t[1] for t in tokens),min(t[0] for t in tokens),
                               max(t[1]+t[2] for t in tokens),max(t[0]+t[3] for t in tokens)],
                        'confidence_mean':sum(t[5] for t in tokens)/len(tokens)})
    return sorted(results,key=lambda r:(r['group'][:3],-r['box'][0],r['box'][1]))
