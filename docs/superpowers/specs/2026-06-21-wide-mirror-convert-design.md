# Design: convertToWide.sh — Mirror-Tiled Widescreen DXV Converter

**Date:** 2026-06-21

## Overview

A bash script that takes a folder of DXV movie files (e.g. `1_dxv`) and produces a new folder (e.g. `1_dxv_wide`) where every movie has been extended to 3840×384px by mirror-tiling outward from center and center-cropping the height. Output uses the DXV codec, matching the existing `convert/convertToDXV.sh` conventions.

## File Location

`convert/convertToWide.sh`

## Inputs

- User provides input folder path at runtime (prompted, with a default)
- Output folder is derived: `<inputFolder>_wide`, placed next to the input folder

## File Selection

- Recurse through input folder
- Include files with extensions: `.mov`, `.mkv`, `.mp4`, `.avi`, `.gif`, `.webm`
- Exclude any file whose path contains `__thumbs_mov`
- Skip all non-video files (no copy)

## FFmpeg Filtergraph (per file)

For each video file:

1. **Probe dimensions** — `ffprobe` reads `W` (width) and `H` (height)
2. **Calculate copies** — `n_per_side = ceil(3840 / W)`, guarantees the tiled strip width exceeds 3840px
3. **Build filter_complex:**
   - `split` input into `2 * n_per_side + 1` streams
   - Alternate streams: every other one gets `hflip` applied
   - Pattern (center = source): `…[flip][orig][flip][SOURCE][flip][orig][flip]…`
   - `hstack=inputs=<total>` combines all streams into one wide strip
   - `crop=3840:H:(strip_width-3840)/2:0` — center-crop to 3840px wide
   - `crop=3840:384:0:(H-384)/2` — center-crop to 384px tall
   - `setsar=1` — enforce square pixels
4. `strip_width = W * (2 * n_per_side + 1)`

## Output Settings

| Setting   | Value                        |
|-----------|------------------------------|
| Codec     | `dxv` (`-c:v dxv`)          |
| Audio     | none (`-an`)                 |
| FPS       | 30 (`-r 30`, `fps=30` in vf) |
| Container | `.mov`                       |
| Size      | 3840×384 (both divisible by 16, DXV-safe) |
| SAR       | 1:1 (square pixels)          |

No thumbnail generation.

## Execution Pattern

Same as `convertToDXV.sh`: commands are collected into a `finalCommand` string and executed once with `eval` at the end.

## Directory Structure

Output mirrors input directory structure under `<inputFolder>_wide`. Subdirectories are pre-created with `mkdir -p` before processing files.

## Edge Cases

- **File wider than 3840px:** `n_per_side = ceil(3840/W) = 1`, so strip = 3 copies wide. The center crop still works correctly.
- **File taller than 384px:** center-crop removes equal amounts from top and bottom.
- **File shorter than 384px:** `(H-384)/2` is negative — FFmpeg will error. This is an unlikely edge case for VJ assets; not handled explicitly (acceptable to fail loudly).
- **Special characters in filenames:** handled via `printf -v ... "%q"` escaping, same as `convertToDXV.sh`.
