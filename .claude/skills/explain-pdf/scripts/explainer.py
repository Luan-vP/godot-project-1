"""Shared pieces for explainer PDFs: fonts, styles, ruled note boxes,
dot-grid pages, diagram helpers, a concept mind-map, and the output name.

Import from a build script:

    import sys; sys.path.insert(0, ".claude/skills/explain-pdf/scripts")
    from explainer import *

See ../SKILL.md for how a guide is put together.
"""
from pathlib import Path

from reportlab.graphics.shapes import Drawing, Line, Polygon, Rect, String
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    CondPageBreak,
    Flowable,
    KeepTogether,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


FONT_DIR = "/usr/share/fonts/truetype/dejavu/"
pdfmetrics.registerFont(TTFont("Sans", FONT_DIR + "DejaVuSans.ttf"))
pdfmetrics.registerFont(TTFont("Sans-Bold", FONT_DIR + "DejaVuSans-Bold.ttf"))
# DejaVu Sans ships no oblique here; Liberation Sans Italic stands in.
pdfmetrics.registerFont(
    TTFont("Sans-Oblique", "/usr/share/fonts/truetype/liberation/LiberationSans-Italic.ttf")
)
pdfmetrics.registerFont(TTFont("Mono", FONT_DIR + "DejaVuSansMono.ttf"))
pdfmetrics.registerFontFamily(
    "Sans", normal="Sans", bold="Sans-Bold", italic="Sans-Oblique", boldItalic="Sans-Bold"
)

INK = colors.HexColor("#1f2430")
MUTED = colors.HexColor("#5b6272")
RULE = colors.HexColor("#c9ced8")
ACCENT = colors.HexColor("#3b5bdb")
WARM = colors.HexColor("#d9480f")
GREEN = colors.HexColor("#2b8a3e")
FILL_BLUE = colors.HexColor("#e7ecff")
FILL_WARM = colors.HexColor("#fff0e6")
FILL_GREEN = colors.HexColor("#e6f6ea")
FILL_GREY = colors.HexColor("#f1f3f5")
NOTE_LINE = colors.HexColor("#b8c4d9")

PAGE_W, PAGE_H = A4
MARGIN = 18 * mm
FRAME_W = PAGE_W - 2 * MARGIN

body = ParagraphStyle("body", fontName="Sans", fontSize=9.4, leading=13.2, textColor=INK)
small = ParagraphStyle("small", parent=body, fontSize=8.2, leading=11)
cell = ParagraphStyle("cell", parent=body, fontSize=8.2, leading=10.6)
cell_bold = ParagraphStyle("cellb", parent=cell, fontName="Sans-Bold")
h1 = ParagraphStyle(
    "h1", fontName="Sans-Bold", fontSize=18, leading=23, textColor=INK, spaceBefore=2, spaceAfter=6
)
h2 = ParagraphStyle(
    "h2", fontName="Sans-Bold", fontSize=12.5, leading=16, textColor=ACCENT, spaceBefore=10,
    spaceAfter=4,
)
h3 = ParagraphStyle(
    "h3", fontName="Sans-Bold", fontSize=10.2, leading=13.5, textColor=INK, spaceBefore=6,
    spaceAfter=2,
)
bullet = ParagraphStyle("bullet", parent=body, leftIndent=12, bulletIndent=2, spaceAfter=1.5)
code = ParagraphStyle(
    "code", fontName="Mono", fontSize=8, leading=10.6, textColor=INK, backColor=FILL_GREY,
    borderPadding=(4, 5, 4, 5), spaceBefore=4, spaceAfter=6, leftIndent=4, rightIndent=4,
)
callout = ParagraphStyle(
    "callout", parent=body, backColor=FILL_WARM, borderColor=WARM, borderWidth=0.6,
    borderPadding=(5, 6, 5, 6), spaceBefore=6, spaceAfter=8, leftIndent=6, rightIndent=6,
)
tip = ParagraphStyle(
    "tip", parent=callout, backColor=FILL_BLUE, borderColor=ACCENT,
)


def P(text, style=body):
    return Paragraph(text, style)


def B(text):
    return Paragraph(text, bullet, bulletText="•")


def C(text):
    """Inline code."""
    return f'<font name="Mono" size="8.4">{text}</font>'


def code_block(text):
    escaped = (
        text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\n", "<br/>")
    )
    escaped = escaped.replace("  ", "&nbsp;&nbsp;")
    return Paragraph(escaped, code)


