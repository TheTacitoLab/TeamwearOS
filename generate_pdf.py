from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib import colors
from reportlab.lib.colors import HexColor

W, H = A4
OUT = "/home/user/TeamwearOS/TeamwearOS_Image_Naming_Guide.pdf"

DARK_BG   = HexColor("#0f172a")
CARD_BG   = HexColor("#1e293b")
CARD2_BG  = HexColor("#162032")
ORANGE    = HexColor("#f97316")
BLUE      = HexColor("#38bdf8")
GREEN     = HexColor("#4ade80")
PURPLE    = HexColor("#a78bfa")
MUTED     = HexColor("#94a3b8")
WHITE     = HexColor("#f1f5f9")
RULE      = HexColor("#334155")
MONO_BG   = HexColor("#0d1b2a")

c = canvas.Canvas(OUT, pagesize=A4)
c.setTitle("TeamwearOS — Product Image Naming Guide")

# ── background ──────────────────────────────────────────────────────────────
c.setFillColor(DARK_BG)
c.rect(0, 0, W, H, fill=1, stroke=0)

y = H  # cursor from top — we'll subtract as we go

# ── header band ─────────────────────────────────────────────────────────────
HEADER_H = 28*mm
c.setFillColor(ORANGE)
c.rect(0, H - HEADER_H, W, HEADER_H, fill=1, stroke=0)

c.setFillColor(DARK_BG)
c.setFont("Helvetica-Bold", 17)
c.drawString(12*mm, H - 17*mm, "TeamwearOS")
c.setFont("Helvetica", 17)
c.drawString(12*mm + c.stringWidth("TeamwearOS", "Helvetica-Bold", 17) + 3, H - 17*mm, "— Product Image Naming Guide")

c.setFont("Helvetica", 8.5)
c.setFillColor(DARK_BG)
c.drawRightString(W - 12*mm, H - 22*mm, "Upload images for Shopify store creation")

y = H - HEADER_H - 6*mm

# ── helpers ──────────────────────────────────────────────────────────────────
def section_label(label, cy, col=ORANGE):
    c.setFillColor(col)
    c.setFont("Helvetica-Bold", 7.5)
    c.drawString(12*mm, cy, label.upper())
    c.setStrokeColor(col)
    c.setLineWidth(0.5)
    lx = 12*mm + c.stringWidth(label.upper(), "Helvetica-Bold", 7.5) + 3
    c.line(lx, cy + 1.5, W - 12*mm, cy + 1.5)
    return cy - 5*mm

def code_pill(text, cx, cy, bg=MONO_BG, fg=GREEN, font_size=8):
    tw = c.stringWidth(text, "Courier-Bold", font_size)
    pad_x, pad_y, r = 2.8*mm, 1.4*mm, 1.5*mm
    bw = tw + 2*pad_x
    bh = font_size*0.37*mm*2 + 2*pad_y
    # rounded rect via clipping trick — just do a simple rect
    c.setFillColor(bg)
    c.roundRect(cx, cy - pad_y, bw, bh, r, fill=1, stroke=0)
    c.setFillColor(fg)
    c.setFont("Courier-Bold", font_size)
    c.drawString(cx + pad_x, cy + 0.5, text)
    return bw  # width consumed

def row_bg(cy, rh, col=CARD_BG):
    c.setFillColor(col)
    c.rect(10*mm, cy - 1.2*mm, W - 20*mm, rh, fill=1, stroke=0)

def rule(cy):
    c.setStrokeColor(RULE)
    c.setLineWidth(0.3)
    c.line(12*mm, cy, W - 12*mm, cy)

# ── INTRO CARD ───────────────────────────────────────────────────────────────
INTRO_H = 18*mm
c.setFillColor(CARD_BG)
c.roundRect(10*mm, y - INTRO_H, W - 20*mm, INTRO_H, 2*mm, fill=1, stroke=0)

c.setFillColor(ORANGE)
c.setFont("Helvetica-Bold", 9)
c.drawString(15*mm, y - 7*mm, "The one rule to remember:")
c.setFillColor(WHITE)
c.setFont("Helvetica", 8.5)
c.drawString(15*mm, y - 12.5*mm, "Replace every")
x_after = 15*mm + c.stringWidth("Replace every ", "Helvetica", 8.5)
code_pill(" / ", x_after, y - 13.5*mm, fg=ORANGE, font_size=8.5)
x_after += c.stringWidth(" /  ", "Courier-Bold", 8.5) + 7
c.setFillColor(WHITE)
c.setFont("Helvetica", 8.5)
c.drawString(x_after, y - 12.5*mm, "in your product SKU with a")
x_after2 = x_after + c.stringWidth("in your product SKU with a ", "Helvetica", 8.5)
code_pill(" - ", x_after2, y - 13.5*mm, fg=ORANGE, font_size=8.5)
x_after2 += c.stringWidth(" -  ", "Courier-Bold", 8.5) + 7
c.setFillColor(WHITE)
c.setFont("Helvetica", 8.5)
c.drawString(x_after2, y - 12.5*mm, "in the filename.  That's it.")

