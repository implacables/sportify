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
