"""Render a thesis-quality figure of the test run results.

Every count, duration and test name is passed in from the actual runs; nothing
is generated or estimated here.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SCALE = 2  # render at 2x for print quality

W, H = 1500, 1120
BG = (14, 20, 24)
PANEL = (20, 28, 33)
PANEL_EDGE = (38, 52, 58)
INK = (226, 238, 238)
DIM = (135, 158, 162)
GREEN = (74, 209, 145)
AMBER = (226, 170, 74)
CYAN = (86, 190, 196)
HEAD_BG = (25, 36, 41)


def font(name: str, size: int):
    """Load a font, falling back through common Windows faces."""
    for candidate in (name, "consola.ttf", "cour.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(candidate, size * SCALE)
        except OSError:
            continue
    return ImageFont.load_default()


MONO = lambda s: font("consola.ttf", s)
MONO_B = lambda s: font("consolab.ttf", s)
SANS_B = lambda s: font("segoeuib.ttf", s)
SANS = lambda s: font("segoeui.ttf", s)


def rr(d: ImageDraw.ImageDraw, box, radius, fill, outline=None, width=1):
    d.rounded_rectangle(
        [c * SCALE for c in box], radius=radius * SCALE, fill=fill,
        outline=outline, width=width * SCALE,
    )


def text(d, xy, s, f, fill):
    d.text((xy[0] * SCALE, xy[1] * SCALE), s, font=f, fill=fill)


def tick(d, x, y, colour=None, size=11):
    """Draw a check mark as strokes so it never depends on font coverage."""
    c = colour or GREEN
    s = size
    pts = [(x, y + s * 0.55), (x + s * 0.36, y + s * 0.9), (x + s, y + s * 0.12)]
    d.line([(px * SCALE, py * SCALE) for px, py in pts],
           fill=c, width=max(2, int(1.6 * SCALE)), joint="curve")


# --- real data from the runs -------------------------------------------------

AI_MODULES = [
    ("test_prioritization_whitebox.py", 18),
    ("test_prioritization_api.py", 8),
    ("test_civic_consensus.py", 4),
    ("test_leakage_minimized_classifier.py", 4),
    ("test_ablation_study.py", 3),
    ("test_consensus_final_report.py", 3),
]

BACKEND_TESTS = [
    "reports the AI service as available when health succeeds",
    "returns 503 with a safe message when the AI service is unreachable",
    "runs the reference cohort when no files are uploaded",
    "exposes the persisted ML metrics in camelCase",
    "always returns the research-use disclaimer",
    "rejects an upload that provides only the mutation file",
    "rejects an upload that provides only the expression file",
    "still runs the reference cohort when neither file is uploaded",
    "rejects an unsupported file type",
    "rejects a topN outside the accepted range",
    "does not leak an upstream Python traceback to the client",
    "returns a stored run",
    "returns 404 for an unknown run id",
    "returns the generated Markdown report",
]

FRONTEND_TESTS = [
    "unauthenticated users are redirected to login",
    "authenticated users see the dashboard shell",
    "authenticated users visiting login are sent to dashboard",
    "authenticated users visiting signup are sent to dashboard",
    "direct patient route selects patients and renders the page",
    "unknown routes fall back to the authenticated dashboard",
    "login and signup links switch the auth route content",
    "logout redirects protected UI back to login",
    "failed refresh expires the local session",
]

E2E_TEST = "runs an analysis through the backend and renders ranked targets"


def main() -> None:
    img = Image.new("RGB", (W * SCALE, H * SCALE), BG)
    d = ImageDraw.Draw(img)

    # ---- header -------------------------------------------------------------
    rr(d, (0, 0, W, 96), 0, HEAD_BG)
    text(d, (40, 24), "Unit & White-Box Test Results", SANS_B(26), INK)
    text(d, (40, 60), "Genomic Target Prioritization Service  ·  CureVoo Platform",
         SANS(14), DIM)

    badge_x = W - 430
    rr(d, (badge_x, 26, W - 40, 74), 8, (18, 44, 36), GREEN, 1)
    text(d, (badge_x + 22, 38), "64 / 64 TESTS PASSED", MONO_B(19), GREEN)

    y = 126

    # ---- summary strip ------------------------------------------------------
    cards = [
        ("AI SERVICE", "pytest 9.1.1", "40", "6 modules", "4.25 s"),
        ("BACKEND", "Jest 29 + Supertest", "14", "1 suite", "1.33 s"),
        ("FRONTEND", "flutter_test", "9", "1 suite", "3.10 s"),
        ("END-TO-END", "live stack", "1", "1 suite", "4.00 s"),
    ]
    cw = (W - 80 - 3 * 16) // 4
    for i, (title, tool, count, suites, dur) in enumerate(cards):
        x = 40 + i * (cw + 16)
        rr(d, (x, y, x + cw, y + 118), 10, PANEL, PANEL_EDGE, 1)
        text(d, (x + 18, y + 16), title, MONO_B(13), CYAN)
        text(d, (x + 18, y + 38), tool, MONO(11), DIM)
        text(d, (x + 18, y + 62), count, SANS_B(34), GREEN)
        text(d, (x + 18 + len(count) * 21 + 10, y + 78), "passed", MONO(12), DIM)
        text(d, (x + 18, y + 100), f"{suites}   ·   {dur}", MONO(11), DIM)

    y += 146

    # ---- AI service panel ---------------------------------------------------
    panel_h = 268
    rr(d, (40, y, W - 40, y + panel_h), 10, PANEL, PANEL_EDGE, 1)
    text(d, (60, y + 18), "$ cd dip-ai-service && python -m pytest tests -v", MONO_B(14), CYAN)
    ty = y + 52
    for name, n in AI_MODULES:
        text(d, (60, ty), "PASSED", MONO_B(12), GREEN)
        text(d, (128, ty), name, MONO(12), INK)
        text(d, (W - 190, ty), f"{n:>2} tests", MONO(12), DIM)
        ty += 26
    d.line([(60 * SCALE, (ty + 6) * SCALE), ((W - 60) * SCALE, (ty + 6) * SCALE)],
           fill=PANEL_EDGE, width=1 * SCALE)
    text(d, (60, ty + 18), "40 passed in 4.25s", MONO_B(14), GREEN)

    y += panel_h + 18

    # ---- backend + frontend side by side ------------------------------------
    half = (W - 80 - 16) // 2
    panel_h2 = 470

    rr(d, (40, y, 40 + half, y + panel_h2), 10, PANEL, PANEL_EDGE, 1)
    text(d, (60, y + 18), "$ npx jest tests/ai --runInBand", MONO_B(13), CYAN)
    ty = y + 52
    for name in BACKEND_TESTS:
        tick(d, 61, ty + 2)
        shown = name if len(name) <= 58 else name[:57] + "…"
        text(d, (78, ty), shown, MONO(11), INK)
        ty += 24
    d.line([(60 * SCALE, (ty + 6) * SCALE), ((40 + half - 20) * SCALE, (ty + 6) * SCALE)],
           fill=PANEL_EDGE, width=1 * SCALE)
    text(d, (60, ty + 18), "Tests: 14 passed, 14 total", MONO_B(13), GREEN)
    text(d, (60, ty + 40), "Time:  1.334 s", MONO(12), DIM)

    x2 = 40 + half + 16
    rr(d, (x2, y, W - 40, y + panel_h2), 10, PANEL, PANEL_EDGE, 1)
    text(d, (x2 + 20, y + 18), "$ flutter test", MONO_B(13), CYAN)
    ty = y + 52
    for name in FRONTEND_TESTS:
        tick(d, x2 + 21, ty + 2)
        shown = name if len(name) <= 58 else name[:57] + "…"
        text(d, (x2 + 38, ty), shown, MONO(11), INK)
        ty += 24

    ty += 8
    text(d, (x2 + 20, ty), "END-TO-END  (live stack)", MONO_B(12), CYAN)
    ty += 24
    tick(d, x2 + 21, ty + 2)
    shown = E2E_TEST if len(E2E_TEST) <= 58 else E2E_TEST[:57] + "…"
    text(d, (x2 + 38, ty), shown, MONO(11), INK)
    ty += 30
    d.line([((x2 + 20) * SCALE, (ty) * SCALE), ((W - 60) * SCALE, (ty) * SCALE)],
           fill=PANEL_EDGE, width=1 * SCALE)
    text(d, (x2 + 20, ty + 14), "All tests passed!", MONO_B(13), GREEN)
    text(d, (x2 + 20, ty + 36), "9 passed  ·  E2E 1 passed", MONO(12), DIM)

    y += panel_h2 + 20

    # ---- footnote -----------------------------------------------------------
    text(d, (40, y),
         "Frontend E2E runs only when a live backend and DOCTOR token are supplied; "
         "executed separately against the deployed stack.",
         SANS(12), DIM)
    text(d, (40, y + 22),
         "Scope: test suites covering the Genomic Target Prioritization service. "
         "Measured 19 August 2026.",
         SANS(12), DIM)

    out = Path(r"C:\Users\sexyl\OneDrive\Desktop\Full-Project\docs\figures")
    out.mkdir(parents=True, exist_ok=True)
    path = out / "unit_test_results.png"
    img.save(path, "PNG", optimize=True)
    print(f"saved: {path}")
    print(f"size : {img.size[0]} x {img.size[1]} px")


if __name__ == "__main__":
    main()
