#!/usr/bin/env python3
"""Generate a printer test page PDF (border, grayscale ramp, CMYK/RGB/K swatches,
multi-size text, hairline block). Run in the mind's own venv (reportlab is in the
root venv): `uv run python make_test_page.py OUT.pdf ["timestamp text"]`."""
import sys

from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.units import inch
from reportlab.pdfgen import canvas

out = sys.argv[1] if len(sys.argv) > 1 else "minds_print_test.pdf"
ts = sys.argv[2] if len(sys.argv) > 2 else ""

W, H = letter
c = canvas.Canvas(out, pagesize=letter)

m = 0.5 * inch
c.setLineWidth(1)
c.rect(m, m, W - 2 * m, H - 2 * m)


def crop(x, y, dx, dy):
    length = 18
    c.setLineWidth(1.2)
    c.line(x, y, x + dx * length, y)
    c.line(x, y, x, y + dy * length)


for (x, y, dx, dy) in [(m, m, 1, 1), (W - m, m, -1, 1), (m, H - m, 1, -1), (W - m, H - m, -1, -1)]:
    crop(x, y, dx, dy)

c.setFont("Helvetica-Bold", 24)
c.drawCentredString(W / 2, H - 1.15 * inch, "MINDS PRINTER TEST PAGE")
c.setFont("Helvetica", 11)
c.drawCentredString(W / 2, H - 1.45 * inch, "End-to-end print test via the Minds file bridge")
if ts:
    c.setFont("Helvetica-Oblique", 10)
    c.drawCentredString(W / 2, H - 1.68 * inch, f"Generated: {ts}")

y = H - 2.3 * inch
c.setFont("Helvetica-Bold", 11)
c.drawString(m + 0.2 * inch, y, "Grayscale ramp (should show smooth steps light->dark):")
y -= 0.28 * inch
steps = 11
bw = (W - 2 * m - 0.4 * inch) / steps
for i in range(steps):
    c.setFillGray(1.0 - i / (steps - 1))
    c.rect(m + 0.2 * inch + i * bw, y - 0.35 * inch, bw, 0.35 * inch, fill=1, stroke=0)
c.setFillGray(0)
y -= 0.75 * inch

c.setFont("Helvetica-Bold", 11)
c.drawString(m + 0.2 * inch, y, "Color swatches (blank/gray if printer is monochrome):")
y -= 0.28 * inch
swatches = [("C", colors.cyan), ("M", colors.magenta), ("Y", colors.yellow),
            ("R", colors.red), ("G", colors.green), ("B", colors.blue), ("K", colors.black)]
sw = (W - 2 * m - 0.4 * inch) / len(swatches)
for i, (lbl, col) in enumerate(swatches):
    x0 = m + 0.2 * inch + i * sw
    c.setFillColor(col)
    c.rect(x0, y - 0.35 * inch, sw - 4, 0.35 * inch, fill=1, stroke=1)
    c.setFillColor(colors.white if lbl in ("B", "K") else colors.black)
    c.setFont("Helvetica-Bold", 12)
    c.drawCentredString(x0 + (sw - 4) / 2, y - 0.24 * inch, lbl)
c.setFillColor(colors.black)
y -= 0.8 * inch

c.setFont("Helvetica-Bold", 11)
c.drawString(m + 0.2 * inch, y, "Text legibility (font sizes):")
y -= 0.26 * inch
for size in (6, 8, 10, 12):
    c.setFont("Helvetica", size)
    c.drawString(m + 0.4 * inch, y, f"{size}pt  The quick brown fox jumps over the lazy dog. 0123456789 !@#$%&*()")
    y -= (size + 6)

y -= 0.15 * inch
c.setFont("Helvetica-Bold", 11)
c.drawString(m + 0.2 * inch, y, "Hairline test (lines should stay distinct):")
y -= 0.3 * inch
for i, lw in enumerate((0.25, 0.5, 0.75, 1.0, 1.5, 2.0)):
    c.setLineWidth(lw)
    xx = m + 0.4 * inch + i * 0.9 * inch
    c.line(xx, y, xx, y - 0.4 * inch)
    c.setFont("Helvetica", 7)
    c.drawCentredString(xx, y - 0.52 * inch, f"{lw}pt")

c.setFont("Helvetica-Oblique", 9)
c.drawCentredString(W / 2, m + 0.18 * inch,
                    "If this page printed fully with a visible border on all four sides, the end-to-end path works.")
c.showPage()
c.save()
print(f"wrote {out}")
