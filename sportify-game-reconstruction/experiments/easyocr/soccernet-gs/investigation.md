# SoccerNet-GS — Jersey OCR benchmark design

**Status:** Reference for EasyOCR on SoccerNet-GS crops  
**Last updated:** 2026-05-27

## Dataset shape (relevant fields)

Same on-disk tree as [YOLO investigation](../../../../benchmarks/yolo-soccernet/investigation.md): `$SPORTIFY_DATA_ROOT/SoccerNetGS/{split}/{SNGS-XXX}/img1/` + `Labels-GameState.json`.

| Property | Value |
|----------|-------|
| Frames / clip | 750 @ 25 FPS, 1920×1080 |
| Object annotations | COCO-style `bbox_image` + `attributes` |

### Jersey ground truth

`attributes.jersey` is a string digit label (e.g. `"10"`) or missing/null.

**Important (SNGS-021):** parseable jersey labels appear **only on `category_id == 1` (player)**. Goalkeeper, referee, and other boxes have `jersey: null` — they are not used as positive OCR samples.

| Split | Labeled clips | Use for bench |
|-------|---------------|---------------|
| valid | 59 | **Default** — public labels |
| train | 57 | Optional fine-tune / extra eval |
| test | 50 | Labels withheld |

Roughly **40–45%** of player box instances carry a jersey label in a typical clip; the rest are null (occlusion, back to camera, etc.).

### Crop geometry

Median labeled player crop (image bbox): ~61×129 px. Full-frame OCR without crop fails; the bench **crops `bbox_image` with padding** then applies the same `IMAGE_SCALE` upscale as the screenshot experiments.

## Benchmark protocol

1. Load clip list from [`benchmarks/soccernet-gsr/manifests/valid-quick.yaml`](../../../../benchmarks/soccernet-gsr/manifests/valid-quick.yaml) (or override `CLIP_IDS`).
2. For each clip, walk frames with `FRAME_STRIDE` (default 25 → 1 Hz).
3. **Positive samples:** `category_id == 1` and parseable `attributes.jersey`.
4. **Negative samples (optional):** `category_id == 1` and null jersey — measure digit false positives on players without GT number.
5. Run EasyOCR on each crop; compare parsed digits to GT.

## Metrics

| Metric | Definition |
|--------|------------|
| **Jersey accuracy** | % positive crops where predicted digits == GT |
| **Miss rate** | % positive crops with no digit detected |
| **Wrong digit rate** | % positive with digits but ≠ GT |
| **FP on null-jersey players** | % negative crops where any digit detected |
| **Throughput** | ms/crop, crops/s |

Not GS-HOTA: this isolates **image-space jersey OCR** on GT boxes (oracle detection), comparable in spirit to conditional OCR in the Sportify pipeline but without tracking.

## Baseline context

Official GSR uses **MMOCR** every frame (~1.1 FPS full pipeline). This bench measures **EasyOCR** only on labeled crops to inform whether EasyOCR is viable before integration.

## Setup

Requires **`SPORTIFY_DATA_ROOT`** (default `~/data/sportify`). SoccerNet files: `$SPORTIFY_DATA_ROOT/SoccerNetGS/`. See [docs/data-layout.md](../../../../docs/data-layout.md).

Download valid split: [benchmarks/soccernet-gsr/setup-bench.sh](../../../../benchmarks/soccernet-gsr/setup-bench.sh).
