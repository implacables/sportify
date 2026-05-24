# DJI Osmo 360 — Intended Match Camera

**Status:** Planned input device  
**Last updated:** 2026-05-24  

**Sources:** [DJI Osmo 360 specs](https://www.dji.com/360/specs), [DJI Osmo 360 FAQ](https://www.dji.com/360/faq), [DrDrone Osmo 360 FAQ](https://drdrone.com/pages/dji-osmo-360-faq)

Sportify intends to record amateur match footage with a **DJI Osmo 360**. This camera is expected to cover our field-capture needs: elevated fixed viewpoint, pretaped MP4 upload, and venue homography computed once at setup.

---

## Role in Sportify

| Need | How Osmo 360 addresses it |
|------|---------------------------|
| Fixed elevated side view | Mount on tripod or pole at touchline; camera stays put for the match |
| Pretaped upload to VPS | Record locally → export flat MP4 (HEVC) → upload |
| Venue homography once | Camera position fixed per venue; no per-frame calibration in pipeline |
| Amateur / thesis budget | Consumer 360 camera, not broadcast rig |
| Outdoor pitch | IP68 body (10 m); −20 °C to 45 °C operating range |

The reconstruction pipeline consumes **exported flat video**, not in-camera panoramic OSV files, unless a separate reframe/dewarp step is added later.

---

## Hardware Summary (official)

| Property | Value |
|----------|--------|
| Model | DJI Osmo 360 |
| Dimensions | 61 × 36.3 × 81 mm (L × W × H) |
| Weight | 183 g (body only) |
| Sensors | 2 × 1/1.1-inch square CMOS (dual fisheye) |
| Aperture | f/1.9 |
| ISO range | 100–51200 |
| Dynamic range | Up to ~13.5 stops (DJI marketing spec) |
| Waterproof | IP68; body rated to 10 m depth |
| Display | 2.0-inch OLED touchscreen |
| Microphones | 4 (48 kHz, 16-bit AAC) |
| Built-in storage | 128 GB (~105 GB available) |
| Expandable storage | microSD, up to 1 TB (exFAT) |
| USB | USB 3.1 Type-C (DJI cites up to ~600 MB/s transfer from internal storage in lab conditions) |
| Wi-Fi | Wi-Fi 6 |
| Battery | 1950 mAh / 7.5 Wh |
| Stabilization | RockSteady 3.0, HorizonSteady (mode-dependent) |

Each lens is a **fisheye prime** with **>180°** field of view; panoramic output is stitched from both lenses.

---

## Video Modes Relevant to Sportify

DJI supports many modes. For match capture, the practical candidates are:

### Single Lens — Video (flat MP4)

| Resolution | Frame rates | Aspect | Notes |
|------------|-------------|--------|-------|
| 5K | 25/30/50/60 fps | 16:9 (5120×2880) | Highest flat 16:9 |
| 4K | 25/30/50/60 fps | 16:9 (3840×2160) | Common balance of quality and file size |
| 4K | 25/30/50/60 fps | 4:3 | Taller frame |
| 2.7K | 25/30/50/60 fps | 16:9 | Smaller files |

### Single Lens — Boost Video (flat MP4, wider FOV)

| Resolution | Frame rates | Notes |
|------------|-------------|-------|
| 4K | up to 120 fps | DJI cites **170°** field of view in Boost mode |
| 2.7K | up to 120 fps | Lower res, still wide FOV |

Boost mode may help cover more pitch width from a single sideline mount. Exact coverage for a given mount height and distance is **TBD** at venue setup.

### Panoramic Video (OSV)

| Resolution | Frame rates |
|------------|-------------|
| 8K | 7680×3840 @ 24/25/30/48/50 fps |
| 6K | 6000×3000 @ 24/25/30/48/50/60 fps |
| 4K | 3840×1920 @ 100 fps |

Stored as **OSV**, not flat MP4. Using panoramic capture would require exporting or reframing to a fixed viewpoint before pipeline ingest unless reconstruction is extended to handle 360° source.

---

## Codec, Container, and Bitrate

| Property | Value |
|----------|--------|
| Flat video format | **MP4 (HEVC / H.265)** |
| Panoramic format | **OSV** |
| Max video bitrate | **170 Mbps** (official spec — applies when High bit rate is selected) |
| Photo format | JPEG |

The POC pipeline spec requires H.265 in MP4. Osmo 360 flat exports align with **HEVC in MP4**.

---

## Bitrate Configuration

**Short answer:** you can choose a **lower bit rate preset** in DJI Mimo — not a custom Mbps value, and not always max.

### What the camera offers

| Control | Where | What it does |
|---------|-------|--------------|
| **Bit rate** | DJI Mimo → swipe down → Settings → **Bit rate** | Preset toggle — **High** uses more data; the alternative preset uses less (DJI does not publish exact Mbps for the lower preset in official specs) |
| **Resolution / fps** | Recording mode settings | Lower resolution or frame rate reduces file size and processing load |
| **PRO mode** | Image/Audio Settings → PRO | Manual **shutter speed** and **ISO** only — does **not** expose numeric bitrate |

Official documentation confirms **170 Mbps maximum** when recording at high quality settings. There is **no arbitrary Mbps slider** in DJI's published controls.

### Sportify intent

Configure a **venue recording profile** (resolution, fps, bit rate preset, lens mode) tuned for reconstruction quality vs file size — **not** max bitrate by default. The optimal profile is **TBD** after test recordings and pipeline trials.

**Levers available today:**

1. Set Bit rate to **below High** in Mimo settings.
2. Pick a lower resolution/fps mode (e.g. 4K/30 instead of 4K/60 or 8K).
3. Use Single Lens flat export rather than 8K panoramic OSV.

---

## Match Capture Workflow (intended)

A full match is **~90 minutes**. Sportify intends to record in **two segments** with a **halftime break** for charging and storage headroom:

```
1st half → stop recording at halftime
         → camera on charger during break (mount stays fixed)
2nd half → start new recording after break
         → two MP4 files stored on microSD
```

| Aspect | Plan |
|--------|------|
| Segments | **Two** — one per half |
| Halftime | Stop recording; **charge camera** (USB-C, PD 3.0, 30 W+ supported) |
| Mount | Camera position **unchanged** across both halves (same homography) |
| Storage | Each half stored on **microSD** as separate files |
| Before upload | Operator **joins both halves into one MP4** manually (POC — no in-app or pipeline concat) |
| While charging | Osmo 360 **can record while charging** (DJI FAQ) — charging during the break is the primary use |

Each half is **~45 minutes**, which fits comfortably within single-charge limits for typical recording modes. The reconstruction pipeline ingests **one file per match**.

---

## Battery and Match Length

Official operating time (lab conditions, screen off, Wi‑Fi off):

| Mode | Max continuous recording |
|------|--------------------------|
| 8K/30 fps panoramic | ~100 min |
| 8K/30 fps panoramic + Endurance mode | ~120 min |
| 6K/24 fps panoramic + Endurance mode | ~190 min |

With the **two-half workflow**, each segment is ~45 min — well within battery limits for most modes. Halftime charging adds margin and avoids relying on Endurance mode or spare batteries.

Compatible spare batteries: DJI Action 3 / 4 / 5 Pro batteries fit Osmo 360 (third-party FAQ) — optional backup, not required if halftime charging is used.

---

## Storage and File Size

Built-in **105 GB** is likely **insufficient** for a full match at high bitrate. **microSD (up to 1 TB)** is expected.

With **two ~45-minute segments**, per-file size is roughly half of a full-match estimate:

| Assumed bitrate | ~45 min per half (order of magnitude) |
|-----------------|----------------------------------------|
| 170 Mbps (max) | ~57 GB |
| 100 Mbps | ~34 GB |
| 60 Mbps | ~20 GB |
| 40 Mbps | ~14 GB |

Halftime segmentation also keeps each file closer to the product spec **~20 GB upload** target when bit rate and resolution are tuned down from max.

**Open:** chosen recording profile that hits acceptable reconstruction quality at target file size per half.

---

## Mounting and Capture Setup

Documented DJI mounting options include tripods and the **Invisible Selfie Stick** (sold separately). For Sportify:

1. Mount camera **fixed** at elevated sideline position for the match.
2. Register **venue homography** once from this mount geometry.
3. Do not move the camera mid-match (pipeline assumes fixed view).

Minimum stitching distance for panoramic modes: **≥ 0.75 m** from the lens — irrelevant at pitch scale for subjects on the field, but relevant if the camera is mounted very close to a fence or wall.

HorizonSteady in Single Lens mode applies to **16:9 distortion-corrected flat video up to 60 fps** — may reduce shake if the mount is not perfectly rigid.

---

## Export Workflow

Footage is stored on **microSD** or **built-in storage**. Export paths (DJI):

1. **DJI Mimo app** — wireless transfer to phone
2. **microSD card reader** — direct to computer
3. **USB-C** — camera in USB mode, cable to computer

For pipeline ingest, export **flat MP4 (HEVC)** at the chosen resolution. DJI Mimo / DJI Studio can reframe panoramic OSV to flat video if panoramic capture is used.

**Open:** standard export workflow from camera to VPS upload (tooling, reframe settings, naming).

---

## Implications for the Reconstruction POC

| Topic | Implication |
|-------|-------------|
| Fixed camera assumption | Satisfied when mounted and left unmoved |
| HEVC MP4 ingest | Satisfied by Single Lens / Boost flat export |
| Per-frame calibration eliminated | Satisfied — homography from venue setup |
| ~90 min jobs | Two ~45 min halves; charge at halftime |
| File size / upload | Bit rate preset + resolution/fps drive size per half |
| 360° vs flat capture | Flat Single Lens simplest for POC; panoramic is optional future flexibility |

---

## Open Decisions

| # | Topic | Notes |
|---|--------|-------|
| 1 | Recording mode | Single Lens 4K/30 vs 4K/60 vs Boost 170° vs panoramic + reframe |
| 2 | Venue recording profile | Bit rate preset + resolution/fps tuned for quality vs ~20 GB per half |
| 3 | microSD capacity | Size for two halves at chosen profile |
| 4 | Join tooling | How halves are concatenated before upload (ffmpeg, DJI Studio, etc.) |
| 5 | Mount height and position | Standard per venue; feeds homography setup |
| 6 | Export tooling | Mimo vs USB vs card reader for thesis workflow |

---

## Related Documents

| Document | Path |
|----------|------|
| Product overview | [../overview.md](../overview.md) |
| Product spec (upload) | [../spec/overview.md](../spec/overview.md) |
| Pipeline video input | [../../sportify-game-reconstruction/docs/spec/overview.md](../../sportify-game-reconstruction/docs/spec/overview.md) |