def table(rows, widths, header=True, zebra=True):
    data = []
    for r, row in enumerate(rows):
        style = cell_bold if header and r == 0 else cell
        data.append([Paragraph(str(c), style) for c in row])
    t = Table(data, colWidths=widths, repeatRows=1 if header else 0)
    cmds = [
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LINEBELOW", (0, 0), (-1, -1), 0.4, RULE),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ("LEFTPADDING", (0, 0), (-1, -1), 4),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
    ]
    if header:
        cmds += [("BACKGROUND", (0, 0), (-1, 0), FILL_BLUE), ("LINEBELOW", (0, 0), (-1, 0), 0.8, ACCENT)]
    if zebra:
        for r in range(1 if header else 0, len(rows)):
            if r % 2 == 0:
                cmds.append(("BACKGROUND", (0, r), (-1, r), FILL_GREY))
    t.setStyle(TableStyle(cmds))
    return t


class NotesBox(Flowable):
    """A ruled box to write in."""

    def __init__(self, lines=6, title="Notes", width=FRAME_W, gap=7.2 * mm):
        super().__init__()
        self.lines = lines
        self.title = title
        self.width = width
        self.gap = gap
        self.height = 16 + lines * gap + 4

    def wrap(self, aw, ah):
        return self.width, self.height

    def draw(self):
        c = self.canv
        c.setStrokeColor(NOTE_LINE)
        c.setLineWidth(0.8)
        c.roundRect(0, 0, self.width, self.height, 4, stroke=1, fill=0)
        c.setFillColor(ACCENT)
        c.setFont("Sans-Bold", 8.5)
        c.drawString(7, self.height - 12, "✎  " + self.title)
        c.setStrokeColor(NOTE_LINE)
        c.setLineWidth(0.4)
        y = self.height - 16 - self.gap
        for _ in range(self.lines):
            c.line(7, y, self.width - 7, y)
            y -= self.gap


def notes(lines=6, title="Notes"):
    return KeepTogether([Spacer(1, 6), NotesBox(lines, title), Spacer(1, 6)])


class Dot(Flowable):
    """A ruled-dot full page for free notes and sketches."""

    def __init__(self, title):
        super().__init__()
        self.title = title
        self.width = FRAME_W
        self.height = PAGE_H - 2 * MARGIN - 20

    def wrap(self, aw, ah):
        return self.width, self.height

    def draw(self):
        c = self.canv
        c.setFillColor(ACCENT)
        c.setFont("Sans-Bold", 12)
        c.drawString(0, self.height - 12, self.title)
        c.setFillColor(NOTE_LINE)
        step = 6 * mm
        y = self.height - 30
        while y > 0:
            x = 0
            while x <= self.width:
                c.circle(x, y, 0.5, stroke=0, fill=1)
                x += step
            y -= step


# ---------------------------------------------------------------- drawings


def fit(text, font, size, width):
    """[param size], shrunk until [param text] fits in [param width]."""
    while size > 4.5 and pdfmetrics.stringWidth(text, font, size) > width:
        size -= 0.2
    return size


def wrap_words(text, font, size, width):
    lines, line = [], ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if line and pdfmetrics.stringWidth(trial, font, size) > width:
            lines.append(line)
            line = word
        else:
            line = trial
    return lines + [line] if line else lines


def box(d, x, y, w, h, title, lines=(), fill=FILL_BLUE, stroke=ACCENT, title_size=8.2):
    d.add(Rect(x, y, w, h, rx=3, ry=3, fillColor=fill, strokeColor=stroke, strokeWidth=0.8))
    size = fit(title, "Sans-Bold", title_size, w - 10)
    d.add(String(x + 5, y + h - 11, title, fontName="Sans-Bold", fontSize=size, fillColor=INK))
    ty = y + h - 22
    for line in lines:
        size = fit(line, "Sans", 6.8, w - 10)
        d.add(String(x + 5, ty, line, fontName="Sans", fontSize=size, fillColor=MUTED))
        ty -= 9


def arrow(d, x1, y1, x2, y2, color=INK, width=0.9, label=None, label_dx=0, label_dy=3):
    d.add(Line(x1, y1, x2, y2, strokeColor=color, strokeWidth=width))
    import math

    ang = math.atan2(y2 - y1, x2 - x1)
    size = 5
    p1 = (x2 - size * math.cos(ang - 0.4), y2 - size * math.sin(ang - 0.4))
    p2 = (x2 - size * math.cos(ang + 0.4), y2 - size * math.sin(ang + 0.4))
    d.add(Polygon([x2, y2, p1[0], p1[1], p2[0], p2[1]], fillColor=color, strokeColor=color))
    if label:
        d.add(
            String(
                (x1 + x2) / 2 + label_dx, (y1 + y2) / 2 + label_dy, label, fontName="Sans",
                fontSize=6.6, fillColor=color, textAnchor="middle",
            )
        )


def caption(d, x, y, text, size=6.8, color=MUTED, anchor="start", font="Sans"):
    d.add(String(x, y, text, fontName=font, fontSize=size, fillColor=color, textAnchor=anchor))



# ---------------------------------------------------------------- mind-map