# example
c.setFillColor(MUTED)
c.setFont("Helvetica", 8)
c.drawString(15*mm, y - 17*mm, "SKU: APX/ATL/001    →    File:")
ex_x = 15*mm + c.stringWidth("SKU: APX/ATL/001    →    File: ", "Helvetica", 8)
code_pill("APX-ATL-001.png", ex_x, y - 18*mm, fg=GREEN, font_size=8)

y -= INTRO_H + 6*mm

# ── SECTION 1: structure ──────────────────────────────────────────────────────
y = section_label("Filename structure", y)

c.setFillColor(CARD_BG)
c.roundRect(10*mm, y - 12*mm, W - 20*mm, 12*mm, 2*mm, fill=1, stroke=0)

parts = [
    ("PRODUCT-CODE", GREEN,  "required"),
    (" - ",          MUTED,  ""),
    ("VIEW",         BLUE,   "optional"),
    (" - ",          MUTED,  ""),
    ("V2 or P2",     PURPLE, "optional"),
    (" - ",          MUTED,  ""),
    ("NAME",         ORANGE, "optional"),
    (".png",         MUTED,  ""),
]
px = 15*mm
py_main = y - 6.5*mm
for txt, col, _ in parts:
    c.setFillColor(col)
    c.setFont("Courier-Bold", 9)
    c.drawString(px, py_main, txt)
    px += c.stringWidth(txt, "Courier-Bold", 9)

# labels below
px = 15*mm
for txt, col, lbl in parts:
    if lbl:
        mid = px + c.stringWidth(txt, "Courier-Bold", 9) / 2
        c.setStrokeColor(col)
        c.setFillColor(col)
        c.setLineWidth(0.4)
        c.line(mid, py_main - 1, mid, py_main - 3.2*mm)
        c.setFont("Helvetica", 6.5)
        c.drawCentredString(mid, py_main - 4.5*mm, lbl)
    px += c.stringWidth(txt, "Courier-Bold", 9)

y -= 12*mm + 7*mm

# ── SECTION 2: view angles ────────────────────────────────────────────────────
y = section_label("View angles (add after product code)", y, col=BLUE)

views = [
    ("-FRONT  or  -F",  "Front view (default — can be omitted entirely)"),
    ("-BACK   or  -B",  "Back view"),
    ("-REAR   or  -R",  "Back view (alternative spelling)"),
    ("-SIDE   or  -S",  "Side view"),
    ("-TOP    or  -T",  "Top-down view"),
    ("-DETAIL or  -DTL","Close-up / detail shot"),
    ("-INSIDE or  -IN", "Inside / lining view"),
]

ROW_H = 6.2*mm
for i, (sfx, desc) in enumerate(views):
    ry = y - (i+1)*ROW_H
    if i % 2 == 0:
        c.setFillColor(CARD_BG)
        c.rect(10*mm, ry - 1*mm, W - 20*mm, ROW_H, fill=1, stroke=0)
    c.setFillColor(BLUE)
    c.setFont("Courier-Bold", 8)
    c.drawString(15*mm, ry + 1.2*mm, sfx)
    c.setFillColor(MUTED)
    c.setFont("Helvetica", 8)
    c.drawString(70*mm, ry + 1.2*mm, desc)

y -= len(views)*ROW_H + 7*mm

# ── SECTION 3: variants and listings ─────────────────────────────────────────
# two columns
COL_W = (W - 28*mm) / 2
LEFT_X  = 10*mm
RIGHT_X = 10*mm + COL_W + 8*mm

