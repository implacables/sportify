# Game Reconstruction Pipeline — Specification

**Status:** Draft  
**Version:** 0.3  
**Last updated:** 2026-05-24  
**Stage:** **POC — building now**

This spec defines requirements and interfaces for the game reconstruction pipeline in `sportify-game-reconstruction`. It reflects **current design only**—nothing is inherited from prior repositories.

> **Product stages:** [product-stages.md](../../../docs/product-stages.md). This spec is **POC only**. Scoring and matchmaking are **thesis scope — separate systems**. Event detection is **deferred**.

Product-level requirements: [Sportify product spec](../../../docs/spec/overview.md).

---

## 1. Objective

Transform a pretaped amateur football match video, together with venue geometry and a match roster, into a **time-indexed reconstruction** of player identities with field positions — **fast enough to challenge SoccerNet GSR at mass scale**.

### 1.1 Performance baseline (SoccerNet GSR)

| Metric | SoccerNet GSR baseline | POC requirement |
|--------|------------------------|-----------------|
| End-to-end FPS | ~1.1 | **Materially higher** — exact target TBD during build |
| ~90 min match | ~36 hours wall-clock (A100) | **Hours, not days** — TBD |
| Accuracy bar | GS-HOTA 22.26% | Not the POC primary bar; efficiency is |

The POC succeeds when reconstruction throughput and VPS cost model make **many matches per month** conceivable — not when it matches broadcast-grade identification accuracy.

---

## 2. Definitions

| Term | Meaning |
|------|---------|
| **Venue** | A physical pitch with stored dimensions and homography |
| **Roster** | Match-specific mapping of jersey numbers to platform user IDs, per team |
| **Reconstruction frame** | One output sample at time *t* (every frame or every *k* frames) |
| **Track (`player_id`)** | MOT instance id linking detections across frames |
| **Identity mapping** | Cached association of a track to a roster `user_id` once association succeeds |
| **Identity** | Platform `user_id` from the mapping cache or from ReID + OCR association against the roster |
| **Field coordinates** | Meters in a pitch plane defined by venue dimensions and homography |
| **Eliminated step** | Never run in POC when prerequisites exist (e.g. stored homography) |
| **Conditional step** | Run only when upstream state triggers it |

---

## 3. Pipeline Step Disposition (vs SoccerNet)

| Step | Disposition | Trigger / notes |
|------|-------------|-----------------|
| **Player detection** | Always | Every processed frame (respecting `frame_stride`); eval reference: [YOLO SoccerNet spec](../../../benchmarks/yolo-soccernet/spec.md) |
| **Pitch localization** | **Eliminated** | Never — venue has stored homography |
| **Per-frame camera calibration** | **Eliminated** | Never — homography from venue setup |
| **Multi-object tracking** | Always | Link detections across frames |
| **Identity mapping lookup** | Always (per track, per frame) | If track already mapped to `user_id`, skip association |
| **Identity association (ReID + jersey OCR)** | **Conditional** | Only when track is **not** yet mapped to a `user_id` |
| **Field projection** | Always | Stored homography + detection footpoint |
| **Tracklet merge / roster bind** | Always | Lightweight post-process; updates mapping cache on successful association |

**FR-D1:** Eliminated steps shall not appear in the default POC execution graph.  
**FR-D2:** Conditional steps shall log when invoked and why (for efficiency analysis).  
**FR-D3:** Pipeline shall report count of conditional-step invocations per job.

---

## 4. Inputs

### 4.1 Video (`input.video`)

| Property | Requirement |
|----------|-------------|
| Camera | **DJI Osmo 360** (intended) — [hardware doc](../../../docs/hardware/dji-osmo-360.md) |
| Container | MP4 |
| Codecs | H.265 (HEVC) from Osmo flat export; worker must decode via FFmpeg or equivalent |
| View | Elevated side view, fixed mount for the match |
| Location | VPS filesystem path; referenced by job record |
| Max size (target) | ~20 GB (product spec; actual size depends on Osmo recording settings) |

### 4.2 Venue data (`input.venue`)

Read-only for the job. Produced at venue setup, not by this pipeline per match.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `venue_id` | string | yes | Stable venue identifier |
| `field_length_m` | number | yes | Touchline length |
| `field_width_m` | number | yes | Goal line to goal line |
| `goal_width_m` | number | yes | Goal mouth width |
| `goal_height_m` | number | yes | Goal height |
| `homography` | 3×3 matrix or documented equivalent | yes | Image → pitch plane transform |

**FR-H1:** The pipeline shall **not** recompute homography during match processing.  
**FR-H2:** The pipeline shall **not** run pitch line segmentation or per-frame calibration (SoccerNet TVCalib Modules 2–3).  
**FR-H3:** The pipeline shall use venue homography to express player positions in field coordinates.

