# SoccerNet Game State Reconstruction — Investigation

**Status:** Reference for Sportify benchmarks  
**Last updated:** 2026-05-24

## Task

[Game State Reconstruction (GSR)](https://www.soccer-net.org/tasks/game-state-reconstruction) compresses broadcast football video into a **minimap** of all individuals on the pitch:

| Output per person | Values |
|-------------------|--------|
| 2D pitch position | meters (`x_bottom_middle`, `y_bottom_middle`) |
| Role | player, goalkeeper, referee, other |
| Team | left / right (camera-relative) |
| Jersey number | integer or null when not visible |

Subtasks in the official baseline: pitch localization, camera calibration, detection, tracking, ReID, jersey OCR, team assignment.

## Dataset: SoccerNet-GS

| Split | Clips | Notes |
|-------|-------|-------|
| train | 57 | Public labels |
| valid | 59 | Public labels |
| test | 50 | Labels withheld — submit predictions |
| challenge | varies | Competition holdout |

- **200 clips** total, **30 seconds** each, **1080p** main broadcast camera
- Annotations: pitch lines, camera calibration, athlete positions with role/team/jersey
- **Version ≥ 1.3** required (temporal bbox-pitch consistency fix)
- Download: [sn-gamestate](https://github.com/SoccerNet/sn-gamestate) auto-download or `SoccerNet` pip package (`gamestate-2024` task)

## Metric: GS-HOTA

Primary evaluation metric ([paper](https://arxiv.org/abs/2404.11335)):

```
Sim_GS-HOTA(P, G) = LocSim(P, G) × IdSim(P, G)
```

- **LocSim:** Gaussian on Euclidean distance in pitch space; τ = 5 m
- **IdSim:** 1 only if **role, team, and jersey** all match; else 0
- Built on HOTA (DetA, AssA) — strict: wrong identity attributes count as false positives

**Baseline GS-HOTA:** 22.26% (validation, full pipeline).

## Official baseline pipeline

Built on [TrackLab](https://github.com/TrackingLaboratory/tracklab) + [sn-gamestate](https://github.com/SoccerNet/sn-gamestate):

| Module | Model / tool |
|--------|----------------|
| Detection | YOLOv11 |
| Pitch + calibration | TVCalib (also PnLCalib / NBJW alternatives) |
| Tracking | StrongSORT |
| ReID | PRTReID |
| Jersey OCR | MMOCR |
| Team | From ReID head |

**End-to-end throughput:** ~**1.1 FPS** on A100 → ~**36 hours** for a 90-minute match.

Every module runs **every frame** in the baseline — the main cost driver Sportify aims to reduce.

## Submission format

Zipped JSON per video (`SNGS-XXX.json`), each detection:

```json
{
  "category_id": 1.0,
  "image_id": "...",
  "track_id": 1,
  "supercategory": "object",
  "confidence": 0.95,
  "attributes": { "role": "player", "jersey": 10, "team": "left" },
  "bbox_pitch": { "x_bottom_middle": 12.3, "y_bottom_middle": 45.6 }
}
```

Evaluation: [sn-trackeval](https://github.com/SoccerNet/sn-trackeval) fork; Codabench / EvalAI for test/challenge.

## Relevance to Sportify POC

| Aspect | SoccerNet GSR | Sportify POC |
|--------|---------------|--------------|
| Camera | Moving broadcast | Fixed elevated side view |
| Calibration | Per-frame TVCalib | **Eliminated** — stored homography |
| OCR / ReID | Every frame | **Conditional** |
| Primary bar | GS-HOTA accuracy | **Throughput / cost** |
| Identity | Jersey + team + role | Roster → `user_id` |
| Infrastructure | Research GPU (A100) | VPS |

**Imperative for POC:** benchmark against this baseline on **throughput** using shared clips where possible; GS-HOTA on a validation subset is optional sanity check, not the POC gate (per [pipeline spec](../../sportify-game-reconstruction/docs/spec/overview.md)).

## References

- Paper: [arXiv:2404.11335](https://arxiv.org/abs/2404.11335)
- Code: [SoccerNet/sn-gamestate](https://github.com/SoccerNet/sn-gamestate)
- Rules: [ChallengeRules.md](https://github.com/SoccerNet/sn-gamestate/blob/main/ChallengeRules.md)
- 2025 competition: [Codabench](https://www.codabench.org/competitions/4469/)
