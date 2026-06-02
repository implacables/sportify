# Makefile Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace user-facing shell scripts with co-located Makefiles providing `setup`, `dry-run`, and `clean` (or `run`) targets, then update all docs to reference `make` instead of `./script.sh`.

**Architecture:** Three co-located Makefiles — two experiment Makefiles inline the ~10-line venv setup logic directly; the benchmark Makefile wraps the existing complex shell scripts as private implementation. Each Makefile uses file-timestamp tracking for idempotency and a `dry-run` target that makes no changes.

**Tech Stack:** GNU Make, uv, bash, `scripts/sportify-check-requirements.sh` (sourced library)

---

## File Map

| Action | Path |
|---|---|
| Create | `sportify-game-reconstruction/experiments/easyocr/synthetic/Makefile` |
| Delete | `sportify-game-reconstruction/experiments/easyocr/synthetic/setup.sh` |
| Create | `sportify-game-reconstruction/experiments/easyocr/soccernet-gs/Makefile` |
| Delete | `sportify-game-reconstruction/experiments/easyocr/soccernet-gs/setup.sh` |
| Create | `sportify-game-reconstruction/benchmarks/soccernet-gsr/Makefile` |
| Modify | `sportify-game-reconstruction/experiments/easyocr/README.md` |
| Modify | `sportify-game-reconstruction/experiments/easyocr/soccernet-gs/README.md` |
| Modify | `sportify-game-reconstruction/benchmarks/soccernet-gsr/README.md` |
| Modify | `docs/data-layout.md` |
| Modify | `docs/branching-strategy.md` |
| Modify | `docs/superpowers/specs/2026-06-02-makefile-migration-design.md` |

---

## Task 1: Experiment Makefile — synthetic/

**Files:**
- Create: `sportify-game-reconstruction/experiments/easyocr/synthetic/Makefile`
- Delete: `sportify-game-reconstruction/experiments/easyocr/synthetic/setup.sh`

- [ ] **Step 1.1: Create the Makefile**

Create `sportify-game-reconstruction/experiments/easyocr/synthetic/Makefile` with this exact content (tabs required for recipe lines):

```makefile
MAKEFILE_DIR  := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
REPO_ROOT     := $(abspath $(MAKEFILE_DIR)/../../../..)
KERNEL_NAME   := sportify-easyocr-synthetic
KERNEL_DISPLAY := Sportify EasyOCR synthetic

.PHONY: setup dry-run clean

setup: .venv/pyvenv.cfg
	.venv/bin/python -m ipykernel install --user \
		--name $(KERNEL_NAME) \
		--display-name "$(KERNEL_DISPLAY)"
	@echo "Done. source .venv/bin/activate"

.venv/pyvenv.cfg: requirements.txt
	bash -c 'source "$(REPO_ROOT)/scripts/sportify-check-requirements.sh" && \
		sportify_check_requirements easyocr || exit 1'
	uv venv --python 3.11
	uv pip install -r requirements.txt

dry-run:
	@echo "==> Dry run: $(KERNEL_DISPLAY)"
	@command -v uv >/dev/null 2>&1 \
		|| { echo "ERROR: uv not found — https://docs.astral.sh/uv/"; exit 1; }
	@echo "  uv: $$(uv --version)"
	@uv python find 3.11 >/dev/null 2>&1 \
		&& echo "  Python 3.11: $$(uv python find 3.11)" \
		|| echo "  WARNING: Python 3.11 not installed (run: uv python install 3.11)"
	@echo "  venv: .venv/ ($$(test -d .venv && echo 'exists' || echo 'will create'))"
	@echo "  kernel: $(KERNEL_NAME)"
	@echo "==> No changes made"

clean:
	rm -rf .venv
```

- [ ] **Step 1.2: Run dry-run — verify it exits 0 and prints expected output**

```bash
cd sportify-game-reconstruction/experiments/easyocr/synthetic
make dry-run
```

Expected output (exact lines may vary by environment):
```
==> Dry run: Sportify EasyOCR synthetic
  uv: uv 0.x.x
  Python 3.11: /path/to/python3.11
  venv: .venv/ (will create)
  kernel: sportify-easyocr-synthetic
==> No changes made
```
Exit code: 0. No `.venv/` directory created.

- [ ] **Step 1.3: Run setup — verify venv and kernel are created**

```bash
make setup
```

