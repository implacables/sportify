# Sportify — Product Stages

**Canonical reference.** All other docs use these definitions.

| Stage | Commitment | In reconstruction POC? | Spec / repo |
|-------|------------|--------------------------|-------------|
| **Upload + game-state reconstruction** | **POC — building now** | **Yes** | [Product spec](spec/overview.md) · [Pipeline](../sportify-game-reconstruction/docs/overview.md) |
| **Scoring** | **Thesis scope — separate system** | No | Not written yet |
| **Matchmaking** | **Thesis scope — separate system** | No | Not written yet |
| **Event detection** | **Deferred — want later, no plan** | No | Not on roadmap; no approach selected |

## End-to-end thesis chain

Events are **not** in this chain until we have a viable approach:

```
Upload → Reconstruct → Score → Matchmake
         └─ POC ─┘    └─ thesis (separate systems) ─┘
```

## How to read the labels

### POC (building now)

What we are designing and implementing in the **game reconstruction pipeline**: a **proof of concept** that challenges the [SoccerNet Game State Reconstruction](https://arxiv.org/abs/2404.11335) pipeline on **cost and efficiency at mass scale**.

The POC is **not** a production MVP. It proves that reconstruction can run fast enough and cheaply enough to be viable for amateur football — on a **VPS**, not managed cloud — by eliminating and conditioning steps that make SoccerNet's baseline impractical (~1.1 FPS end-to-end).

See [overview.md](overview.md#poc-objective-challenging-soccernet-gsr) for the performance baseline and success criteria.

### Thesis scope — separate systems (not part of reconstruction POC)

**Scoring** and **matchmaking** are **in scope for the thesis** as their own systems — not part of the `sportify-game-reconstruction` pipeline and not deferred.

- **Scoring** reads reconstruction artifacts and produces player/team skill metrics.
- **Matchmaking** reads scores and pairs players or teams on demand.
- Each will have its own spec and repo (TBD).
- **Scoring v1 must not depend on event detection.**

### Deferred (want later, no commitment)

**Event detection** only (passes, shots, goals, possession, etc.). We would like it eventually. It is **not** in the reconstruction POC, **not** in thesis scope as a committed deliverable, and we have **no selected approach**. It may enrich scoring later; it is not a blocker for v1 scoring.

## What this is not

| Misread | Correct |
|---------|---------|
| “This is a production MVP” | This is a **POC** — efficiency and cost vs SoccerNet GSR, not full product launch. |
| “Scoring is out of thesis scope” | Scoring is **in thesis scope** — as a **separate system**, not in the reconstruction pipeline. |
| “Matchmaking is out of thesis scope” | Matchmaking is **in thesis scope** — as a **separate system**, not in the reconstruction pipeline. |
| “Events are on the roadmap after scoring” | Events are **deferred**, not scheduled. |
| “POC includes the full thesis chain” | POC is **upload + reconstruction only**. |
| “We need AWS for the POC” | POC runs on a **VPS** — no managed cloud overhead during experiments. |
