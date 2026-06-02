# Makefile Migration Design

**Date:** 2026-06-02
**Scope:** Replace user-facing shell scripts with co-located Makefiles across the project.

---

## Files Created / Deleted / Kept

| File | Action |
|---|---|
| `sportify-game-reconstruction/experiments/easyocr/synthetic/Makefile` | Create |
| `sportify-game-reconstruction/experiments/easyocr/soccernet-gs/Makefile` | Create |
| `sportify-game-reconstruction/benchmarks/soccernet-gsr/Makefile` | Create |
| `sportify-game-reconstruction/experiments/easyocr/synthetic/setup.sh` | Delete |
| `sportify-game-reconstruction/experiments/easyocr/soccernet-gs/setup.sh` | Delete |
| `sportify-game-reconstruction/benchmarks/soccernet-gsr/setup-bench.sh` | Keep — private implementation called by Makefile |
| `sportify-game-reconstruction/benchmarks/soccernet-gsr/run-baseline.sh` | Keep — private implementation called by Makefile |
| `scripts/sportify-*.sh` | Keep — sourced libraries, not user-facing |

The experiment `setup.sh` files (~10 lines each) are inlined directly into Makefile recipes. The benchmark scripts (150–200 lines, Python heredocs, config patching, zip extraction) are kept as shell but demoted to internal implementation — the Makefile becomes the documented interface. The benchmark scripts are not renamed or moved; they are simply no longer referenced in docs.

---

## Experiment Makefiles

Applies to both `synthetic/Makefile` and `soccernet-gs/Makefile`. The only difference between them is `KERNEL_NAME` and `KERNEL_DISPLAY`.

### Targets

| Target | Description |
|---|---|
| `setup` | Default. Requirements check → create `.venv` → install deps → register kernel. |
| `dry-run` | Check `uv` present, find Python 3.11, report venv state. No changes. |
| `clean` | Remove `.venv/`. |

### Idempotency

`.venv/pyvenv.cfg` is declared as a Make file target depending on `requirements.txt`. Make skips venv creation if `.venv/pyvenv.cfg` is newer than `requirements.txt`. Re-running `make setup` after a dep change triggers a clean reinstall.

### Requirements check

Called via a single bash invocation to source the library:

```bash
bash -c 'source $(REPO_ROOT)/scripts/sportify-check-requirements.sh && sportify_check_requirements easyocr || exit 1'
```

### Dry-run behaviour

Prints:
- `uv` version (exits with error if missing)
- Python 3.11 status (`found` / `WARNING: not installed`)
- Venv state (`exists` / `will create`)
- Kernel name that would be registered
- `==> No changes made`

---

## Benchmark Makefile

Located at `sportify-game-reconstruction/benchmarks/soccernet-gsr/Makefile`. Wraps `setup-bench.sh` and `run-baseline.sh`.

### Targets

| Target | Description |
|---|---|
| `setup` | Default. Calls `setup-bench.sh` with translated flags. |
| `run` | Calls `run-baseline.sh` with translated flags. |
| `dry-run` | Prints resolved variables, checks `uv`/`git` present, calls `run-baseline.sh --dry-run`. |

### Variables

| Variable | Replaces | Default |
|---|---|---|
| `DATA_ROOT` | `--data-root` | Auto-detected (`/workspace` if present, else `~/data/sportify`) |
| `SPLIT` | `--split` | `valid` |
| `SKIP_DOWNLOAD` | `--skip-download` | unset (false) |
| `LOW_VRAM` | `--low-vram` | unset (false) |
| `MANIFEST` | `--manifest` | `$(CURDIR)/manifests/valid-quick.yaml` |

Pass overrides on the command line: `make setup DATA_ROOT=~/data SPLIT=train LOW_VRAM=1`.

Boolean flags (`SKIP_DOWNLOAD`, `LOW_VRAM`) are passed through only when set to a non-empty value:

```makefile
$(if $(SKIP_DOWNLOAD),--skip-download) \
$(if $(LOW_VRAM),--low-vram)
```

### Dry-run behaviour

Prints:
- Resolved `DATA_ROOT`, `SPLIT`, `MANIFEST`
- `uv` and `git` present/missing
- The exact `run-baseline.sh` command that would execute
- Calls `run-baseline.sh --dry-run` to validate the run path (already supported by that script)

---

## Testing

### Experiment Makefiles

Tested end-to-end in the project worktree:

1. `make dry-run` — verify output, exit 0
2. `make setup` — verify `.venv/pyvenv.cfg` exists, verify kernel appears in `jupyter kernelspec list`
3. Re-run `make setup` — verify it skips venv creation (idempotency)
4. `make clean` — verify `.venv/` removed

### Benchmark Makefile

Tested with `make dry-run` only (GPU and dataset not available in this environment):

1. `make dry-run` — verify output, exit 0
2. `make dry-run DATA_ROOT=/tmp/test SPLIT=train LOW_VRAM=1` — verify variable translation in output
3. Inspect generated flag strings for correctness

Live `make setup` and `make run` are deferred to a GPU machine.