def mind_map(concept, branches, width=FRAME_W, height=None):
    """A concept mind-map: [param concept] in the middle, [param branches] (a
    list of (title, [leaf, ...]) pairs, up to about ten) round it, each
    branch's leaves listed in its box. Branches run clockwise from the top
    right: down the right-hand column, then up the left-hand one, so section
    numbers read in order. Colours cycle so neighbours differ."""
    import math

    n = len(branches)
    right = math.ceil(n / 2)
    rows = max(right, 1)
    tallest = max((18 + 9 * len(leaves) for _, leaves in branches), default=30)
    row_h = tallest + 30
    height = height or rows * row_h + 10
    d = Drawing(width, height)
    cx, cy = width / 2, height / 2
    palette = [(FILL_BLUE, ACCENT), (FILL_GREEN, GREEN), (FILL_WARM, WARM), (FILL_GREY, MUTED)]
    bw = min(160, (width - 190) / 2)
    cw = max(96, min(124, pdfmetrics.stringWidth(concept, "Sans-Bold", 12) + 28))
    for i, (title, leaves) in enumerate(branches):
        on_right = i < right
        column = list(range(right)) if on_right else list(range(n - right))
        row = i if on_right else (n - right - 1) - (i - right)
        count = len(column)
        # Centre each column's rows vertically.
        top = cy + (count - 1) * row_h / 2
        by = top - row * row_h
        bh = 18 + 9 * len(leaves)
        bx = width - bw if on_right else 0
        fill, stroke = palette[i % len(palette)]
        edge_x = bx if on_right else bx + bw
        hub_x = cx + (cw / 2 if on_right else -cw / 2)
        # An elbow: out of the hub, then across to the box.
        mid_x = (hub_x + edge_x) / 2
        d.add(Line(hub_x, cy, mid_x, by, strokeColor=stroke, strokeWidth=1.3))
        d.add(Line(mid_x, by, edge_x, by, strokeColor=stroke, strokeWidth=1.3))
        box(d, bx, by - bh / 2, bw, bh, title, ["· " + leaf for leaf in leaves],
            fill=fill, stroke=stroke)
    d.add(Rect(cx - cw / 2, cy - 24, cw, 48, rx=24, ry=24, fillColor=INK, strokeColor=INK))
    lines = wrap_words(concept, "Sans-Bold", 12, cw - 20)[:2]
    ty = cy - 4 + 7 * (len(lines) - 1)
    for line in lines:
        d.add(String(cx, ty, line, fontName="Sans-Bold", fontSize=12, fillColor=colors.white,
                     textAnchor="middle"))
        ty -= 14
    return d


# ---------------------------------------------------------------- the document


def slug(text):
    import re

    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def project_slug(repo_dir="."):
    """The git remote's repository name, else the directory's name, as a slug."""
    import subprocess

    try:
        url = subprocess.run(
            ["git", "-C", str(repo_dir), "remote", "get-url", "origin"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        name = url.rstrip("/").split("/")[-1].removesuffix(".git")
    except (subprocess.CalledProcessError, FileNotFoundError):
        name = Path(repo_dir).resolve().name
    return slug(name)


def output_name(concept, repo_dir=".", when=None):
    """<project-slug>-<concept>-<timestamp>.pdf, timestamp YYYYMMDD-HHMM in UTC."""
    from datetime import datetime, timezone

    when = when or datetime.now(timezone.utc)
    return f"{project_slug(repo_dir)}-{slug(concept)}-{when:%Y%m%d-%H%M}.pdf"


def page_callbacks(footer):
    """onFirstPage/onLaterPages callbacks: a footer line with page numbers,
    and an accent band across the top of the first page."""

    def on_page(canvas, doc):
        canvas.saveState()
        canvas.setFont("Sans", 7.5)
        canvas.setFillColor(MUTED)
        canvas.drawString(MARGIN, 10 * mm, footer)
        canvas.drawRightString(PAGE_W - MARGIN, 10 * mm, f"{doc.page}")
        canvas.setStrokeColor(RULE)
        canvas.setLineWidth(0.4)
        canvas.line(MARGIN, 12.5 * mm, PAGE_W - MARGIN, 12.5 * mm)
        canvas.restoreState()

    def on_first_page(canvas, doc):
        canvas.saveState()
        canvas.setFillColor(ACCENT)
        canvas.rect(0, PAGE_H - 9 * mm, PAGE_W, 9 * mm, stroke=0, fill=1)
        canvas.restoreState()
        on_page(canvas, doc)

    return on_first_page, on_page


def build_pdf(story, out_path, title, footer):
    doc = SimpleDocTemplate(
        str(out_path), pagesize=A4, leftMargin=MARGIN, rightMargin=MARGIN, topMargin=MARGIN,
        bottomMargin=MARGIN + 2 * mm, title=title, author=footer, subject=title,
    )
    first, later = page_callbacks(footer)
    doc.build(story, onFirstPage=first, onLaterPages=later)
    return out_path
