#!/usr/bin/env python3
"""Sportify game reconstruction pipeline — walking skeleton.

Usage:
    python pipeline.py --job jobs/dev-sngs021.yaml
"""
import argparse
import json
import time
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

import cv2
import yaml
from ultralytics import YOLO


def load_job(path: str) -> dict:
    with open(path) as f:
        job = yaml.safe_load(f)
    # Resolve tracker config path relative to src/ (job file lives in src/jobs/)
    tracking = job.get("processing", {}).get("tracking", {})
    if "config" in tracking:
        cfg_path = Path(tracking["config"])
        if not cfg_path.is_absolute():
            tracking["config"] = str(Path(path).parent.parent / cfg_path)
    return job


class StepTimer:
    """Accumulates per-step wall-clock times (in milliseconds)."""

    def __init__(self):
        self._totals: dict[str, float] = defaultdict(float)
        self._counts: dict[str, int] = defaultdict(int)
        self._t0: float = 0.0
        self._step: str = ""

    def start(self, step: str) -> None:
        self._step = step
        self._t0 = time.perf_counter()

    def stop(self) -> float:
        elapsed_ms = (time.perf_counter() - self._t0) * 1000
        self._totals[self._step] += elapsed_ms
        self._counts[self._step] += 1
        return elapsed_ms

    def add(self, step: str, ms: float) -> None:
        self._totals[step] += ms
        self._counts[step] += 1

    def summary(self) -> dict:
        return {
            step: {
                "total_ms": round(self._totals[step], 2),
                "mean_ms": round(self._totals[step] / self._counts[step], 2),
                "calls": self._counts[step],
            }
            for step in self._totals
        }


def run(job: dict) -> None:
    job_id = job["job_id"]
    out_dir = Path(job["output"]["dir"])
    out_dir.mkdir(parents=True, exist_ok=True)

    proc = job["processing"]
    stride = proc.get("frame_stride", 1)
    model_path = proc["detection"]["model"]
    imgsz = proc["detection"].get("imgsz", 640)
    tracking_cfg = proc.get("tracking", {})
    tracking_enabled = tracking_cfg.get("enabled", True)
    tracker_config = tracking_cfg.get("config", "bytetrack.yaml")

    import torch
    device = 0 if torch.cuda.is_available() else "cpu"
    print(f"[{job_id}] loading model: {model_path} (device: {device})")
    model = YOLO(model_path)
    model.to(device)

    video_path = job["input"]["video_path"]
    print(f"[{job_id}] opening video: {video_path}")
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise RuntimeError(f"Cannot open video: {video_path}")

    native_fps = cap.get(cv2.CAP_PROP_FPS) or 25.0
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    print(f"[{job_id}] video: {total_frames} frames @ {native_fps} fps, stride={stride}")

    timer = StepTimer()
    started_at = datetime.now(timezone.utc)
    wall_start = time.perf_counter()

    reconstruction = []
    frames_processed = 0
    frame_index = 0
    done = False

    while not done:
        # --- decode ---
        timer.start("decode")
        ret, frame = cap.read()
        timer.stop()
        if not ret:
            break

        timestamp_ms = int(frame_index / native_fps * 1000)

        # --- detect + track ---
        timer.start("detect_and_track")
        if tracking_enabled:
            results = model.track(frame, imgsz=imgsz, persist=True,
                                  tracker=tracker_config, verbose=False)
        else:
            results = model.predict(frame, imgsz=imgsz, verbose=False)
        track_wall_ms = timer.stop()

        # Split Ultralytics-reported detection timing from ByteTrack overhead
        speed = results[0].speed  # keys: preprocess, inference, postprocess (ms)
        timer.add("detection_preprocess", speed["preprocess"])
        timer.add("detection_inference", speed["inference"])
        timer.add("detection_postprocess", speed["postprocess"])
        if tracking_enabled:
            bytetrack_ms = max(
                0.0,
                track_wall_ms - speed["preprocess"] - speed["inference"] - speed["postprocess"],
            )
            timer.add("bytetrack_association", bytetrack_ms)

        # --- projection (stub) ---
        timer.start("projection")
        # Homography not yet wired — x/y remain null.
        timer.stop()

        # --- collect ---
        players = []
        boxes = results[0].boxes
        if boxes is not None and len(boxes):
            ids = boxes.id
            for i in range(len(boxes)):
                x1, y1, x2, y2 = boxes.xyxy[i].tolist()
                conf = float(boxes.conf[i])
                track_id = int(ids[i]) if ids is not None else None

                players.append({
                    "track_id": track_id,
                    "user_id": None,
                    "bbox_ltwh": [round(x1, 1), round(y1, 1), round(x2 - x1, 1), round(y2 - y1, 1)],
                    "x": None,
                    "y": None,
                    "confidence": round(conf, 4),
                })

        reconstruction.append({
            "frame_index": frame_index,
            "timestamp_ms": timestamp_ms,
            "players": players,
        })

        frames_processed += 1
        if frames_processed % 50 == 0:
            elapsed = time.perf_counter() - wall_start
            print(f"[{job_id}] {frames_processed} frames processed ({frames_processed / elapsed:.1f} fps)")

        # Skip stride-1 frames without decoding
        timer.start("decode_skip")
        for _ in range(stride - 1):
            if not cap.grab():
                done = True
                break
        timer.stop()

        frame_index += stride

    cap.release()

    wall_seconds = time.perf_counter() - wall_start
    effective_fps = frames_processed / wall_seconds if wall_seconds > 0 else 0.0
    finished_at = datetime.now(timezone.utc)

    step_summary = timer.summary()

    print(f"\n[{job_id}] === step timings (mean ms / frame) ===")
    for step, s in step_summary.items():
        print(f"  {step:<28} {s['mean_ms']:>8.2f} ms   total {s['total_ms']:>9.1f} ms")
    print(f"\n[{job_id}] {frames_processed} frames in {wall_seconds:.1f}s — effective {effective_fps:.1f} fps")

    # Write reconstruction.json
    recon_path = out_dir / "reconstruction.json"
    recon_path.write_text(json.dumps(reconstruction, indent=2))
    print(f"[{job_id}] wrote {recon_path}")

    # Write job.meta.json
    meta = {
        "job_id": job_id,
        "input": {
            "video_path": video_path,
            "venue_id": job["input"].get("venue_id"),
            "roster_id": job["input"].get("roster_id"),
        },
        "output": {
            "reconstruction_path": str(recon_path),
        },
        "status": "succeeded",
        "frame_stride": stride,
        "started_at": started_at.isoformat(),
        "finished_at": finished_at.isoformat(),
        "metrics": {
            "frames_processed": frames_processed,
            "wall_clock_seconds": round(wall_seconds, 2),
            "effective_fps": round(effective_fps, 2),
            "step_timings": step_summary,
            "conditional_steps": {
                "jersey_ocr": 0,
                "reid": 0,
            },
        },
    }
    meta_path = out_dir / "job.meta.json"
    meta_path.write_text(json.dumps(meta, indent=2))
    print(f"[{job_id}] wrote {meta_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Sportify game reconstruction pipeline")
    parser.add_argument("--job", required=True, help="Path to job YAML descriptor")
    args = parser.parse_args()

    job = load_job(args.job)
    run(job)


if __name__ == "__main__":
    main()
