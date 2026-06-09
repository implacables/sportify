#!/usr/bin/env python3
"""
EasyOCR jersey bench on SoccerNet-GS.

Run from repo root or experiment dir:
  python run_bench.py [--clip-ids SNGS-021 SNGS-022] [--frame-stride 25]

Results written to:
  benchmarks/results/easyocr-soccernet-gs/<timestamp>/
"""
import argparse
import json
import os
import re
import sys
import time
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from statistics import mean

import easyocr
import numpy as np
import yaml
from PIL import Image

try:
    RESAMPLE = Image.Resampling.LANCZOS
except AttributeError:
    RESAMPLE = Image.LANCZOS

# --- paths ---
EXPERIMENT_DIR = Path(__file__).parent.resolve()
REPO_ROOT = EXPERIMENT_DIR.parents[3]  # sportify/
SGR_ROOT = REPO_ROOT / "sportify-game-reconstruction"
MANIFEST_PATH = SGR_ROOT / "benchmarks" / "soccernet-gsr" / "manifests" / "valid-quick.yaml"
RESULTS_ROOT = SGR_ROOT / "benchmarks" / "results" / "easyocr-soccernet-gs"

# --- defaults (match notebook) ---
SPLIT = "valid"
FRAME_STRIDE = 25
MAX_CROPS_POSITIVE = None
MAX_CROPS_NEGATIVE = 200
NEGATIVE_RATIO = 0.25
IMAGE_SCALE = 4
CROP_PAD_FRAC = 0.12
OCR_KWARGS = {
    "allowlist": "0123456789",
    "mag_ratio": 1.5,
    "contrast_ths": 0.05,
    "adjust_contrast": 0.7,
}
MIN_CONFIDENCE = 0.2
PLAYER_CATEGORY_ID = 1


# ------------------------------------------------------------------ helpers

def _expand(path) -> Path:
    return Path(path).expanduser().resolve()


def _has_labels(root: Path, split: str, clip_id: str) -> bool:
    return (root / split / clip_id / "Labels-GameState.json").is_file()


def resolve_socnet_root(split: str, probe_clip: str = "SNGS-021") -> Path:
    env_root = os.environ.get("SPORTIFY_DATA_ROOT") or os.environ.get("DATA_ROOT")
    candidates = []
    if env_root:
        candidates.append(_expand(env_root))
    candidates += [Path("/workspace"), _expand("~/data/sportify"), Path("/data/sportify")]
    for data_root in dict.fromkeys(candidates):
        root = data_root / "SoccerNetGS"
        if _has_labels(root, split, probe_clip):
            return root
    raise FileNotFoundError(
        f"SoccerNetGS not found (probe: {probe_clip}). "
        f"Set SPORTIFY_DATA_ROOT. Tried: {[str(c) for c in candidates]}"
    )


def parse_jersey(value) -> "str | None":
    if value is None:
        return None
    s = str(value).strip()
    if not s or s.lower() in ("null", "none"):
        return None
    digits = re.sub(r"\D", "", s)
    return digits if digits else None


def load_manifest_clips(path: Path) -> list:
    data = yaml.safe_load(path.read_text())
    return [c["id"] for c in data["clips"]]


def find_clip_dir(socnet_root: Path, split: str, clip_id: str) -> Path:
    label_path = socnet_root / split / clip_id / "Labels-GameState.json"
    if label_path.is_file():
        return label_path.parent
    hits = sorted((socnet_root / split).glob(f"**/{clip_id}/Labels-GameState.json"))
    if hits:
        return hits[0].parent
    raise FileNotFoundError(label_path)


def load_clip_labels(socnet_root: Path, split: str, clip_id: str):
    clip_dir = find_clip_dir(socnet_root, split, clip_id)
    raw = json.loads((clip_dir / "Labels-GameState.json").read_text())
    image_by_id = {im["image_id"]: im for im in raw["images"]}
    img_dir = clip_dir / raw.get("info", {}).get("im_dir", "img1")
    return image_by_id, img_dir, raw["annotations"]


@dataclass
class CropSample:
    clip_id: str
    file_name: str
    frame_idx: int
    track_id: int
    gt_jersey: "str | None"
    bbox: tuple
    is_positive: bool


def build_samples(socnet_root, split, clip_ids, frame_stride, max_pos, max_neg, neg_ratio):
    positives, negatives = [], []
    for clip_id in clip_ids:
        image_by_id, img_dir, annotations = load_clip_labels(socnet_root, split, clip_id)
        frame_order = sorted(image_by_id.values(), key=lambda im: im["file_name"])
        for frame_i, im in enumerate(frame_order):
            if frame_i % frame_stride != 0:
                continue
            for ann in annotations:
                if ann.get("supercategory") != "object":
                    continue
                if ann.get("category_id") != PLAYER_CATEGORY_ID:
                    continue
                if ann.get("image_id") != im["image_id"]:
                    continue
                bbox = ann.get("bbox_image")
                if not bbox:
                    continue
                gt = parse_jersey((ann.get("attributes") or {}).get("jersey"))
                box = (int(bbox["x"]), int(bbox["y"]), int(bbox["w"]), int(bbox["h"]))
                s = CropSample(
                    clip_id=clip_id,
                    file_name=im["file_name"],
                    frame_idx=frame_i,
                    track_id=int(ann.get("track_id", -1)),
                    gt_jersey=gt,
                    bbox=box,
                    is_positive=gt is not None,
                )
                (positives if gt is not None else negatives).append(s)

    if max_pos is not None:
        positives = positives[:max_pos]
    if max_neg > 0 and negatives:
        cap = min(max_neg, max(1, int(len(positives) * neg_ratio)))
        negatives = negatives[:cap]
    return positives + negatives