Expected:
- No errors
- `.venv/pyvenv.cfg` exists
- `jupyter kernelspec list` contains `sportify-easyocr-synthetic`

Verify:
```bash
test -f .venv/pyvenv.cfg && echo "venv OK"
jupyter kernelspec list | grep sportify-easyocr-synthetic && echo "kernel OK"
```

- [ ] **Step 1.4: Run setup again — verify idempotency (no reinstall)**

```bash
time make setup
```

Expected: completes in under 3 seconds (skips venv creation, only re-registers kernel).

- [ ] **Step 1.5: Verify requirements.txt change triggers reinstall**

```bash
touch requirements.txt
make setup
```

Expected: re-runs `uv venv` and `uv pip install` (`.venv/pyvenv.cfg` is older than `requirements.txt`).

- [ ] **Step 1.6: Run clean — verify .venv removed**

```bash
make clean
test ! -d .venv && echo "clean OK"
```

- [ ] **Step 1.7: Delete setup.sh**

```bash
git rm sportify-game-reconstruction/experiments/easyocr/synthetic/setup.sh
```

- [ ] **Step 1.8: Commit**

```bash
git add sportify-game-reconstruction/experiments/easyocr/synthetic/Makefile
git commit -m "Add Makefile for easyocr/synthetic experiment; remove setup.sh"
```

---

## Task 2: Experiment Makefile — soccernet-gs/

**Files:**
- Create: `sportify-game-reconstruction/experiments/easyocr/soccernet-gs/Makefile`
- Delete: `sportify-game-reconstruction/experiments/easyocr/soccernet-gs/setup.sh`

- [ ] **Step 2.1: Create the Makefile**

Create `sportify-game-reconstruction/experiments/easyocr/soccernet-gs/Makefile` — identical to Task 1 except `KERNEL_NAME` and `KERNEL_DISPLAY`:

```makefile
MAKEFILE_DIR  := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
REPO_ROOT     := $(abspath $(MAKEFILE_DIR)/../../../..)
KERNEL_NAME   := sportify-easyocr-soccernet-gs
KERNEL_DISPLAY := Sportify EasyOCR SoccerNet-GS

.PHONY: setup dry-run clean

setup: .venv/pyvenv.cfg
	.venv/bin/python -m ipykernel install --user \
		--name $(KERNEL_NAME) \
		--display-name "$(KERNEL_DISPLAY)"
	@echo "Done. source .venv/bin/activate"

.venv/pyvenv.cfg: requirements.txt
	bash -c 'source "$(REPO_ROOT)/scripts/sportify-check-requirements.sh" && \
		sportify_check_requirements easyocr || exit 1'
	uv venv --python 3.11
	uv pip install -r requirements.txt

dry-run:
	@echo "==> Dry run: $(KERNEL_DISPLAY)"
	@command -v uv >/dev/null 2>&1 \
		|| { echo "ERROR: uv not found — https://docs.astral.sh/uv/"; exit 1; }
	@echo "  uv: $$(uv --version)"
	@uv python find 3.11 >/dev/null 2>&1 \
		&& echo "  Python 3.11: $$(uv python find 3.11)" \
		|| echo "  WARNING: Python 3.11 not installed (run: uv python install 3.11)"
	@echo "  venv: .venv/ ($$(test -d .venv && echo 'exists' || echo 'will create'))"
	@echo "  kernel: $(KERNEL_NAME)"
	@echo "==> No changes made"

clean:
	rm -rf .venv
```

- [ ] **Step 2.2: Run dry-run — verify it exits 0**

```bash
cd sportify-game-reconstruction/experiments/easyocr/soccernet-gs
make dry-run
```

Expected: same structure as Task 1 with kernel name `sportify-easyocr-soccernet-gs`. Exit code 0.

- [ ] **Step 2.3: Run setup — verify venv and kernel are created**

```bash
make setup
test -f .venv/pyvenv.cfg && echo "venv OK"
jupyter kernelspec list | grep sportify-easyocr-soccernet-gs && echo "kernel OK"
```

- [ ] **Step 2.4: Run setup again — verify idempotency**

```bash
time make setup
```

Expected: under 3 seconds.

- [ ] **Step 2.5: Run clean — verify .venv removed**

```bash
make clean
test ! -d .venv && echo "clean OK"
```

- [ ] **Step 2.6: Delete setup.sh**

