"""Conservative OCR consensus within one image region; no ground-truth injection."""
from collections import defaultdict
import re

HAN = re.compile(r'[\u3400-\u9fff]+')

def audit(runs, minimum=2):
    if minimum < 1:
        raise ValueError("minimum must be >= 1")
    votes = defaultdict(lambda: {"configs": set(), "languages": set(), "sources": set()})
    for index, run in enumerate(runs):
        if run.get("ok") is False or run.get("error") or not run.get("raw"):
            continue
        job = run.get("job")
        if not isinstance(job, (list, tuple)) or len(job) < 3:
            continue
        roi, psm, language = job[:3]
        config = (str(psm), str(language))
        seen = set()
        for line_no, line in enumerate(run["raw"].splitlines()):
            for match in HAN.finditer(line):
                span = match.group()
                for length in (2, 3):
                    for offset in range(len(span) - length + 1):
                        seen.add((span[offset:offset + length], line_no, match.start() + offset))
        for candidate, line_no, pos in seen:
            key = (roi, candidate)
            votes[key]["configs"].add(config)
            votes[key]["languages"].add(str(language))
            votes[key]["sources"].add((index, line_no, pos))
    return sorted(({"roi": roi, "text": candidate, "support": len(v["configs"]),
                    "languages": sorted(v["languages"]), "sources": len(v["sources"])}
                   for (roi, candidate), v in votes.items()
                   if len(v["configs"]) >= minimum),
                  key=lambda x: (x["roi"], -x["support"], x["text"]))