def mini_section(sx, sy, title, col, items, note=None):
    c.setFillColor(col)
    c.setFont("Helvetica-Bold", 7.5)
    c.drawString(sx, sy, title.upper())
    c.setStrokeColor(col)
    c.setLineWidth(0.4)
    lx2 = sx + c.stringWidth(title.upper(), "Helvetica-Bold", 7.5) + 3
    c.line(lx2, sy + 1.5, sx + COL_W, sy + 1.5)
    cy = sy - 5*mm
    for code_txt, desc_txt in items:
        c.setFillColor(col)
        c.setFont("Courier-Bold", 7.5)
        c.drawString(sx, cy, code_txt)
        c.setFillColor(MUTED)
        c.setFont("Helvetica", 7.5)
        c.drawString(sx + 38*mm, cy, desc_txt)
        cy -= 5*mm
    if note:
        c.setFillColor(MUTED)
        c.setFont("Helvetica-Oblique", 7)
        c.drawString(sx, cy - 1*mm, note)
        cy -= 4.5*mm
    return cy

variant_items = [
    ("-V2", "2nd colourway"),
    ("-V3", "3rd colourway"),
    ("-V2-RED", "named Red"),
    ("-V3-NAVY", "named Navy"),
]
listing_items = [
    ("-P2", "2nd listing"),
    ("-P3", "3rd listing"),
    ("-P2-HOME", "named Home"),
    ("-P3-AWAY", "named Away"),
]

mini_section(LEFT_X,  y, "-V  Colour / Style Variants", PURPLE, variant_items,
             note="V1 is never written — plain filename = V1")
mini_section(RIGHT_X, y, "-P  Separate Listings",        ORANGE, listing_items,
             note="P1 is never written — plain filename = P1")

y -= 5*mm + len(variant_items)*5*mm + 8*mm + 7*mm

# ── SECTION 4: examples ───────────────────────────────────────────────────────
y = section_label("Real examples  (SKU: APX/ATL/001)", y, col=GREEN)

examples = [
    ("APX-ATL-001.png",             "Primary image, front view, style 1"),
    ("APX-ATL-001-BACK.png",        "Back view of the same product"),
    ("APX-ATL-001-DETAIL.png",      "Close-up shot"),
    ("APX-ATL-001-V2-RED.png",      "Red colourway, front view"),
    ("APX-ATL-001-BACK-V2-RED.png", "Red colourway, back view"),
    ("APX-ATL-001-P2-HOME.png",     "Separate 'Home' kit listing"),
    ("APX-ATL-001-BACK-P3-AWAY.png","'Away' kit listing, back view"),
    ("collection-image.png",        "Club collection banner (special — exact name, no SKU)"),
]

EX_H = 6*mm
for i, (fn, desc) in enumerate(examples):
    ey = y - (i+1)*EX_H
    if i % 2 == 0:
        c.setFillColor(CARD2_BG)
        c.rect(10*mm, ey - 1*mm, W - 20*mm, EX_H, fill=1, stroke=0)
    tw = code_pill(fn, 15*mm, ey + 0.8*mm, fg=GREEN, font_size=8)
    c.setFillColor(MUTED)
    c.setFont("Helvetica", 8)
    c.drawString(15*mm + tw + 4*mm, ey + 1.2*mm, desc)

y -= len(examples)*EX_H + 8*mm

# ── SECTION 5: order of parts ──────────────────────────────────────────────────
y = section_label("Quick reference — order of filename parts", y, col=MUTED)

c.setFillColor(CARD_BG)
c.roundRect(10*mm, y - 14*mm, W - 20*mm, 14*mm, 2*mm, fill=1, stroke=0)

tips = [
    (GREEN,  "1",  "Product code   (always first — dashes not slashes)"),
    (BLUE,   "2",  "View angle     (FRONT / BACK / SIDE etc.)   — optional"),
    (PURPLE, "3",  "Variant (-V2)  OR  Listing (-P2)   — optional, never both"),
    (ORANGE, "4",  "Name           (e.g. RED, HOME, AWAY)   — optional, after V or P number"),
]
for j, (col, num, txt) in enumerate(tips):
    ty = y - 4.5*mm - j*3*mm
    c.setFillColor(col)
    c.setFont("Helvetica-Bold", 8)
    c.drawString(15*mm, ty, f"{num}.")
    c.setFillColor(WHITE)
    c.setFont("Helvetica", 8)
    c.drawString(20*mm, ty, txt)

y -= 14*mm + 7*mm

# ── footer ────────────────────────────────────────────────────────────────────
c.setStrokeColor(RULE)
c.setLineWidth(0.4)
c.line(12*mm, 10*mm, W - 12*mm, 10*mm)
c.setFillColor(MUTED)
c.setFont("Helvetica", 7)
c.drawString(12*mm, 6.5*mm, "TeamwearOS  ·  Product Image Naming Guide")
c.drawRightString(W - 12*mm, 6.5*mm, "V and P are mutually exclusive on any single filename")

c.save()
print(f"PDF saved to {OUT}")