def crop_player(rgb: np.ndarray, box: tuple, pad_frac: float, scale: int) -> np.ndarray:
    x, y, w, h = box
    H, W = rgb.shape[:2]
    px, py = int(w * pad_frac), int(h * pad_frac)
    x0, y0 = max(0, x - px), max(0, y - py)
    x1, y1 = min(W, x + w + px), min(H, y + h + py)
    crop = rgb[y0:y1, x0:x1]
    if crop.size == 0 or scale == 1:
        return crop
    im = Image.fromarray(crop)
    cw, ch = im.size
    im = im.resize((cw * scale, ch * scale), RESAMPLE)
    return np.array(im)


def ocr_digits(reader, crop: np.ndarray) -> tuple:
    if crop.size == 0:
        return "(none)", 0.0
    t0 = time.perf_counter()
    raw = reader.readtext(crop, detail=1, paragraph=False, **OCR_KWARGS)
    ms = (time.perf_counter() - t0) * 1000.0
    parts = [str(x[1]).strip() for x in raw if float(x[2]) >= MIN_CONFIDENCE and str(x[1]).strip()]
    text = " | ".join(parts) if parts else ""
    digits = re.sub(r"\D", "", text)
    return (digits if digits else "(none)"), ms


# ------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--clip-ids", nargs="+", default=None)
    ap.add_argument("--frame-stride", type=int, default=FRAME_STRIDE)
    ap.add_argument("--no-gpu", action="store_true")
    ap.add_argument("--max-pos", type=int, default=None)
    ap.add_argument("--max-neg", type=int, default=MAX_CROPS_NEGATIVE)
    args = ap.parse_args()

    socnet_root = resolve_socnet_root(SPLIT)
    clip_ids = args.clip_ids or load_manifest_clips(MANIFEST_PATH)

    print(f"SoccerNet root:  {socnet_root}")
    print(f"Clips:           {', '.join(clip_ids)}")
    print(f"Frame stride:    {args.frame_stride}")

    samples = build_samples(
        socnet_root, SPLIT, clip_ids,
        args.frame_stride, args.max_pos, args.max_neg, NEGATIVE_RATIO,
    )
    pos_samples = [s for s in samples if s.is_positive]
    neg_samples = [s for s in samples if not s.is_positive]
    print(f"Samples:         {len(samples)} ({len(pos_samples)} pos, {len(neg_samples)} neg)")
    if not pos_samples:
        sys.exit("No positive jersey crops — check dataset path")

    try:
        import torch
        use_gpu = torch.cuda.is_available() and not args.no_gpu
    except ImportError:
        use_gpu = False

    print(f"Loading EasyOCR (gpu={use_gpu})...")
    t0 = time.perf_counter()
    reader = easyocr.Reader(["en"], gpu=use_gpu, verbose=False)
    print(f"Reader ready in {time.perf_counter() - t0:.1f}s")

    # warmup
    first = pos_samples[0]
    img_dir = find_clip_dir(socnet_root, SPLIT, first.clip_id) / "img1"
    rgb_w = np.array(Image.open(img_dir / first.file_name).convert("RGB"))
    ocr_digits(reader, crop_player(rgb_w, first.bbox, CROP_PAD_FRAC, IMAGE_SCALE))

    # run
    frame_cache: dict = {}
    results = []
    crop_ms = []

    for sample in samples:
        key = (sample.clip_id, sample.file_name)
        if key not in frame_cache:
            p = find_clip_dir(socnet_root, SPLIT, sample.clip_id) / "img1" / sample.file_name
            frame_cache[key] = np.array(Image.open(p).convert("RGB"))
        rgb = frame_cache[key]
        crop = crop_player(rgb, sample.bbox, CROP_PAD_FRAC, IMAGE_SCALE)
        pred, ms = ocr_digits(reader, crop)
        crop_ms.append(ms)

        if sample.is_positive:
            outcome = "correct" if pred == sample.gt_jersey else ("miss" if pred == "(none)" else "wrong")
        else:
            outcome = "fp" if pred != "(none)" else "tn"

        results.append({
            "clip": sample.clip_id, "frame": sample.file_name,
            "track": sample.track_id, "gt": sample.gt_jersey,
            "pred": pred, "outcome": outcome, "ms": round(ms, 1),
        })

    pos_results = [r for r in results if r["gt"] is not None and r["gt"] != "(none)"]
    neg_results = [r for r in results if r["gt"] is None or r["gt"] == "(none)"]

    n_pos, n_neg = len(pos_results), len(neg_results)
    correct = sum(1 for r in pos_results if r["outcome"] == "correct")
    miss    = sum(1 for r in pos_results if r["outcome"] == "miss")
    wrong   = sum(1 for r in pos_results if r["outcome"] == "wrong")
    fp_neg  = sum(1 for r in neg_results if r["outcome"] == "fp")
    mean_ms = mean(crop_ms) if crop_ms else 0.0

    print()
    print("=" * 56)
    print("EASYOCR — SOCCERNET-GS JERSEY BENCH")
    print("=" * 56)
    print(f"clips:              {', '.join(clip_ids)}")
    print(f"split:              {SPLIT}   stride={args.frame_stride}")
    print(f"image_scale:        {IMAGE_SCALE}   gpu={use_gpu}")
    print(f"positive crops:     {n_pos}")
    print(f"negative crops:     {n_neg}")
    print()
    print("ACCURACY (player boxes with GT jersey)")
    if n_pos:
        print(f"  exact match:      {correct:5d}  ({100*correct/n_pos:.1f}%)")
        print(f"  miss (no digit):  {miss:5d}  ({100*miss/n_pos:.1f}%)")
        print(f"  wrong digit:      {wrong:5d}  ({100*wrong/n_pos:.1f}%)")
    print()
    print("NULL-JERSEY PLAYERS (should not read a digit)")
    if n_neg:
        print(f"  false positive:   {fp_neg:5d}  ({100*fp_neg/n_neg:.1f}%)")
        print(f"  true negative:    {n_neg - fp_neg:5d}")
    print()
    print("SPEED")
    print(f"  mean per crop:    {mean_ms:.1f} ms")
    print(f"  crops/s:          {1000.0/mean_ms:.2f}" if mean_ms > 0 else "  crops/s:          n/a")
    print()
    print("PER CLIP (positive only)")
    for cid in clip_ids:
        sub = [r for r in pos_results if r["clip"] == cid]
        if not sub:
            continue
        c = sum(1 for r in sub if r["outcome"] == "correct")
        print(f"  {cid}: {c}/{len(sub)} correct ({100*c/len(sub):.1f}%)")
    print()
    wrong_pairs = Counter((r["gt"], r["pred"]) for r in pos_results if r["outcome"] == "wrong")
    if wrong_pairs:
        print("TOP WRONG (gt -> pred)")
        for (gt, pred), cnt in wrong_pairs.most_common(12):
            print(f"  {gt} -> {pred}  x{cnt}")
        print()
    print("SAMPLE FAILURES (up to 15)")
    for r in [r for r in pos_results if r["outcome"] != "correct"][:15]:
        print(f"  {r['clip']} {r['frame']} track={r['track']}  gt={r['gt']} pred={r['pred']}  [{r['outcome']}]")
    print("=" * 56)

    # save results
    timestamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    out_dir = RESULTS_ROOT / timestamp
    out_dir.mkdir(parents=True, exist_ok=True)

    summary = {
        "benchmark": "easyocr-soccernet-gs",
        "timestamp_utc": timestamp,
        "config": {
            "clips": clip_ids,
            "split": SPLIT,
            "frame_stride": args.frame_stride,
            "image_scale": IMAGE_SCALE,
            "crop_pad_frac": CROP_PAD_FRAC,
            "min_confidence": MIN_CONFIDENCE,
            "ocr_kwargs": OCR_KWARGS,
            "gpu": use_gpu,
        },
        "counts": {"positive": n_pos, "negative": n_neg},
        "accuracy": {
            "correct": correct,
            "miss": miss,
            "wrong": wrong,
            "correct_pct": round(100*correct/n_pos, 2) if n_pos else None,
            "miss_pct":    round(100*miss/n_pos, 2)    if n_pos else None,
            "wrong_pct":   round(100*wrong/n_pos, 2)   if n_pos else None,
        },
        "null_jersey": {
            "false_positive": fp_neg,
            "true_negative": n_neg - fp_neg,
            "fp_pct": round(100*fp_neg/n_neg, 2) if n_neg else None,
        },
        "speed": {
            "mean_ms_per_crop": round(mean_ms, 2),
            "crops_per_sec": round(1000.0/mean_ms, 2) if mean_ms > 0 else None,
        },
        "per_clip": {
            cid: {
                "correct": sum(1 for r in pos_results if r["clip"] == cid and r["outcome"] == "correct"),
                "total":   sum(1 for r in pos_results if r["clip"] == cid),
            }
            for cid in clip_ids
        },
    }
    (out_dir / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    (out_dir / "per_crop.json").write_text(json.dumps(results, indent=2) + "\n")
    print(f"\nResults written: {out_dir}/")


if __name__ == "__main__":
    main()
