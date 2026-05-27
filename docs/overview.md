# Sportify — Project Overview

**Status:** Active design  
**Last updated:** 2026-05-24

> **Product stages:** See [product-stages.md](product-stages.md) for the canonical POC vs thesis scope vs deferred definitions.

## Product Stages (summary)

| Stage | Commitment |
|-------|------------|
| Upload + reconstruction | **POC — building now** |
| Scoring | **Thesis scope — separate system** |
| Matchmaking | **Thesis scope — separate system** |
| Event detection | **Deferred — want later, no plan** |

## What Sportify Is

Sportify is a product for **amateur football**. It aims to make matches fairer and easier to organize by measuring player and team skill from match video, then using those signals for **scoring** and **matchmaking**.

The **POC** is upload and game-state reconstruction only (see [POC Scope](#poc-scope)). **Scoring** and **matchmaking** are **in scope for the thesis** as separate systems—not part of the reconstruction pipeline, and not deferred. **Event detection** is the only deferred capability (see [Deferred: Event Detection](#deferred-event-detection)).

Today, amateur games depend on informal knowledge: captains who know players, venues that guess team levels, and word of mouth. That does not scale and leaves new players without a reliable way to find appropriately matched games.

Sportify proposes a data-driven alternative: record a match, reconstruct who is where on the pitch, derive skill scores, and match players and teams of similar level.

## POC Objective: Challenging SoccerNet GSR

The POC exists to challenge the [SoccerNet Game State Reconstruction](https://arxiv.org/abs/2404.11335) baseline on **cost and efficiency at mass scale**.

SoccerNet's published end-to-end pipeline runs at roughly **~1.1 FPS** on an A100 GPU. For a typical **~90-minute** amateur match, that implies **under ~36 hours of GPU time per job** — a critical barrier to any product that must process many matches affordably.

| Metric | SoccerNet GSR baseline | POC target |
|--------|------------------------|------------|
| End-to-end throughput | ~1.1 FPS | **Significantly faster** (exact target TBD as pipeline is built) |
| ~90 min match wall time | ~36 hours | **Hours, not days** — TBD |
| Infrastructure | Research GPU (A100) | **VPS** with consumer/rented GPU |
| Per-frame pitch calibration | Yes (TVCalib) | **Eliminated** — fixed camera + stored homography |
| Cost model | Impractical at mass scale | **Experiment-friendly** — no cloud overhead |

The POC does **not** need to beat SoccerNet on GS-HOTA accuracy. It must demonstrate that reconstruction is **fast and cheap enough** to be viable for amateur football at scale, with acceptable output for downstream scoring.

### Why SoccerNet is slow (and what we change)

SoccerNet GSR runs six heavy modules every frame, including per-frame pitch localization and camera calibration. Our amateur context — **elevated fixed side-view camera, venue setup once** — allows a leaner pipeline:

| SoccerNet module | POC disposition | Rationale |
|------------------|-----------------|-----------|
| Player detection | **Always run** | Core output |
| Pitch localization (TVCalib) | **Eliminated** | Homography computed at venue setup, not per frame |
| Camera calibration (TVCalib) | **Eliminated** | Stored homography reused for every match at that venue |
| Multi-object tracking | **Always run** | Temporal continuity before identity |
| Identity mapping lookup | **Always run** | Per track: if already mapped to `user_id`, skip association |
| Re-identification (PRTReID) | **Conditional** | Run with jersey OCR when track is not yet mapped to `user_id` |
| Jersey OCR (MMOCR) | **Conditional** | Run with ReID when track is not yet mapped to `user_id` |
| Event detection | **Out of scope** | Deferred entirely |

Exact conditional triggers are pipeline design items; see [sportify-game-reconstruction/docs/spec/overview.md](../sportify-game-reconstruction/docs/spec/overview.md).

## The Problem

| Pain point | Why it matters |
|------------|----------------|
| Manual organization | Captains spend time finding players, rivals, times, and pitches |
| Subjective skill assessment | Venues and leaders know some teams; new players are invisible |
| Mismatched games | Uneven matches are less fun for both sides |
| No scalable measurement | There is no objective, automated way to score amateur players from video |
| Reconstruction too slow | SoccerNet-class pipelines take ~36 hours per 90-min match — unusable at scale |

## POC Scope

**Label: POC — building now.**

The POC is two linked capabilities, run on a **VPS**:

```
Upload match video → Reconstruct game state (efficiently)
```

Upload and job orchestration are lightweight services on the VPS. Reconstruction is GPU batch work on the same machine (or attached GPU). Scoring and matchmaking are separate thesis systems—not part of this pipeline.

**Infrastructure:** VPS-first. Managed cloud (AWS S3, Batch, etc.) is **explicitly out of scope** for the POC so experiments can run freely without cloud billing overhead.

## Thesis Architecture

Sportify is built as a chain of distinct stages—not one monolithic pipeline:

```
Upload match video → Reconstruct game state → Score players → Matchmake on demand
```

| Stage | Commitment |
|-------|------------|
| Upload + reconstruction | **POC** — building now (`sportify-game-reconstruction`) |
| Scoring | **Thesis scope** — separate system; consumes reconstruction artifacts |
| Matchmaking | **Thesis scope** — separate system; consumes scores |

Each stage has different latency, cost, and infrastructure needs. Only reconstruction is in the current POC.

## Deferred: Event Detection

**Label: Deferred — want later, no plan (not POC, not in thesis scope).**

**Event detection** (passes, shots, goals, possession changes, etc.) is something we **would like to have** eventually. It is:

- **Not** part of the POC
- **Not** in thesis scope as a committed deliverable
- **Not** something we are designing or scheduling now
- **Without** a viable approach today

Scoring v1 and matchmaking shall work from **reconstruction artifacts** (and scores). Events may enrich them later if we find a workable solution—they are **not** a dependency for v1.

## Target Context

Sportify is designed for **amateur football**, not broadcast or professional analytics:

- **DJI Osmo 360** as the intended match camera — see [hardware/dji-osmo-360.md](hardware/dji-osmo-360.md)
- Fixed **elevated side-view** mount (flat MP4 export from single-lens or reframed capture)
- Imperfect video quality and occasional occlusions
- **VPS-scale** infrastructure — thesis/demo budget, not AWS at scale
- Need for a **defensible POC**, not a research demo that cannot run in reasonable time

## Major Subsystems

| Subsystem | Purpose | Stage | Repo / location |
|-----------|---------|-------|-----------------|
| **Game reconstruction** | Per-*k*-frame player positions and identities | **POC** | `sportify-game-reconstruction` |
| **Web & upload** | Match video upload; storage and job orchestration on VPS | **POC** | TBD |
| **Scoring** | Player/team skill metrics from reconstruction artifacts | **Thesis — separate system** | TBD |
| **Matchmaking** | Pair users/teams on demand from stored scores | **Thesis — separate system** | TBD |
| **Event detection** | Passes, shots, goals, possession, etc. | **Deferred** | — |

Detailed pipeline design lives in the reconstruction repo. This document stays at product level.

## Users & Stakeholders

- **Players** — upload or associate with match footage; receive skill profile; find fair matches
- **Team organizers** — manage rosters and match submissions
- **Venues** — one-time field setup (dimensions, homography)
- **Thesis evaluators** — need a coherent, modular architecture with measurable outputs — including **processing time vs SoccerNet baseline**

## Design Principles

1. **Efficiency first (POC)** — Beat SoccerNet's ~1.1 FPS wall; mass scale is impossible otherwise.
2. **Eliminate what context gives us** — No per-frame pitch localization or calibration when homography is known at setup.
3. **Conditional heavy steps** — ReID and jersey OCR run only for unmapped tracks, not on every frame by default.
4. **Modular stages** — Each step has clear inputs, outputs, and failure modes; components can be swapped or evaluated independently.
5. **VPS, not cloud** — POC runs on a rented VPS for cheap, unconstrained experimentation.
6. **Setup vs match runtime** — Venue calibration (homography, dimensions) happens once and is reused; it is not recomputed every frame or every match.
7. **Honest scope** — POC is reconstruction only; scoring and matchmaking are separate thesis systems.
8. **Clean documentation** — Prior specs from other repos are not authoritative; this tree is the source of truth going forward.

## Presentation & Demo Strategy

The POC may be shown on the **same VPS** used for development. Depending on achieved processing speeds:

- **If fast enough:** demonstrate live or near-live reconstruction during the presentation.
- **If still too slow for a live audience:** use a **presentation workaround** — show processing as if real-time while the displayed output comes from a **pre-processed** run, to respect evaluators' time without misrepresenting the system's eventual capability.

The honest metric for the thesis is **measured wall-clock throughput** on representative match footage, compared against the SoccerNet ~1.1 FPS / ~36-hour baseline.

## Current Status

- **Game reconstruction** — POC; in active design (no implementation yet in this repo).
- **Scoring** — thesis scope; separate system; spec not written yet.
- **Matchmaking** — thesis scope; separate system; spec not written yet.
- **Event detection** — deferred only; want later; no approach selected; **not on roadmap**.
- **Infrastructure** — VPS-first; cloud architecture **deprecated** for POC.

## Related Documents

| Document | Location |
|----------|----------|
| **Product stages (canonical)** | [product-stages.md](product-stages.md) |
| **Match camera (DJI Osmo 360)** | [hardware/dji-osmo-360.md](hardware/dji-osmo-360.md) |
| Product specification | [spec/overview.md](spec/overview.md) |
| Pipeline overview | [../sportify-game-reconstruction/docs/overview.md](../sportify-game-reconstruction/docs/overview.md) |
| Pipeline specification | [../sportify-game-reconstruction/docs/spec/overview.md](../sportify-game-reconstruction/docs/spec/overview.md) |
