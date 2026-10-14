#!/usr/bin/env python3
import math
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def png(path, size, pixels):
    raw = b"".join(b"\0" + bytes(pixels[y * size * 4:(y + 1) * size * 4]) for y in range(size))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))

def star_polygon(cx, cy, outer, inner):
    points = []
    for i in range(10):
        r = outer if i % 2 == 0 else inner
        a = -math.pi / 2 + i * math.pi / 5
        points.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return points

def inside(px, py, poly):
    hit = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi:
            hit = not hit
        j = i
    return hit

def rounded_coverage(px, py, size):
    r = size * 0.1754
    cx = min(max(px, r), size - r)
    cy = min(max(py, r), size - r)
    return math.hypot(px - cx, py - cy) <= r

def gloss_alpha(px, py, size):
    u, v = px / size, py / size
    ecx, ecy, rx, ry = 0.5, -0.6, 1.0, 1.12
    if ((u - ecx) / rx) ** 2 + ((v - ecy) / ry) ** 2 > 1:
        return 0.0
    return 0.48 - 0.34 * min(1.0, v / 0.52)

def render(size):
    top, bottom = (0x63, 0xBE, 0xF8), (0x0B, 0x55, 0xC4)
    cx, cy = size / 2, size / 2
    ring_outer, ring_inner = size * 0.37, size * 0.31
    star = star_polygon(cx, cy + size * 0.015, size * 0.22, size * 0.09)
    drop = size * 0.025

    def glyph(px, py):
        d = math.hypot(px - cx, py - cy)
        return ring_inner <= d <= ring_outer or inside(px, py, star)

    samples = 4
    pixels = []
    for y in range(size):
        t = y / (size - 1)
        bg = [top[i] + (bottom[i] - top[i]) * t for i in range(3)]
        for x in range(size):
            cover = shade = 0
            for sy in range(samples):
                for sx in range(samples):
                    px, py = x + (sx + 0.5) / samples, y + (sy + 0.5) / samples
                    if glyph(px, py):
                        cover += 1
                    elif glyph(px, py - drop):
                        shade += 1
            cover /= samples * samples
            shade /= samples * samples
            color = [c * (1 - shade * 0.3) for c in bg]
            color = [c + (255 - c) * cover for c in color]
            inside_n = shine = 0.0
            for sy in range(samples):
                for sx in range(samples):
                    px, py = x + (sx + 0.5) / samples, y + (sy + 0.5) / samples
                    if rounded_coverage(px, py, size):
                        inside_n += 1
                        shine += gloss_alpha(px, py, size)
            alpha = inside_n / (samples * samples)
            if inside_n:
                g = shine / inside_n
                color = [c + (255 - c) * g for c in color]
            pixels += [round(c) for c in color] + [round(alpha * 255)]
    return pixels

for name, size in (("Icon.png", 57), ("Icon@2x.png", 114)):
    png(os.path.join(ROOT, "Resources", name), size, render(size))
    print("wrote", name)