```bash
git rm sportify-game-reconstruction/experiments/easyocr/soccernet-gs/setup.sh
```

- [ ] **Step 2.7: Commit**

```bash
git add sportify-game-reconstruction/experiments/easyocr/soccernet-gs/Makefile
git commit -m "Add Makefile for easyocr/soccernet-gs experiment; remove setup.sh"
```

---

## Task 3: Benchmark Makefile — benchmarks/soccernet-gsr/

**Files:**
- Create: `sportify-game-reconstruction/benchmarks/soccernet-gsr/Makefile`
- `setup-bench.sh` and `run-baseline.sh` remain as private implementation (not deleted)

- [ ] **Step 3.1: Create the Makefile**

Create `sportify-game-reconstruction/benchmarks/soccernet-gsr/Makefile`:

```makefile
MAKEFILE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
REPO_ROOT    := $(abspath $(MAKEFILE_DIR)/../../..)

DATA_ROOT    ?= $(shell bash -c 'source "$(REPO_ROOT)/scripts/sportify-default-data-root.sh" \
                  && sportify_default_data_root')
SPLIT        ?= valid
MANIFEST     ?= $(MAKEFILE_DIR)/manifests/valid-quick.yaml

.PHONY: setup run dry-run

setup:
	bash "$(MAKEFILE_DIR)/setup-bench.sh" \
		--data-root "$(DATA_ROOT)" \
		--split "$(SPLIT)" \
		$(if $(SKIP_DOWNLOAD),--skip-download) \
		$(if $(LOW_VRAM),--low-vram)

run:
	bash "$(MAKEFILE_DIR)/run-baseline.sh" \
		--manifest "$(MANIFEST)"

dry-run:
	@echo "==> Dry run: soccernet-gsr benchmark"
	@echo "  REPO_ROOT:  $(REPO_ROOT)"
	@echo "  DATA_ROOT:  $(DATA_ROOT)"
	@echo "  SPLIT:      $(SPLIT)"
	@echo "  MANIFEST:   $(MANIFEST)"
	@test -n "$(SKIP_DOWNLOAD)" && echo "  --skip-download: yes" || true
	@test -n "$(LOW_VRAM)"      && echo "  --low-vram: yes"      || true
	@command -v uv >/dev/null 2>&1 \
		&& echo "  uv: $$(uv --version)" \
		|| { echo "ERROR: uv not found — https://docs.astral.sh/uv/"; exit 1; }
	@command -v git >/dev/null 2>&1 \
		&& echo "  git: $$(git --version)" \
		|| { echo "ERROR: git not found"; exit 1; }
	@echo "  run command: bash $(MAKEFILE_DIR)/run-baseline.sh --manifest $(MANIFEST) --dry-run"
	@bash "$(MAKEFILE_DIR)/run-baseline.sh" --manifest "$(MANIFEST)" --dry-run
	@echo "==> No changes made"
```

- [ ] **Step 3.2: Run dry-run with defaults — verify output and exit 0**

```bash
cd sportify-game-reconstruction/benchmarks/soccernet-gsr
make dry-run
```

Expected output includes:
```
==> Dry run: soccernet-gsr benchmark
  REPO_ROOT:  /path/to/sportify
  DATA_ROOT:  /workspace   (or ~/data/sportify)
  SPLIT:      valid
  MANIFEST:   /path/to/.../manifests/valid-quick.yaml
  uv: uv 0.x.x
  git: git version x.x.x
  run command: ...run-baseline.sh --manifest ... --dry-run
dry-run: would run tracklab in ...
==> No changes made
```

Exit code: 0.

- [ ] **Step 3.3: Run dry-run with overrides — verify variable translation**

```bash
make dry-run DATA_ROOT=/tmp/test-data SPLIT=train SKIP_DOWNLOAD=1 LOW_VRAM=1
```

Expected output includes:
```
  DATA_ROOT:  /tmp/test-data
  SPLIT:      train
  --skip-download: yes
  --low-vram: yes
```

Exit code: 0.

- [ ] **Step 3.4: Commit**

```bash
git add sportify-game-reconstruction/benchmarks/soccernet-gsr/Makefile
git commit -m "Add Makefile for soccernet-gsr benchmark"
```

---

## Task 4: Update docs

