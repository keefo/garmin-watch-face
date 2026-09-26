#!/usr/bin/env python3
"""Generate resources/drawables/night_sky.png, the dithered night-sky gradient.

The watch draws this image instead of dithering the gradient point by point.
Keep these values in sync with SKY_TOP, SKY_MAX_LEVEL and SKY_DITHER in
source/LiamView.mc: the moon blends its edges against the same levels.
"""

import os
import struct
import zlib

WIDTH = 280
SCREEN_HEIGHT = 280
SKY_TOP = 239
SKY_MAX_LEVEL = 16
SKY_COLORS = [(0x00, 0x00, 0x00), (0x00, 0x00, 0x55), (0x00, 0x00, 0xAA)]
SKY_DITHER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def sky_pixel(x, y, height):
    level = ((y - SKY_TOP) * SKY_MAX_LEVEL) // height
    shade, fraction = divmod(level, 16)
    if fraction > 0 and shade < len(SKY_COLORS) - 1 and fraction > SKY_DITHER[y % 4][x % 4]:
        return SKY_COLORS[shade + 1]
    return SKY_COLORS[shade]


def main():
    height = SCREEN_HEIGHT - SKY_TOP
    rows = b"".join(
        b"\x00" + bytes(channel for x in range(WIDTH) for channel in sky_pixel(x, SKY_TOP + row, height))
        for row in range(height)
    )

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", WIDTH, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(rows, 9))
        + chunk(b"IEND", b"")
    )
    path = os.path.join(os.path.dirname(__file__), "..", "resources", "drawables", "night_sky.png")
    with open(path, "wb") as f:
        f.write(png)
    print(f"Wrote {os.path.normpath(path)} ({WIDTH}x{height})")


if __name__ == "__main__":
    main()
