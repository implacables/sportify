#!/usr/bin/env python3
"""Convert SoccerNet-GS Labels-GameState.json to Ultralytics YOLO layout.

Reads:  $DATA_ROOT/SoccerNetGS/{split}/SNGS-XXX/Labels-GameState.json
Writes: $DATA_ROOT/yolo-soccernet/{images,labels}/{train,val}/SNGS-XXX/

Images are symlinked (not copied). Labels are one .txt per frame, empty when
no person boxes are present. See spec.md §4 for the full conversion spec.
"""
import argparse
import json
import sys
from pathlib import Path

# Categories to include as class 0 "person" (player, goalkeeper, referee, other)
PERSON_CATEGORY_IDS = {1, 2, 3, 7}

# SoccerNet split name -> YOLO directory name
SN_TO_YOLO_SPLIT = {"valid": "val", "train": "train"}


def parse_manifest(path: Path) -> dict:
    """Parse a YAML manifest, returning {split, clips}. No PyYAML dependency."""
    result = {"split": "valid", "clips": []}
    in_clips = False
    for line in path.read_text().splitlines():
        s = line.strip()
        if s.startswith("#"):
            continue
        if s.startswith("split:"):
            result["split"] = s.split(":", 1)[1].strip().strip('"').strip("'")
            in_clips = False
        elif s == "clips:":
            in_clips = True
        elif in_clips and s.startswith("- id:"):
            result["clips"].append(s[len("- id:"):].strip())
        elif in_clips and s and not s.startswith("-"):
            in_clips = False
    return result


def convert_clip(
    clip_dir: Path,
    out_images: Path,
    out_labels: Path,
    clip_id: str,
    dry_run: bool,
) -> dict:
    labels_file = clip_dir / "Labels-GameState.json"
    if not labels_file.exists():
        print(f"  warning: {labels_file} not found — skipping", file=sys.stderr)
        return {"clip_id": clip_id, "frames": 0, "boxes": 0, "skipped": True}

    data = json.loads(labels_file.read_text())

    # image_id -> {file_name, width, height}
    img_meta = {
        img["image_id"]: {
            "file_name": img["file_name"],
            "width": img.get("width", 1920),
            "height": img.get("height", 1080),
        }
        for img in data.get("images", [])
    }

    # image_id -> list of bbox_image dicts
    boxes_by_image: dict = {}
    for ann in data.get("annotations", []):
        if ann.get("supercategory") != "object":
            continue
        if ann.get("category_id") not in PERSON_CATEGORY_IDS:
            continue
        bbox = ann.get("bbox_image")
        if not bbox:
            continue
        boxes_by_image.setdefault(ann["image_id"], []).append(bbox)

    img1_dir = clip_dir / "img1"
    out_img_clip = out_images / clip_id
    out_lbl_clip = out_labels / clip_id

    if not dry_run:
        out_img_clip.mkdir(parents=True, exist_ok=True)
        out_lbl_clip.mkdir(parents=True, exist_ok=True)

    total_boxes = 0
    frames_written = 0

    for image_id, meta in img_meta.items():
        fname = meta["file_name"]
        stem = Path(fname).stem
        W, H = meta["width"], meta["height"]

        src_img = img1_dir / fname
        dst_img = out_img_clip / fname
        if not dry_run:
            if not dst_img.exists():
                if src_img.exists():
                    dst_img.symlink_to(src_img)
                else:
                    print(f"  warning: source image missing: {src_img}", file=sys.stderr)

        boxes = boxes_by_image.get(image_id, [])
        lines = []
        for bbox in boxes:
            x, y, w, h = bbox["x"], bbox["y"], bbox["w"], bbox["h"]
            cx = (x + w / 2) / W
            cy = (y + h / 2) / H
            nw = w / W
            nh = h / H
            lines.append(f"0 {cx:.6f} {cy:.6f} {nw:.6f} {nh:.6f}")

        if not dry_run:
            label_text = "\n".join(lines) + ("\n" if lines else "")
            (out_lbl_clip / f"{stem}.txt").write_text(label_text)

        total_boxes += len(lines)
        frames_written += 1

    return {"clip_id": clip_id, "frames": frames_written, "boxes": total_boxes, "skipped": False}


