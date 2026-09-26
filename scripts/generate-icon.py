#!/usr/bin/env python3
# Writes the SVG layers of AppDetective/AppDetective/app.icon. Run from the repo root after changing the geometry below.
import math, pathlib
A = pathlib.Path("AppDetective/AppDetective/app.icon/Assets")
# A 3x3 grid of apps; the lens magnifies the bottom-right 2x2 block and the other five stay at grid size.
pitch, g0 = 205, 262
cols = [g0, g0 + pitch, g0 + 2 * pitch]
cx, cy = (cols[1] + cols[2]) / 2, (cols[1] + cols[2]) / 2   # lens over the bottom-right block
r, w = 222, 50                                              # lens ring
size, gap, rx = 130, 16, 32                                 # magnified tiles
small, srx = 88, 21                                         # grid tiles
def tile(x, y, s, radius, color): return f'  <rect x="{x - s/2:.0f}" y="{y - s/2:.0f}" width="{s}" height="{s}" rx="{radius}" fill="{color}"/>'
def star(x, y, ro, ri):
    pts = []
    for i in range(10):
        rad = ro if i % 2 == 0 else ri; a = -math.pi/2 + i*math.pi/5
        pts.append(f"{x + rad*math.cos(a):.0f} {y + rad*math.sin(a):.0f}")
    return f'  <path d="M{" L".join(pts)} Z" fill="#FFFFFF"/>'
def bars(x, y, k): return (f'  <rect x="{x-44*k:.0f}" y="{y-40*k:.0f}" width="{88*k:.0f}" height="{18*k:.0f}" rx="{9*k:.0f}" fill="#FFFFFF"/>\n'
                           f'  <rect x="{x-44*k:.0f}" y="{y-9*k:.0f}" width="{88*k:.0f}" height="{18*k:.0f}" rx="{9*k:.0f}" fill="#FFFFFF"/>\n'
                           f'  <rect x="{x-44*k:.0f}" y="{y+22*k:.0f}" width="{58*k:.0f}" height="{18*k:.0f}" rx="{9*k:.0f}" fill="#FFFFFF"/>')
half = size + gap/2
centers = [(cx - half + size/2, cy - half + size/2), (cx + gap/2 + size/2, cy - half + size/2), (cx - half + size/2, cy + gap/2 + size/2), (cx + gap/2 + size/2, cy + gap/2 + size/2)]
(ax, ay), (bx, by), (px, py), (lx, ly) = centers
tiles = "\n".join([
    tile(ax, ay, size, rx, "#FF9F0A"), star(ax, ay, 44, 19),
    tile(bx, by, size, rx, "#30D158"), f'  <circle cx="{bx:.0f}" cy="{by:.0f}" r="31" fill="none" stroke="#FFFFFF" stroke-width="16"/>',
    tile(px, py, size, rx, "#FF375F"), f'  <path d="M{px-24:.0f} {py-35:.0f} L{px-24:.0f} {py+35:.0f} L{px+37:.0f} {py:.0f} Z" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="13" stroke-linejoin="round"/>',
    tile(lx, ly, size, rx, "#BF5AF2"), bars(lx, ly, 0.78),
])
head = '<?xml version="1.0" encoding="UTF-8"?>\n<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">\n'
(A / "tiles.svg").write_text(head + "  <!-- The four apps under the lens, magnified. -->\n" + tiles + "\n</svg>\n")
hx = cx + (r + w/2 - 6) * math.cos(math.pi/4); hy = cy + (r + w/2 - 6) * math.sin(math.pi/4)
(A / "lens.svg").write_text(head + f'  <circle cx="{cx:.0f}" cy="{cy:.0f}" r="{r}" fill="none" stroke="#1D55EE" stroke-width="{w}"/>\n  <line x1="{hx:.0f}" y1="{hy:.0f}" x2="{cx + 255:.0f}" y2="{cy + 255:.0f}" stroke="#1D55EE" stroke-width="72" stroke-linecap="round"/>\n</svg>\n')
# Top row left to right, then the rest of the left column. Plain squares: at Dock size they are specks,
# so marks would only add noise.
apps = [(cols[0], cols[0], "#FFD60A"), (cols[1], cols[0], "#AF52DE"), (cols[2], cols[0], "#5AC8FA"),
        (cols[0], cols[1], "#FF6B35"), (cols[0], cols[2], "#64D2FF")]
parts = [tile(x, y, small, srx, color) for x, y, color in apps]
(A / "apps.svg").write_text(head + "  <!-- Apps outside the lens, at their unmagnified size. -->\n" + "\n".join(parts) + "\n</svg>\n")
print("generated")