### 4.3 Team data (`input.roster`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `team_a.squad_size` | integer | yes | Players expected for team A |
| `team_b.squad_size` | integer | yes | Players expected for team B |
| `team_a.players` | list | yes | `{ user_id, jersey_number }` |
| `team_b.players` | list | yes | `{ user_id, jersey_number }` |

**FR-R1:** Output player identity shall be `user_id` from the roster when jersey number is resolved.  
**FR-R2:** Team affiliation is implied by which roster entry matched; a separate per-frame `team` field is **not required** in the output schema.

---

## 5. Outputs

### 5.1 Primary artifact (`reconstruction.json` or equivalent)

Time series keyed by `frame_index` or `timestamp_ms`.

**Per reconstruction sample:**

```json
{
  "frame_index": 1200,
  "timestamp_ms": 40000,
  "players": [
    {
      "user_id": "usr_abc123",
      "x": 34.2,
      "y": 12.8,
      "z": 0.0,
      "confidence": 0.91
    }
  ]
}
```

| Field | Required | Notes |
|-------|----------|-------|
| `players[].user_id` | when identified | Omit or mark provisional if jersey not resolved (policy TBD) |
| `players[].x`, `players[].y` | yes | Field plane, meters, origin per venue convention (TBD) |
| `players[].z` | optional | Include when estimated; default 0 for ground plane POC |
| `players[].confidence` | recommended | Identity or detection confidence |

**FR-O1:** Output cadence shall be configurable via `output.frame_stride` (1 = every frame, *k* = every *k* frames).  
**FR-O2:** The pipeline shall write the primary artifact to VPS storage and register its path on the job record.  
**FR-O3:** Homography and venue dimensions shall **not** be duplicated in every frame of the output.

### 5.2 Job metadata (`job.meta.json`)

| Field | Description |
|-------|-------------|
| `job_id` | Unique run identifier |
| `input.video.path` | Source video on VPS |
| `input.venue_id` | Venue reference |
| `output.reconstruction.path` | Primary artifact location |
| `status` | `queued` \| `processing` \| `succeeded` \| `failed` |
| `frame_stride` | Applied stride |
| `started_at`, `finished_at` | ISO timestamps |
| `metrics.frames_processed` | Input frames processed |
| `metrics.wall_clock_seconds` | Total duration |
| `metrics.effective_fps` | `frames_processed / wall_clock_seconds` |
| `metrics.conditional_steps` | Counts per step (jersey OCR, ReID, etc.) |
| `metrics.baseline_comparison` | Optional: SoccerNet equivalent hours at 1.1 FPS |
| `error` | Present when `status=failed` |

---

## 6. Processing Requirements

### 6.1 Detection & tracking (always)

- **FR-P1:** Detect persons (players, and optionally referees/staff) in video frames.
- **FR-P2:** Track detections over time to maintain temporal continuity before identity assignment.

*Implementation (YOLO, ByteTrack, etc.) is not specified in this version.*

### 6.2 Identity resolution

- **FR-P3:** The pipeline shall maintain a per-track mapping from track id (`player_id`) to `user_id` once association succeeds.
- **FR-P4:** After tracking, if a track is already mapped to a `user_id`, the pipeline shall **not** run ReID or jersey OCR for that track on that frame; it shall use the cached mapping.
- **FR-P5:** When a track is **not** yet mapped to a `user_id`, the pipeline shall run **ReID and jersey OCR together** to associate the track with a roster entry (not OCR-first with ReID as a later fallback).
- **FR-P6:** Map association results to `user_id` using the roster.
- **FR-P7:** When association is ambiguous or fails, behavior shall be explicit (provisional ID, omit, or low-confidence flag)—**open: see §9**.

Suggested triggers to **invalidate** a cached mapping and re-run association (TBD):

- MOT track break or new `player_id` for the same physical player
- Confidence drop or explicit operator reset

### 6.3 Coordinate projection (always)

- **FR-P8:** Map image-space detections to field `(x, y)` using **stored** homography and venue dimensions.

### 6.4 Eliminated processing

- **FR-P9:** Pitch line segmentation shall **not** run.
- **FR-P10:** Per-frame intrinsic/extrinsic calibration shall **not** run.

---

## 7. Execution & Infrastructure

### 7.1 Worker responsibilities

The **pipeline worker** (GPU process on VPS):

1. Reads job descriptor (video path, venue, roster, config).
2. Reads video from VPS filesystem.
3. Runs reconstruction per step disposition (§3).
4. Writes artifacts to output directory.
5. Updates job status and throughput metrics in metadata store.

