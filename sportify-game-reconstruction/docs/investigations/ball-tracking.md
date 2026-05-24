# Ball Tracking — Investigation & Phased Plan

**Status:** Investigation complete; **Phase 1 spike recommended**  
**Last updated:** 2026-05-24  
**Stage:** Not in reconstruction POC spec (v0.3). Adjacent to deferred **event detection**; may inform future scoring or analytics.

---

## Context

Reliable ball tracking has not been achieved consistently on Sportify footage. This document records an online/literature investigation into approaches that fit our constraints:

| Constraint | Implication |
|------------|-------------|
| **Fixed elevated side-view camera** | No pan/zoom compensation; ball may appear larger than broadcast (~10–30 px) but remains a small object |
| **Stored venue homography** | Ground-plane `(x, y)` projection is cheap; **height is not** resolved by homography alone |
| **VPS / GPU cost sensitivity** | Detection must be sparse or lightweight; filtering can run on CPU |
| **POC focus** | Player GSR efficiency is primary; ball is **not** a POC deliverable today |

The [pipeline spec](../spec/overview.md) (v0.3) defines player reconstruction only. Ball tracking is documented here as a **separate research track** with a phased spike plan.

---

## Problem Statement

We need a method that can, from a single elevated viewpoint:

1. **Detect and track** the ball with reasonable temporal consistency (occlusions, motion blur, clutter).
2. **Estimate field position** `(x, y)` in meters.
3. **Estimate height** `z` when the ball is airborne — homography footpoint projection is wrong off the ground plane.

These goals conflict with cost: broadcast-grade ball pipelines use dedicated detectors plus heavy temporal models. SoccerNet's own tracking benchmark treats the ball as the hardest class (baseline end-to-end HOTA **42.38** on [SoccerNet-Tracking](https://github.com/SoccerNet/sn-tracking)).

---

## Why Single-Camera Height Is Hard

From one viewpoint, image coordinates `(u, v)` define a **ray** in 3D, not a unique world point. A ground homography maps pixels to the **pitch plane** (`z = 0`). An airborne ball projected to the ground is systematically wrong.

Height (or depth) requires at least one extra constraint:

| Cue | Mechanism | Needs beyond homography? |
|-----|-----------|---------------------------|
| Apparent ball size | Known real diameter (≈22 cm) + diameter in pixels + camera calibration | **Yes** — intrinsics/extrinsics |
| Ballistic motion | Parabola / gravity model over a short window | Calibration helpful; physics when in flight |
| Multi-mode temporal filter | Possession vs free-flight vs occluded states | 2D detections + player positions |
| Homography footpoint | Ray–ground intersection | **No** — but only valid when ball is on grass |

**Conclusion:** Phase 1 can evaluate **2D detection and ground-plane tracking** using existing venue homography. Phases 2–3 add calibration and temporal/3D models only if Phase 1 recall is acceptable.

---

## Investigation Summary

### Approaches surveyed

#### Detection (GPU-bound)