def write_data_yaml(yolo_root: Path, dry_run: bool) -> None:
    content = f"""path: {yolo_root}
train: images/train
val: images/val
names:
  0: person
nc: 1
"""
    if not dry_run:
        (yolo_root / "data.yaml").write_text(content)
    else:
        print(f"  [dry-run] would write data.yaml to {yolo_root}/data.yaml")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert SoccerNet-GS Labels-GameState.json to Ultralytics YOLO layout"
    )
    parser.add_argument("--data-root", required=True, help="SPORTIFY_DATA_ROOT")
    parser.add_argument("--manifest", help="Manifest YAML specifying clips and split")
    parser.add_argument(
        "--split",
        default="valid",
        choices=["valid", "train", "all"],
        help="SoccerNet split to convert (ignored when --manifest given)",
    )
    parser.add_argument("--clips", help="Comma-separated clip IDs to convert (overrides manifest clip list)")
    parser.add_argument("--dry-run", action="store_true", help="Print what would happen; write nothing")
    args = parser.parse_args()

    data_root = Path(args.data_root)
    sn_root = data_root / "SoccerNetGS"
    yolo_root = data_root / "yolo-soccernet"

    if not sn_root.exists():
        print(f"error: SoccerNetGS not found at {sn_root}", file=sys.stderr)
        sys.exit(1)

    # Resolve which (sn_split, yolo_split, clip_ids) to process
    targets: list[tuple[str, str, list[str]]] = []

    if args.manifest:
        manifest = parse_manifest(Path(args.manifest))
        sn_split = manifest["split"]
        clip_ids = args.clips.split(",") if args.clips else manifest["clips"]
        clip_ids = [c.strip() for c in clip_ids]
        targets = [(sn_split, SN_TO_YOLO_SPLIT.get(sn_split, sn_split), clip_ids)]
    elif args.split == "all":
        for sn_split, yolo_split in SN_TO_YOLO_SPLIT.items():
            split_dir = sn_root / sn_split
            if split_dir.exists():
                clip_ids = sorted(d.name for d in split_dir.iterdir() if d.is_dir() and d.name.startswith("SNGS-"))
                targets.append((sn_split, yolo_split, clip_ids))
    else:
        sn_split = args.split
        yolo_split = SN_TO_YOLO_SPLIT.get(sn_split, sn_split)
        split_dir = sn_root / sn_split
        if args.clips:
            clip_ids = [c.strip() for c in args.clips.split(",")]
        elif split_dir.exists():
            clip_ids = sorted(d.name for d in split_dir.iterdir() if d.is_dir() and d.name.startswith("SNGS-"))
        else:
            print(f"error: split dir not found: {split_dir}", file=sys.stderr)
            sys.exit(1)
        targets = [(sn_split, yolo_split, clip_ids)]

    dry_run = args.dry_run
    if dry_run:
        print("==> Dry run — no files will be written")

    print(f"==> Output root: {yolo_root}")
    if not dry_run:
        yolo_root.mkdir(parents=True, exist_ok=True)
    write_data_yaml(yolo_root, dry_run)

    all_stats = []
    for sn_split, yolo_split, clip_ids in targets:
        out_images = yolo_root / "images" / yolo_split
        out_labels = yolo_root / "labels" / yolo_split
        if not dry_run:
            out_images.mkdir(parents=True, exist_ok=True)
            out_labels.mkdir(parents=True, exist_ok=True)

        print(f"==> Converting split '{sn_split}' ({len(clip_ids)} clips) -> {yolo_split}/")
        for clip_id in clip_ids:
            clip_dir = sn_root / sn_split / clip_id
            if not clip_dir.exists():
                print(f"  warning: clip dir not found: {clip_dir}", file=sys.stderr)
                continue
            stats = convert_clip(clip_dir, out_images, out_labels, clip_id, dry_run)
            status = "skipped" if stats.get("skipped") else f"{stats['frames']} frames, {stats['boxes']} boxes"
            print(f"  {clip_id}: {status}")
            all_stats.append(stats)

    total_frames = sum(s["frames"] for s in all_stats)
    total_boxes = sum(s["boxes"] for s in all_stats)
    suffix = " (dry-run, nothing written)" if dry_run else ""
    print(f"==> Done: {len(all_stats)} clips, {total_frames} frames, {total_boxes} boxes{suffix}")
    if not dry_run:
        print(f"  data.yaml: {yolo_root}/data.yaml")


if __name__ == "__main__":
    main()
