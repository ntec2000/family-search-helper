"""Score independently verified names against real OCR transcripts, no substitutions."""
import argparse
import json
from pathlib import Path


def evaluate(texts, gold):
    cleaned = [''.join(text.split()) for text in texts]
    matches = {name: [i for i, text in enumerate(cleaned) if name in text]
               for name in gold}
    matched = [name for name, indices in matches.items() if indices]
    return {'gold_count': len(gold), 'matched_count': len(matched),
            'exact_name_recall': len(matched) / len(gold) if gold else None,
            'matched_names': matched,
            'unmatched_names': [n for n in gold if not matches[n]],
            'matched_transcript_indices': matches,
            'metric': 'exact contiguous name recall (not CER or precision)'}


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--gold', required=True, help='UTF-8 JSON list of verified names')
    p.add_argument('transcripts', nargs='+')
    args = p.parse_args()
    gold = json.loads(Path(args.gold).read_text(encoding='utf-8'))
    if not isinstance(gold, list) or not all(isinstance(x, str) and x for x in gold):
        raise ValueError('gold must be a JSON list of nonempty strings')
    print(json.dumps(evaluate(
        [Path(x).read_text(encoding='utf-8') for x in args.transcripts],
        gold), ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
