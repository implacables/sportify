# SoccerNet-GS — Dataset Structure for YOLO Person Detection

**Status:** Reference for YOLO benchmark track  
**Last updated:** 2026-05-27

Factual reference for converting SoccerNet Game State (GS) labels into YOLO training/eval datasets. Normative requirements live in [spec.md](spec.md).

**Full GSR context:** [SoccerNet GSR investigation](../soccernet-gsr/investigation.md) (GS-HOTA, full baseline pipeline, pitch-space eval).

---

## On-disk layout

Dataset root: `$SPORTIFY_DATA_ROOT/SoccerNetGS` (default `~/data/sportify/SoccerNetGS`).

```
SoccerNetGS/
├── sequences_info.json       # index of clip IDs per split (train / valid / test / challenge)
├── gamestate-2024/           # downloaded zips (optional after extract)
├── train/
│   └── SNGS-XXX/
├── valid/
│   └── SNGS-XXX/
│       ├── img1/
│       │   ├── 000001.jpg … 000750.jpg
│       └── Labels-GameState.json
└── test/                     # images only — labels withheld
```

Each labeled clip is self-contained: one JSON file plus one image subfolder (`img1/` by default).

| Property | Value |
|----------|-------|
| Clip duration | 30 s |
| Frames per clip | 750 |
| Frame rate | 25 FPS |
| Resolution | 1920 × 1080 RGB JPEG |
| Dataset version | **≥ 1.3** required (temporal bbox–pitch consistency fix) |

**Split sizes (public labels):**

| Split | Clips | Labels |
|-------|-------|--------|
| train | 57 | Public |
| valid | 59 | Public |
| test | 50 | Withheld |
| challenge | varies | Holdout |

Split membership is authoritative in `sequences_info.json`. Do not move clips across splits.

---

## Label file: `Labels-GameState.json`

COCO-style JSON with four top-level keys: `info`, `images`, `annotations`, `categories`.

### `info` (clip metadata)

Example fields: `name` (`SNGS-021`), `version`, `frame_rate`, `seq_length`, `num_tracklets`, `im_dir`, `game_time_start`, `action_class`, `visibility`.

### `images` (per frame)

```json
{
  "is_labeled": true,
  "image_id": "2021000001",
  "file_name": "000001.jpg",
  "height": 1080,
  "width": 1920,
  "has_labeled_person": true,
  "has_labeled_pitch": true,
  "has_labeled_camera": true
}
```

`image_id` is a string unique within the clip (not the frame index). Map to files via `file_name` under `img1/`.

### `categories`

| `category_id` | Name | Supercategory | YOLO person bench |
|---------------|------|---------------|-------------------|
| 1 | player | object | **Include** → `person` |
| 2 | goalkeeper | object | **Include** → `person` |
| 3 | referee | object | **Include** → `person` |
| 4 | ball | object | **Exclude** (deferred) |
| 5 | pitch | pitch | **Exclude** (line polylines, not bboxes) |
| 6 | camera | camera | **Exclude** (calibration params) |
| 7 | other | object | **Include** → `person` |

For the YOLO person-detection spec, filter annotations with `supercategory == "object"` and `category_id in {1, 2, 3, 7}`.

### Object annotation schema

```json
{
  "id": "2021000001",
  "image_id": "2021000001",
  "track_id": 1,
  "supercategory": "object",
  "category_id": 1,
  "attributes": {
    "role": "player",
    "jersey": "3",
    "team": "right"
  },
  "bbox_image": {
    "x": 1699,
    "y": 236,
    "w": 33,
    "h": 80,
    "x_center": 1715.5,
    "y_center": 276.0
  },
  "bbox_pitch": {
    "x_bottom_middle": 15.09,
    "y_bottom_middle": -20.79
  }
}
```

**`bbox_image`** — COCO top-left format in pixels:

- `x`, `y`: top-left corner
- `w`, `h`: width and height
- `x_center`, `y_center`: consistent with `x + w/2`, `y + h/2`

**`bbox_pitch`** — footpoint position on the pitch plane in meters. Used for GS-HOTA (pitch-space eval), not for image-space YOLO mAP.

**`track_id`** — stable within a clip across frames. Useful for MOT analysis; ignored for pure detection conversion.

**`attributes`** — role, team, jersey. ~60% of object boxes have null/missing jersey in typical clips. Not used for single-class person detection.

### Non-object annotations

**Pitch (category 5):** one annotation per frame. `lines` is a dict mapping line name → list of normalized image points `{x, y}` in 0–1 range.

**Camera (category 6):** defined in `categories` but not always present as per-frame annotations; frames may still set `has_labeled_camera: true`.

---

## Per-clip statistics (SNGS-021, valid)

| Metric | Value |
|--------|-------|
| Frames | 750 |
| Object annotations (all categories) | ~13,428 |
| Person-eligible annotations (cat 1,2,3,7) | ~12,678 |
| Objects per frame | ~13–21 (mean ~18) |
| Tracklets | 25 |
| Resolution | 1920 × 1080 |

Comparable scale across valid clips (e.g. SNGS-022 ~10.6k person boxes, SNGS-023 ~15.9k).

---

## Conversion to YOLO format

From `bbox_image` (COCO top-left) to YOLO normalized center:

```
cx = (x + w/2) / image_width
cy = (y + h/2) / image_height
nw = w / image_width
nh = h / image_height
```

One line per box in `<stem>.txt`: `0 cx cy nw nh` (class `0` = person).

Skip annotations without `bbox_image`. Skip ball, pitch, and camera categories.

---

## How TrackLab loads the dataset

Upstream loader: `tracklab/wrappers/dataset/soccernet/soccernet_game_state.py` (in the sn-gamestate venv).

1. Reads `Labels-GameState.json` per clip.
2. Keeps only `supercategory == "object"`.
3. Converts `bbox_image` center coordinates to `bbox_ltwh` (left-top width-height).
4. Builds fine-grained categories from attributes (e.g. `player_left_10`) for ReID/tracking — not used for single-class YOLO.

**Evaluation space:** TrackLab config `soccernet_gs.yaml` supports:

- `EVAL_SPACE: image` — IOU / HOTA on image bboxes → **correct mode for YOLO mAP**
- `EVAL_SPACE: pitch` — GS-HOTA on pitch positions + identity → full GSR metric, out of scope for this track

---

## Download and setup

See [soccernet-gsr/setup-bench.sh](../soccernet-gsr/setup-bench.sh) for SoccerNet-GS download and extraction. YOLO conversion reads from the same `$SPORTIFY_DATA_ROOT/SoccerNetGS` tree; converted YOLO layout is written to `$SPORTIFY_DATA_ROOT/yolo-soccernet/` (see [spec.md](spec.md)).

---

## References

- Paper: [arXiv:2404.11335](https://arxiv.org/abs/2404.11335)
- Dataset task: `gamestate-2024` via [SoccerNet](https://github.com/SoccerNet/sn-gamestate) downloader
- Full GSR baseline: [soccernet-gsr/investigation.md](../soccernet-gsr/investigation.md)
- YOLO bench spec: [spec.md](spec.md)
