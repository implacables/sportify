# Ball Tracking — Investigation & Phased Plan

**Status:** Investigation complete; **Phase 1 spike recommended**  
**Last updated:** 2026-05-24  
**Stage:** Not in reconstruction POC spec (v0.3). Adjacent to deferred **event detection**; may inform future scoring or analytics.

---

## Product Requirement

**2D ball tracking is sufficient.** We do not need height (`z`) or full 3D trajectory for current product goals.

| Requirement | Target |
|-------------|--------|
| Output | Image `(u, v)` and/or field-plane `(x, y)` via stored homography |
| **Tracking consistency** | **≥65%** on labeled evaluation footage (see metric below) |
| GPU cost | Must not dominate player reconstruction throughput |

Homography footpoint projection is an acceptable approximation even when the ball is briefly airborne — errors are tolerable at this consistency bar.

---

## Context

Reliable ball tracking has not been achieved consistently on Sportify footage. This document records an online/literature investigation and the **2D-only** spike plan.

| Constraint | Implication |
|------------|-------------|
| **Fixed elevated side-view camera** | No pan/zoom compensation; ball may appear larger than broadcast (~10–30 px) but remains a small object |
| **Stored venue homography** | Cheap `(x, y)` on pitch plane from detection footpoint |
| **VPS / GPU cost sensitivity** | Detection sparse or lightweight; association/interpolation on CPU |
| **POC focus** | Player GSR efficiency is primary; ball is **not** a POC deliverable today |

The [pipeline spec](../spec/overview.md) (v0.3) defines player reconstruction only. Ball tracking is a **separate research track** until Phase 1 passes the consistency bar.

---

## Problem Statement

From a single elevated viewpoint we need:

1. **Detect and track** the ball with enough temporal continuity for downstream use (occlusions, motion blur, clutter).
2. **Project to field `(x, y)`** using stored homography.

