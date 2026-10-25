---
name: explain-pdf
description: Explain a concept from this codebase (a system, a feature, a pipeline) as a printable PDF study guide that opens with a concept mind-map, has ruled boxes to write notes in after every section and dot-grid pages at the end, and is saved to the user's Google Drive "Books" folder as <project-slug>-<concept>-<timestamp>.pdf. Use when asked to explain, document or "make me a PDF to understand" something, or to put a guide in Drive/Books.
---

# Explain a concept as a PDF

The output is a study guide someone reads with a pen in hand: a map of the
concept first, then one section per branch of the map, each ending in space to
write, and blank pages at the back. It goes to Google Drive, into the folder
called **Books**.

The worked example is `docs/music-system/build_guide.py`: the music system
guide this skill was made from. Copy its shape.

## 1. Research the concept first

Read the code, the READMEs and the docs before writing anything. Every claim
in the guide should be traceable to a file, so cite repo-relative paths. Keep
two kinds of number apart and label them in the text: *measured* (from the
repo's own docs or your own measurement) and *estimate* (a typical value to
verify). If something is an inference you could not confirm, say so in the
guide ("hypothesis — measure").

Plan the sections before you write: 5–9 is right. Each becomes one branch of
the mind-map, so give each a short title and 2–3 key points.

## 2. Write the build script

Put it at `docs/<concept-slug>/build_guide.py` so it can be re-run when the
code changes. It imports the shared library:

```python
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / ".claude/skills/explain-pdf/scripts"))
from explainer import *  # noqa: F403
```

`scripts/explainer.py` gives you:

| Name | What it is |
| --- | --- |
| `P(text, style)`, `B(text)`, `C(text)`, `code_block(text)` | paragraph, bullet, inline code, code block |
| `h1`, `h2`, `h3`, `body`, `small`, `callout`, `tip` | styles; `callout` for warnings and open questions, `tip` for how-to-read notes |
| `table(rows, widths)` | header row, zebra stripes, wraps cells |
| `notes(lines, title)` | a ruled box to write in |
| `Dot(title)` | a full dot-grid page |
| `mind_map(concept, branches)` | the concept map: `branches` is `[(title, [leaf, ...]), ...]` |
| `box`, `arrow`, `caption`, `fit`, `wrap_words` | helpers for `Drawing` diagrams |
| `INK`, `MUTED`, `ACCENT`, `WARM`, `GREEN`, `FILL_*` | the palette |
| `output_name(concept, ROOT)` | `<project-slug>-<concept>-<YYYYMMDD-HHMM>.pdf`, UTC |
| `build_pdf(story, path, title, footer)` | A4, margins, footer with page numbers |

The document, in order:

1. **Cover**: title, a one-paragraph summary, a table of contents that says
   what each section lets the reader answer, a `tip` on how to use the guide,
   the commit it was written from, and a `notes(...)` box for questions
   before starting.
2. **The concept at a glance**: `mind_map(...)` with one branch per section,
   numbered to match ("1 · Ownership"), then a large `notes(...)` box for the
   reader's own map. Give it a page of its own.
3. **One section per branch**: a page break before each, prose plus at least
   one diagram or table where the idea has structure (flows, timelines,
   ownership, a budget). End each section with `notes(...)`.
4. **File map and glossary**, then **two `Dot(...)` pages** for sketches.

Diagrams are `reportlab.graphics.shapes.Drawing`s built with `box`/`arrow`/
`caption`; `box` shrinks text to fit, `wrap_words` wraps long lines.

The script writes the PDF beside itself and, given a directory as its first
argument, a copy named with `output_name` there.

## 3. Check every page by eye

Render the pages and look at them before calling it done; layout bugs are
invisible in the code:

```bash
pdftoppm -r 110 -png docs/<concept-slug>/<name>.pdf "$SCRATCH/pages/p"
```

Look for text running out of boxes or off the page, labels overlapping lines
or each other, a notes box stranded alone on a page (shrink it), and empty
space where a notes box could go. Fix, rebuild, look again.

## 4. Name it

`<project-slug>-<concept>-<timestamp>.pdf`, from `output_name`:

- **project-slug**: the git remote's repository name, slugged
  (`godot-project-1`); the directory name when there is no remote.
- **concept**: the concept, slugged (`music-system`).
- **timestamp**: when it was built, UTC, `YYYYMMDD-HHMM`.

## 5. Put it in Google Drive → Books

Use the **Google Drive** connector (its tools come from the user's
claude.ai connectors; load them with ToolSearch, e.g. "google drive upload").

1. Find the folder named exactly `Books` (search folders by name). If there
   are several, ask which one. If there is none, ask before creating it.
2. Upload the named PDF with `Books` as its parent, MIME type
   `application/pdf`.
3. Reply with the file's Drive link.

If the connector is not connected in this session (ListConnectors shows
`enabledInChat: false`), you cannot upload. Say so plainly, send the PDF with
SendUserFile so the user has it now, and tell them to connect Google Drive at
https://claude.ai/customize/connectors and start a new session; the next
session can upload the same file (or rebuild it) in one step. Never claim an
upload you did not make.

## 6. Commit the source

Commit `docs/<concept-slug>/build_guide.py` and the PDF on the working branch,
so the guide can be rebuilt as the code moves on.