| Approach | Efficiency | Soccer fit | Output | Notes |
|----------|------------|------------|--------|-------|
| [RF-DETR Nano/Small](https://github.com/roboflow/rfdetr) | Low–medium GPU | Good after fine-tune | Bbox | [AutoCam-AI](https://github.com/chele-s/AutoCam-AI) pattern: detect at 720p/1080p, EKF on CPU |
| [RF-DETR SoccerNet fine-tune](https://huggingface.co/julianzu9612/RFDETR-Soccernet) | Medium–high | Strong | Bbox | Ball F1 ~74.7%; misses heavy occlusion |
| [TrackNetV4](https://github.com/TrackNetV4/TrackNetV4) | Moderate | Tennis/badminton; soccer TBD | Heatmap `(x, y)` image coords | Motion-attention; needs domain fine-tune |
| [VballNet / VballNetFast](https://github.com/asigatchov/vball-net) | **100–300 FPS CPU** (ONNX) | Volleyball | `(x, y)` only | Proves heatmap trackers can be very cheap; not soccer-validated |
| YOLO + ByteTrack | Low per frame | **Poor ball recall** out of box | Bbox | Common tutorials; interpolation hides gaps |
| Color / Hough / background subtraction | Minimal | **Fragile** | Blob | Only viable in controlled lighting/ball color |

#### 3D / height (mostly CPU after detection)

| Approach | Efficiency | Height? | Notes |
|----------|------------|---------|-------|
| [Van Zandycke et al., CVPR 2022](https://arxiv.org/abs/2204.00003) — diameter CNN on detection patch | Small CNN | **Yes** | ~1.6 px diameter error; needs full camera calibration |
| [Yandex 2025 — single-camera 3D trajectory](https://arxiv.org/abs/2506.07981) | Filter **50+ FPS CPU** | **Yes** | Multi-mode beam search; no public code yet |
| EKF + ballistic constraints | CPU | Partial | Good in flight; fails long occlusions without mode switching |
| Trajectory parabola fit (offline window) | CPU | Partial | Free-flight segments only |

#### What does not solve height

- Homography on bbox center alone  
- ByteTrack / DeepSORT on ball bbox  
- TrackNet-style `(x, y)` heatmaps without diameter or physics  
- Event-spotting models (e.g. SoccerNet ball action spotting) — actions, not continuous position  

### Sportify-specific advantages

- **Fixed camera** — no optical-flow camera compensation; detection can run every *k* frames with interpolation.
- **Stored homography** — cheap ground `(x, y)` when ball is on the pitch.
- **Elevated side view** — likely larger ball in pixels than broadcast; still occluded often.

### Sportify-specific gaps

- Venue schema today: homography + dimensions only. **3D height requires extending setup** with camera intrinsics/extrinsics (Phase 2).
- No in-repo ball labels or benchmark harness yet.
- Amateur conditions (lighting, ball color, mud) differ from SoccerNet broadcast distribution.

### Datasets for evaluation / fine-tuning

| Resource | Use |
|----------|-----|
| [SoccerNet-Tracking](https://github.com/SoccerNet/sn-tracking) | Ball tracklets; MOT benchmark |
| [SoccerTrack v2](https://atomscott.github.io/SoccerTrack-v2/) | Fixed panoramic amateur matches — closer to our context |
| Open Soccer Ball / Roboflow exports | Small-ball detection fine-tuning |
| **Own venue footage** | Primary — domain match matters most |

---

## Recommended Phased Investigation

Phases are ordered by **increasing complexity and dependency**. Only **Phase 1** is recommended to start now.

### Phase 1 — 2D detection spike on our footage ✅ *Recommended*

**Goal:** Measure whether a lightweight detector can find the ball often enough on real Sportify-style elevated footage.

**Scope:**

- Sample ~500–1000 frames (or ~10 min of video) from target venue/camera setup.
- Manual labels: ball visible `(u, v)` or bbox; mark occluded/missing.
- Benchmark candidates (same hardware as POC VPS target when possible):
  - RF-DETR-Nano or RF-DETR-Small (off-the-shelf + optional SoccerNet fine-tune)
  - YOLOv8n baseline (sanity check)
  - TrackNetV4 or VballNet-style heatmap model (optional comparison if time permits)
- Run at 640 and 1280 input; optionally every 3rd–5th frame.
- Metrics: recall, precision, typical ball size in px, false positives (lines, shirts, specular highlights).

**Success criteria (TBD after first run):**

- Ball recall high enough that temporal interpolation could plausibly bridge gaps (exact threshold to be set from label stats).
- GPU cost compatible with running **alongside** player reconstruction (not dominating the ~1.1 FPS SoccerNet baseline comparison).

**Deliverables:**

- Labeled frame subset (location TBD)
- Benchmark script + results table
- Go / no-go note for Phase 2

**Explicitly out of scope for Phase 1:** height estimation, venue calibration changes, integration into `reconstruction.json`.

---

### Phase 2 — Ground position + optional 3D height ⏸ *Deferred pending Phase 1*

**Goal:** Map detections to field coordinates; add `z` if calibration is extended.

**Scope:**

- **Ground plane:** project detection footpoint (or bbox bottom center) through stored homography → `(x, y)`.
- **Height:** extend venue setup with camera intrinsics/extrinsics; implement diameter-based 3D (Van Zandycke-style small CNN on 64×64 patches) or adopt temporal filter when Yandex code is available.
- CPU-side association: Kalman / short-gap interpolation; jump rejection (see AutoCam EKF patterns).

**Gate:** Phase 1 recall meets agreed threshold.

---

### Phase 3 — Temporal robustness under occlusion ⏸ *Deferred*

**Goal:** Maintain plausible trajectories through possession, kicks, and multi-frame occlusion.

**Scope:**

- Multi-mode state machine (free flight / possession / occluded / out of play).
- Fuse ball track with player field positions from GSR pipeline when ball is near a player.
- Ballistic EKF segments for airborne phases.
- Evaluate on longer clips; document failure modes (crowded box, goalmouth, motion blur).

**Gate:** Phase 2 ground `(x, y)` stable enough to justify temporal investment.

---

## Architecture Sketch (if Phase 1 succeeds)

Target end-state — **not** to be built until phased gates pass:

```
Video frame
    → [every k frames] RF-DETR-Nano @ 720p
    → [if detected] optional diameter CNN (Phase 2)
    → 3D ray + ball size + camera calib (Phase 2)
    → CPU filter / interpolation (Phase 2–3)
    → field (x, y, z)
```

Player reconstruction runs in parallel; ball path must not regress POC throughput targets.

---

## Decision Log

| Date | Decision |
|------|----------|
| 2026-05-24 | Literature/code investigation complete. Full 3D pipeline deferred; **Phase 1 2D detection spike approved** as next experiment. |
| 2026-05-24 | Ball remains **out of reconstruction POC spec** until Phase 1 results and product decision. |

---

## References

| Resource | URL |
|----------|-----|
| Van Zandycke — 3D ball from single calibrated image (CVPR 2022) | https://arxiv.org/abs/2204.00003 |
| Vorobev et al. — Real-time 3D ball from single camera (2025) | https://arxiv.org/abs/2506.07981 |
| SoccerNet-Tracking dev kit | https://github.com/SoccerNet/sn-tracking |
| SoccerTrack v2 (amateur fixed camera) | https://atomscott.github.io/SoccerTrack-v2/ |
| RF-DETR | https://github.com/roboflow/rfdetr |
| RF-DETR SoccerNet fine-tune | https://huggingface.co/julianzu9612/RFDETR-Soccernet |
| AutoCam-AI (RF-DETR + EKF reference pipeline) | https://github.com/chele-s/AutoCam-AI |
| TrackNetV4 | https://github.com/TrackNetV4/TrackNetV4 |
| VballNet (efficient heatmap tracker) | https://github.com/asigatchov/vball-net |
| SoccerDETR (soccer-specific detector) | https://www.mdpi.com/2227-7080/14/3/142 |

---

## Related Documents

| Document | Relationship |
|----------|--------------|
| [Pipeline spec](../spec/overview.md) | POC scope — players only; ball not in output schema |
| [Pipeline overview](../overview.md) | Efficiency-first POC vs SoccerNet |
| [Product stages](../../../docs/product-stages.md) | Event detection deferred; ball tracking adjacent |
