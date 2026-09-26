# Specification: MARK-ENDURO // TACTICAL TELEMETRY HUD

Target Device: Garmin Enduro 3 (Connect IQ 5.0+, Monkey C)
Display Architecture: 280x280 MIP (Transflective Memory-in-Pixel, 64 Colors)

## 1. UI Grid & Layout Topology
The screen is organized into 5 functional vertical tiers built around a circular 280px bounding box:

- **Tier 1 (y: 10px - 35px)**: System Header & Telemetry Status
  - Left: Remaining Battery (`BAT: 28D`)
  - Center: Header Identifier (`/// ARC-HUD v3.0 \\\`)
  - Right: Satellite Lock (`GPS: FIX`)
- **Tier 2 (y: 40px - 65px)**: Environmental Sensors
  - Left: Altimeter reading in meters
  - Right: Barometric pressure in hPa
- **Tier 3 (y: 70px - 140px)**: Primary Time Anchor (Core)
  - Time rendered in custom block-mono high-contrast font.
  - Seconds and AM/PM aligned to the right edge.
  - Date string rendered directly below: `DAY, MON DD | YYYY`.
- **Tier 4 (y: 145px - 210px)**: Biometric & Solar Data Matrix
  - Quad-grid: Heart Rate (BPM), VO2 Max, Step Count, and Solar Intensity percentage.
- **Tier 5 (y: 215px - 265px)**: Training & Recovery Telemetry
  - Training Load Ramp Rate sparkline / percentage offset.
  - Recovery Time Remaining (`[RECOVERY: 24h]`).

## 2. Garmin Monkey C Implementation Directives

### A. Memory & Performance Optimization
1. **Static HUD Layer Buffering**:
   - Do NOT redraw background frames, labels, or static grids on every `onUpdate(dc)`.
   - Allocate a `BufferedBitmap` during `onLayout()`. Render grid lines, text labels, and static frames once into this buffer.
   - Inside `onUpdate()`, execute `dc.drawBitmap(0, 0, hudBuffer)` before rendering dynamic data text.

2. **Power Management (`onPartialUpdate`)**:
   - To preserve battery life on MIP hardware, refresh live seconds or dynamic HR zones using `onPartialUpdate()`.
   - Restrict updates to a small bounding box via `dc.setClip(x, y, width, height)`.

### B. Color Constraints
- **Background**: `Graphics.COLOR_BLACK`
- **Primary Labels**: `Graphics.COLOR_WHITE`
- **Telemetry Highlights**: `Graphics.COLOR_CYAN` / `Graphics.COLOR_DK_CYAN`
- **Warnings / Caution**: `Graphics.COLOR_ORANGE` / `Graphics.COLOR_RED`