**Files:**
- Modify: `sportify-game-reconstruction/experiments/easyocr/README.md`
- Modify: `sportify-game-reconstruction/experiments/easyocr/soccernet-gs/README.md`
- Modify: `sportify-game-reconstruction/benchmarks/soccernet-gsr/README.md`
- Modify: `docs/data-layout.md`
- Modify: `docs/branching-strategy.md`
- Modify: `docs/superpowers/specs/2026-06-02-makefile-migration-design.md`

- [ ] **Step 4.1: Update experiments/easyocr/README.md — replace setup.sh with make**

Change the `## Run` section from:

```bash
cd sportify-game-reconstruction/experiments/easyocr/synthetic   # or soccernet-gs
./setup.sh
source .venv/bin/activate
jupyter notebook *.ipynb
```

To:

```bash
cd sportify-game-reconstruction/experiments/easyocr/synthetic   # or soccernet-gs
make setup
source .venv/bin/activate
jupyter notebook *.ipynb
```

Also add a note about `make dry-run` and `make clean`:

```
Run `make dry-run` to check prerequisites without installing anything.
Run `make clean` to remove the venv.
```

- [ ] **Step 4.2: Update soccernet-gs/README.md — replace setup.sh with make**

In the `## Run notebook` section, change:

```bash
./setup.sh && source .venv/bin/activate
```

To:

```bash
make setup && source .venv/bin/activate
```

- [ ] **Step 4.3: Update benchmarks/soccernet-gsr/README.md — replace script calls with make**

Replace all `./benchmarks/soccernet-gsr/setup-bench.sh` invocations with `make setup` (from the benchmark directory), and `./benchmarks/soccernet-gsr/run-baseline.sh` with `make run`. Add a variable reference table.

Exact replacements — in the Quick start section:

```bash
# Before
./benchmarks/soccernet-gsr/setup-bench.sh
./benchmarks/soccernet-gsr/setup-bench.sh --low-vram

# After
cd sportify-game-reconstruction/benchmarks/soccernet-gsr
make setup
make setup LOW_VRAM=1
```

Run section:
```bash
# Before
./benchmarks/soccernet-gsr/run-baseline.sh --manifest benchmarks/soccernet-gsr/manifests/valid-quick.yaml

# After
make run
make run MANIFEST=manifests/valid-quick.yaml
```

Add a variables table after the targets:
```
| Variable | Default | Purpose |
|---|---|---|
| `DATA_ROOT` | auto (`/workspace` or `~/data/sportify`) | SoccerNet data location |
| `SPLIT` | `valid` | Dataset split |
| `SKIP_DOWNLOAD` | unset | Set to `1` to skip dataset download |
| `LOW_VRAM` | unset | Set to `1` to patch batch sizes for ≤8 GB VRAM |
| `MANIFEST` | `manifests/valid-quick.yaml` | Clip manifest for `make run` |
```

- [ ] **Step 4.4: Update docs/data-layout.md — prefer make setup**

In the "Method A — Sportify script" section, replace the direct script calls with `make setup`. Keep the script name as a parenthetical for reference since it still works.

Change:
```bash
sportify-game-reconstruction/benchmarks/soccernet-gsr/setup-bench.sh
```
To:
```bash
cd sportify-game-reconstruction/benchmarks/soccernet-gsr && make setup
```

For the flag variants, use Make variables:
```bash
make setup DATA_ROOT=/mnt/data/sportify
make setup SPLIT=train
make setup SKIP_DOWNLOAD=1
make setup LOW_VRAM=1
```

- [ ] **Step 4.5: Update docs/branching-strategy.md — remove merged experiment/easyocr branch**

In the `## Current branches` table, remove or update the `experiment/easyocr` row — that branch was merged and deleted. If no other active experiment branches exist, replace the table with:

```
No active experiment branches at this time.
```

- [ ] **Step 4.6: Mark the design spec complete**

Add a status line at the top of `docs/superpowers/specs/2026-06-02-makefile-migration-design.md`:

```
**Status:** Implemented — 2026-06-02
```

- [ ] **Step 4.7: Commit**

```bash
git add \
  sportify-game-reconstruction/experiments/easyocr/README.md \
  sportify-game-reconstruction/experiments/easyocr/soccernet-gs/README.md \
  sportify-game-reconstruction/benchmarks/soccernet-gsr/README.md \
  docs/data-layout.md \
  docs/branching-strategy.md \
  docs/superpowers/specs/2026-06-02-makefile-migration-design.md
git commit -m "Update docs to reference make targets instead of shell scripts"
```
