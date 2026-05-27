# Branching strategy

**Status:** Active  
**Last updated:** 2026-05-27

Sportify is a small monorepo in POC phase. Git workflow stays minimal: one stable integration branch and short-lived experiment branches.

## Branches

| Branch | Purpose | Lifetime |
|--------|---------|----------|
| **`main`** | Default branch. Docs, benchmarks, and pipeline code that represent the current POC baseline. Always safe to clone and run documented workflows. | Permanent |
| **`experiment/<slug>`** | Exploratory work: spikes, benchmarks, and prototypes that may never land on `main`. | Until merged, abandoned, or superseded |

There is no `develop`, release, or long-lived feature branch yet. Add **`feature/<slug>`** only when POC work needs parallel integration that is clearly destined for `main` (not documented here until we use one).

## Naming

- Use **`experiment/`** (singular), not `experiments/`.
- `<slug>` is lowercase **kebab-case** and should match the experiment folder when one exists, e.g. `experiment/easyocr` ↔ `sportify-game-reconstruction/experiments/easyocr/`.
- One experiment → one branch. Do not stack unrelated work on the same `experiment/*` branch.

## Workflow

### Start an experiment

```bash
git checkout main
git pull origin main
git checkout -b experiment/<slug>
```

Implement under the matching path in the repo (typically `sportify-game-reconstruction/experiments/<slug>/`). Commit and push the branch when you need it on another machine (e.g. VPS):

```bash
git push -u origin experiment/<slug>
```

Large or machine-local assets (weights, sample images, datasets) stay **out of git** — same rule as `SPORTIFY_DATA_ROOT` in [repo-structure.md](repo-structure.md).

### Finish an experiment

| Outcome | Action |
|---------|--------|
| **Keep results on `main`** | Open a PR (or merge locally), squash or merge as you prefer, delete `experiment/<slug>`. |
| **Archive without merging** | Document findings in the experiment README, push final commits, delete the branch when done. |
| **Continue later** | Leave the branch on origin; rebase onto `main` before resuming if `main` moved. |

### Day-to-day on `main`

- Direct commits to `main` are acceptable while the team is tiny and velocity matters.
- Prefer **`experiment/*`** when changes are risky, long-running, or only useful for a side comparison (e.g. OCR timing notebooks on a VPS).

## Current branches

| Branch | Notes |
|--------|-------|
| `main` | Tracks `origin/main`. |
| `experiment/easyocr` | EasyOCR jersey OCR spike; code in `sportify-game-reconstruction/experiments/easyocr/`. |

## VPS and multi-machine sync

Clone once, fetch often, checkout the experiment branch on each machine:

```bash
git fetch origin
git checkout experiment/<slug>
git pull
```

Sync untracked experiment assets with `rsync` or scp — see the experiment’s README.

## What we are not doing (yet)

- GitFlow or environment branches (`staging`, `production`)
- Mandatory PR reviews or protected-branch rules (can add on GitHub when collaborators join)
- Version tags or release branches — POC moves fast; tag only when we cut a reproducible benchmark snapshot

When the repo grows (thesis subsystems, CI, external contributors), extend this doc rather than replacing it wholesale.