Height and 3D trajectory were investigated but are **out of scope** for Sportify — see [Appendix: 3D / height (not required)](#appendix-3d--height-not-required).

Broadcast-grade ball pipelines remain expensive; SoccerNet tracking baseline end-to-end HOTA is **42.38** ([SoccerNet-Tracking](https://github.com/SoccerNet/sn-tracking)). Our bar is pragmatic: **≥65% consistency**, not broadcast accuracy.

---

## Tracking Consistency Metric

Primary metric for go/no-go and model comparison:

**Tracking consistency** = (frames where pipeline outputs a valid ball position) / (frames where ball is **ground-truth visible**)

A frame counts as a **valid output** if any of:

- **Detection hit** — predicted center within **15 px** of label (adjust if median ball diameter differs on our footage), or bbox IoU ≥ 0.3.
- **Short-gap interpolation** — no detection, but position interpolated from detections ≤ **5 frames** before/after (linear or Kalman); gap counted as valid only once per contiguous miss.

Frames labeled **occluded** or **not visible** are excluded from the denominator.

| Result | Meaning |
|--------|---------|
| ≥65% | **Pass** — adopt detector + lightweight tracker for integration planning |
| <65% | **Fail** — try next candidate, fine-tune on venue footage, or revisit frame stride / resolution |

Secondary metrics (report alongside, not gating): precision, typical ball size in px, false-positive rate, GPU ms per inference frame.

---

## Investigation Summary

### Detection candidates (GPU-bound)

| Approach | Efficiency | Soccer fit | Output | Notes |
|----------|------------|------------|--------|-------|
| [RF-DETR Nano/Small](https://github.com/roboflow/rfdetr) | Low–medium GPU | Good after fine-tune | Bbox | [AutoCam-AI](https://github.com/chele-s/AutoCam-AI): detect at 720p, filter on CPU |
| [RF-DETR SoccerNet fine-tune](https://huggingface.co/julianzu9612/RFDETR-Soccernet) | Medium–high | Strong | Bbox | Ball F1 ~74.7%; candidate if Nano recall is low |
| [TrackNetV4](https://github.com/TrackNetV4/TrackNetV4) | Moderate | Tennis/badminton; soccer TBD | Heatmap `(u, v)` | Needs domain fine-tune |
| [VballNet / VballNetFast](https://github.com/asigatchov/vball-net) | **100–300 FPS CPU** (ONNX) | Volleyball | `(u, v)` | Cheap; soccer not validated |
| YOLO + ByteTrack | Low per frame | **Poor ball recall** | Bbox | Sanity baseline only |
| Color / Hough / background subtraction | Minimal | **Fragile** | Blob | Not primary |

### Sportify-specific advantages

- **Fixed camera** — detect every *k* frames; interpolate on CPU.
- **Stored homography** — `(x, y)` without per-frame calibration.
- **Elevated side view** — often larger ball in px than broadcast.

### Gaps

- No in-repo ball labels or benchmark harness yet.
- Amateur conditions differ from SoccerNet broadcast distribution.

### Datasets for evaluation / fine-tuning

| Resource | Use |
|----------|-----|
| [SoccerNet-Tracking](https://github.com/SoccerNet/sn-tracking) | Ball tracklets; external benchmark |
| [SoccerTrack v2](https://atomscott.github.io/SoccerTrack-v2/) | Fixed amateur camera — closer to our context |
| Open Soccer Ball / Roboflow exports | Fine-tune if off-the-shelf <65% |
| **Own venue footage** | **Primary** evaluation set for consistency metric |

---

## Phase 1 — 2D Detection & Tracking Spike ✅ *Active plan*

**Goal:** Hit **≥65% tracking consistency** on labeled Sportify footage with a lightweight 2D pipeline.

**Scope:**

- Sample ~500–1000 frames (or ~10 min) from target venue/camera setup.
- Manual labels: ball visible `(u, v)` or bbox; mark occluded / not visible (excluded from metric).
- Benchmark (POC VPS hardware when possible):
  - RF-DETR-Nano or RF-DETR-Small (off-the-shelf; SoccerNet fine-tune if needed)
  - YOLOv8n baseline
  - TrackNetV4 or VballNet (optional)
- Input sizes: 640 and 1280; frame stride every 1–5 frames.
- CPU-side: linear or Kalman interpolation for gaps ≤5 frames; optional jump rejection (>120 px, AutoCam pattern).

**Success criteria:**

| Criterion | Target |
|-----------|--------|
| Tracking consistency | **≥65%** |
| GPU cost | Compatible with running alongside player reconstruction |

**Deliverables:**

- Labeled frame subset (location TBD)
- Benchmark script + results table (consistency, precision, ms/frame)
- Selected model + config, or fine-tune plan if all candidates <65%

**In scope:** 2D `(u, v)`, homography → `(x, y)`, lightweight temporal glue.

**Out of scope:** height / 3D, venue intrinsics, `reconstruction.json` integration (until pass + product decision).

---

## Target Architecture (2D)

```
Video frame
    → [every k frames] RF-DETR-Nano @ 720p  (or winning Phase 1 model)
    → CPU: interpolate / Kalman for gaps ≤5 frames
    → homography: footpoint → field (x, y)
    → ball track artifact (format TBD)
```

Player reconstruction runs in parallel; ball path must not regress POC throughput targets.

---

## Appendix: 3D / height (not required)

Investigated for completeness; **not planned** unless product requirements change.

From one camera, `(u, v)` alone does not fix depth. Height needs ball diameter + full camera calibration, ballistic models, or multi-mode temporal filters ([Van Zandycke CVPR 2022](https://arxiv.org/abs/2204.00003), [Yandex 2025](https://arxiv.org/abs/2506.07981)). Homography footpoint is wrong off the ground plane but acceptable for our **≥65% 2D** bar.

Previously drafted Phase 2 (3D height) and Phase 3 (occlusion state machine) are **cancelled** for current scope.

---

## Decision Log

| Date | Decision |
|------|----------|
| 2026-05-24 | Literature investigation complete. **2D only**; height/3D out of scope. |
| 2026-05-24 | **Phase 1 spike approved** — target **≥65% tracking consistency**. |
| 2026-05-24 | Ball remains **out of reconstruction POC spec** until Phase 1 pass + product decision. |

---

## References

| Resource | URL |
|----------|-----|
| SoccerNet-Tracking dev kit | https://github.com/SoccerNet/sn-tracking |
| SoccerTrack v2 (amateur fixed camera) | https://atomscott.github.io/SoccerTrack-v2/ |
| RF-DETR | https://github.com/roboflow/rfdetr |
| RF-DETR SoccerNet fine-tune | https://huggingface.co/julianzu9612/RFDETR-Soccernet |
| AutoCam-AI (RF-DETR + EKF reference) | https://github.com/chele-s/AutoCam-AI |
| TrackNetV4 | https://github.com/TrackNetV4/TrackNetV4 |
| VballNet | https://github.com/asigatchov/vball-net |
| Van Zandycke — 3D ball (appendix only) | https://arxiv.org/abs/2204.00003 |
| Vorobev et al. — 3D trajectory (appendix only) | https://arxiv.org/abs/2506.07981 |

---

## Related Documents

| Document | Relationship |
|----------|--------------|
| [Pipeline spec](../spec/overview.md) | POC scope — players only; ball not in output schema |
| [Pipeline overview](../overview.md) | Efficiency-first POC vs SoccerNet |
| [Product stages](../../../docs/product-stages.md) | Event detection deferred; ball tracking adjacent |
