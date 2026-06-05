MAKEFILE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
REPO_ROOT    := $(abspath $(MAKEFILE_DIR)/../../..)

DATA_ROOT ?= $(shell bash -c 'source "$(REPO_ROOT)/scripts/sportify-default-data-root.sh" \
               && sportify_default_data_root')
MANIFEST  ?= $(MAKEFILE_DIR)/manifests/valid-quick.yaml
MODEL     ?= yolo11n.pt
IMGSZ     ?= 640
BATCH     ?= 1

VENV_PYTHON := $(DATA_ROOT)/vendor/yolo-bench/.venv/bin/python

.PHONY: setup convert bench eval dry-run

setup:
	bash "$(MAKEFILE_DIR)/setup-bench.sh" \
		--data-root "$(DATA_ROOT)"

convert:
	"$(VENV_PYTHON)" "$(MAKEFILE_DIR)/convert_to_yolo.py" \
		--data-root "$(DATA_ROOT)" \
		--manifest "$(MANIFEST)"

bench:
	bash "$(MAKEFILE_DIR)/run-bench.sh" \
		--manifest "$(MANIFEST)" \
		--model "$(MODEL)" \
		--imgsz "$(IMGSZ)" \
		--batch "$(BATCH)"

eval:
	bash "$(MAKEFILE_DIR)/run-eval.sh" \
		--manifest "$(MANIFEST)" \
		--model "$(MODEL)" \
		--imgsz "$(IMGSZ)"

dry-run:
	@echo "==> Dry run: yolo-soccernet benchmark"
	@echo "  REPO_ROOT: $(REPO_ROOT)"
	@echo "  DATA_ROOT: $(DATA_ROOT)"
	@echo "  MANIFEST:  $(MANIFEST)"
	@echo "  MODEL:     $(MODEL)"
	@echo "  IMGSZ:     $(IMGSZ)"
	@echo "  BATCH:     $(BATCH)"
	@command -v uv >/dev/null 2>&1 \
		&& echo "  uv: $$(uv --version)" \
		|| { echo "ERROR: uv not found — https://docs.astral.sh/uv/"; exit 1; }
	@test -f "$(VENV_PYTHON)" \
		&& echo "  venv: found" \
		|| echo "  venv: NOT FOUND — run: make setup"
	@test -f "$(DATA_ROOT)/yolo-soccernet/data.yaml" \
		&& echo "  data.yaml: found" \
		|| echo "  data.yaml: NOT FOUND — run: make convert"
	@bash "$(MAKEFILE_DIR)/run-bench.sh" \
		--manifest "$(MANIFEST)" \
		--model "$(MODEL)" \
		--imgsz "$(IMGSZ)" \
		--batch "$(BATCH)" \
		--dry-run
	@echo "==> No changes made"
