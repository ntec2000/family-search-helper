"""Reconstruct vertically ordered Han OCR from Tesseract TSV geometry.

No name dictionary, ground truth, or replacement is used.
"""
import csv
import io
import re

HAN = re.compile(r'[\u3400-\u9fff\U00020000-\U0002fa1f]+')

def reconstruct(tsv, x_tolerance=18, gap_ratio=3.5):
    if x_tolerance <= 0 or gap_ratio <= 0:
        raise ValueError('Tolerances must be positive')
    words = []
    for row in csv.DictReader(io.StringIO(tsv), delimiter='\t'):
        if row.get('level') != '5':
            continue
        value = ''.join(HAN.findall(row.get('text') or ''))
        if not value:
            continue
        try:
            x,y,w,h = (int(row[k]) for k in ('left','top','width','height'))
            float(row.get('conf','-1'))
        except (ValueError,KeyError,TypeError):
            continue
        if w <= 0 or h <= 0:
            continue
        if confidence < 0:
            continue
        words.append({'page':row.get('page_num'), 'block':row.get('block_num'), 'par':row.get('par_num'), 'x':x+w/2,'y':y,'bottom':y+h,'height':h,'text':value})
    columns = []
    for word in sorted(words,key=lambda w:(-w['x'],w['y'])):
        options = [c for c in columns if c['group'] == (word['page'],word['block'],word['par']) and abs(c['anchor']-word['x']) <= x_tolerance]
        if options:
            col = min(options,key=lambda c:abs(c['x']-word['x']))
            col['words'].append(word)
            # Keep anchor fixed to prevent drift across neighboring columns.
        else:
            columns.append({'x':word['x'],'anchor':word['x'],'group':(word['page'],word['block'],word['par']),'words':[word]})
    result=[]
    for col in sorted(columns,key=lambda c:-c['x']):
        sequence=[]; previous=None
        heights=sorted(w['height']/max(1,len(w['text'])) for w in col['words'])
        median=heights[len(heights)//2]
        for word in sorted(col['words'],key=lambda w:w['y']):
            if previous is not None and word['y']-previous > gap_ratio*max(10,median):
                if sequence:
                    result.append({'x':col['x'],'text':''.join(w['text'] for w in sequence)})
                sequence=[]
            sequence.append(word)
            previous=max(word['bottom'],previous or 0)
        if sequence:
            result.append({'x':col['x'],'text':''.join(w['text'] for w in sequence)})
    return result
