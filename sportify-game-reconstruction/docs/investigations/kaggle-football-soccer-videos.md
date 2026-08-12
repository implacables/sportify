# Kaggle — Football-Soccer-Videos Dataset — Investigation

**Status:** Not started — needs access  
**Last updated:** 2026-06-30  
**Stage:** Candidate supplementary dataset; not in POC spec. Potential use for player detection training / jersey OCR fine-tuning.

---

## Dataset Reference

| Field | Value |
|-------|-------|
| **Name** | Football-Soccer-Videos-Dataset |
| **Author** | shreyamainkar |
| **URL** | https://www.kaggle.com/datasets/shreyamainkar/football-soccer-videos-dataset |
| **Latest version** | v2 |
| **Tagline** | "Your Gateway to Soccer and Football Video Archives" |
| **License** | Unknown — check Kaggle page (requires login) |

---

## Why This Dataset Was Flagged

A supplementary video dataset could address two gaps in the current Sportify data stack:

1. **No non-SoccerNet training footage** — SoccerNet-GS uses broadcast video (1080p, professional lighting, multi-camera). A separate dataset with diverse match conditions could improve model generalization to amateur footage.
2. **Fine-tune targets** — jersey OCR (EasyOCR / MMOCR) and player re-ID (PRTReID) both benefit from more varied in-the-wild examples.

The dataset is not required for the POC (which uses SoccerNet-GS valid split). It is a candidate for Phase 1 evaluation support or future model fine-tuning.

---

## Open Questions (requires Kaggle login to verify)

| Question | Why it matters |
|----------|---------------|
| How many videos? What total duration? | Determines utility vs. download cost |
| Resolution and frame rate? | Must be ≥720p / ≥25 FPS to be useful for detection work |
| Camera perspective? (broadcast vs. fixed side-view vs. mixed) | Fixed elevated side-view is our target context; broadcast distributions differ |
| Are there annotations? (bounding boxes, jersey numbers, player IDs, events?) | Annotated data is high value; raw video alone has lower priority |
| File format? (MP4, AVI, frames?) | Affects how easily it integrates with existing benchmark harness |
| License — commercial / research only? | Determines acceptable use |
| Amateur or professional footage? | Amateur closer to Sportify's distribution; professional overlaps with SoccerNet |

---

## Relationship to Existing Datasets

| Dataset | Current role | vs. this dataset |
|---------|-------------|-----------------|
| **SoccerNet-GS (gamestate-2024)** | Primary benchmark, 59 valid clips, NDA required | Broadcast; labeled; download via SoccerNetDownloader |
| **SoccerNet-Tracking** | Ball tracking evaluation reference | Broadcast; ball tracklets |
| **SoccerTrack v2** | Ball tracking investigation — amateur fixed camera | Closer to Sportify context |
| **Kaggle Football-Soccer-Videos** | **TBD** — under investigation | Unknown context; no NDA needed (public Kaggle) |

---

## Investigation Plan

1. **Access the dataset page** on Kaggle (login required) — extract all metadata from the description and data tab.
2. **Download a small sample** (1–2 videos) to inspect resolution, frame rate, perspective, and annotation format.
3. **Answer all open questions** in the table above.
4. **Decide on disposition:**

| Outcome | Action |
|---------|--------|
| Amateur, fixed-side-view, annotated | High priority — add to fine-tune / eval pipeline |
| Amateur, fixed-side-view, unannotated | Medium priority — label subset for ball / player eval |
| Broadcast, annotated | Low priority — overlaps with SoccerNet; only useful if annotations are rare |
| Broadcast, unannotated | Deprioritize — SoccerNet already covers this distribution |

---

## Potential Integration Points

If the dataset proves relevant:

| Use | Integration point |
|-----|------------------|
| Player detection fine-tune | Export frames → YOLO format → `$SPORTIFY_DATA_ROOT/yolo-soccernet/` structure |
| Jersey OCR fine-tune | Extract jersey crops + number labels |
| Ball tracking eval | Add as secondary eval set alongside SoccerNet-Tracking |
| Homography testing | If fixed-side-view: test stored homography pipeline on new venue |

See [data-layout.md](../../../docs/data-layout.md) for where new datasets should land under `$SPORTIFY_DATA_ROOT`.

---

## References

| Resource | URL |
|----------|-----|
| Dataset page (requires Kaggle login) | https://www.kaggle.com/datasets/shreyamainkar/football-soccer-videos-dataset |
| Kaggle dataset v2 | https://www.kaggle.com/datasets/shreyamainkar/football-soccer-videos-dataset/versions/2 |

---

## Related Documents

| Document | Relationship |
|----------|--------------|
| [data-layout.md](../../../docs/data-layout.md) | Where new datasets land; SoccerNet-GS layout reference |
| [ball-tracking.md](ball-tracking.md) | Ball tracking investigation — overlapping dataset needs |
| [Pipeline spec](../spec/overview.md) | POC scope — players only; this dataset not in active plan |
