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
