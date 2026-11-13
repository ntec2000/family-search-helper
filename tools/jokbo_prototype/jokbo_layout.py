"""Detect horizontal record bands in genealogy scans without changing source pixels.

Requires Pillow and NumPy; returns bounding boxes in source-image coordinates.
No names, corrections, or ground-truth data are embedded.
"""
from PIL import Image
import numpy as np


def detect_bands(image: Image.Image, *, left_fraction=0.07,
                 right_fraction=0.88, min_gap=3):
    """Return (top, bottom) pairs between long horizontal rules."""
    gray = np.asarray(image.convert("L"))
    h, w = gray.shape
    left, right = int(w * left_fraction), int(w * right_fraction)
    if right <= left:
        raise ValueError("Invalid horizontal analysis region")
    coverage = (gray[:, left:right] < 220).mean(axis=1)
    candidates = np.flatnonzero(coverage > .35)
    groups = []
    for y in candidates:
        if groups and y - groups[-1][-1] <= min_gap:
            groups[-1].append(int(y))
        else:
            groups.append([int(y)])
    lines = [int(np.median(group)) for group in groups]
    return [(a + 1, b) for a, b in zip(lines, lines[1:])
            if b - a > max(35, int(h * .035))]


def crop_bands(image: Image.Image):
    """Return coordinate-preserving crops for downstream OCR."""
    return [(bounds, image.crop((0, bounds[0], image.width, bounds[1])))
            for bounds in detect_bands(image)]