The web upload service **shall not** decode the full match video for inference.

### 7.2 Job trigger

| Mode | Description |
|------|-------------|
| **Automatic** | Upload complete → worker starts |
| **Gated** | Upload complete → `queued`; operator starts GPU run manually |

**Open:** which mode POC uses (VPS GPU cost vs UX).

### 7.3 Config (illustrative)

```yaml
job_id: job_20260524_001
input:
  video_path: /data/raw/users/u1/match.mp4
  venue_id: venue_001
  roster_id: roster_789
output:
  dir: /data/artifacts/jobs/job_20260524_001/
processing:
  frame_stride: 5
  identity:
    association:
      mode: conditional  # only when track not mapped to user_id
  jersey_ocr:
    run_with: association
  reid:
    run_with: association
```

### 7.4 Cloud (deprecated for POC)

Previous drafts specified AWS S3, SQS, and Batch. **Not used for POC.** A future production deployment may revisit object storage and managed queues; the POC spec does not require them.

---

## 8. Non-Functional Requirements

| ID | Requirement |
|----|-------------|
| NFR-P1 | **VPS-only:** All I/O on local or VPS-attached storage — no cloud egress. |
| NFR-P2 | **Efficiency:** `effective_fps` shall exceed SoccerNet ~1.1 FPS on reference hardware; document hardware used. |
| NFR-P3 | **Observability:** Logs include `job_id`, per-step timing, conditional-step counts, failure stack traces. |
| NFR-P4 | **Idempotent job writes** where possible (overwrite or version by `job_id`). |
| NFR-P5 | **Demo honesty:** Pre-processed presentation output is allowed; measured metrics must reflect actual batch runs. |

---

## 9. Open Design Items

| # | Topic | Notes |
|---|--------|-------|
| 1 | Mapping invalidation | When to clear track→`user_id` and re-run ReID + OCR |
| 2 | ReID model choice | Lightweight vs accuracy during association |
| 3 | Unresolved identity policy | Provisional track ID vs omit vs `user_id: null` |
| 4 | Field coordinate origin | e.g. center spot vs corner; document in venue schema |
| 5 | Checkpointing | Per-step disk artifacts for resume vs single output blob |
| 6 | Referees / staff | Detect but exclude from player output, or separate class |
| 7 | GPU trigger | Automatic vs gated on VPS |
| 8 | Throughput target | Concrete FPS / hours-per-90-min goal |
| 9 | Reference hardware | Which VPS GPU tier is the baseline for SoccerNet comparison |

---

## 10. Acceptance Criteria (Pipeline POC)

1. Worker successfully processes a sample match video from VPS storage using stored homography and roster.
2. Output artifact contains time-series player entries with `user_id`, `x`, `y` for identified players at the configured stride.
3. Venue homography is read from venue data; pitch localization and per-frame calibration **do not run**.
4. Job metadata includes `effective_fps` and `wall_clock_seconds`.
5. **`effective_fps` materially exceeds 1.1** on the agreed reference match and hardware, with methodology documented.
6. ReID and OCR association are skipped on frames/tracks that already have a `user_id` mapping — evidenced by `metrics.conditional_steps` counts below naive per-frame totals.
7. Failed runs set `status=failed` with a diagnostic message.

---

## 11. Scope by Product Stage

| Stage | In this spec? |
|-------|----------------|
| **POC** — reconstruction | **Yes** (§1–10) |
| **Thesis scope** — scoring, matchmaking | **No** — separate systems; separate specs/repos; consume artifacts from this pipeline |
| **Deferred** — event detection | **No** — not on roadmap |

### Out of scope (this spec)

- Web upload UI (product spec)
- Venue homography calibration tool
- **Scoring** and **matchmaking** (thesis scope — separate systems, not this pipeline)
- SoccerNet GS-HOTA evaluation harness (optional future benchmark, not POC gate)
- AWS / managed cloud deployment
- Model training and dataset curation (may be separate experiment docs)

---

## 12. Deferred: Event Detection

**Not POC. Not thesis scope as a committed deliverable.**

Event detection (passes, shots, goals, possession, etc.) is something we **would like** eventually. We have **no viable approach** and are **not** designing it now. Reconstruction artifacts must allow **scoring v1 without events**.

---

## 13. Document History

| Version | Date | Changes |
|---------|------|---------|
| 0.1 | 2026-05-23 | Initial spec from design sessions |
| 0.2 | 2026-05-24 | MVP → POC; SoccerNet efficiency challenge; eliminated/conditional steps; VPS replaces cloud |
| 0.3 | 2026-05-24 | Remove ball pipeline claims; scoring/matchmaking → thesis separate systems |
