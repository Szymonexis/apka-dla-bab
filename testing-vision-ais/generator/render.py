# -*- coding: utf-8 -*-
"""Render paragonu do obrazka + augmentacje (z zachowaniem bounding boxów)."""

import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance

FONTS = {
    "normal": "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
    "bold": "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf",
    "alt": "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",
    "alt_bold": "/usr/share/fonts/truetype/liberation/LiberationMono-Bold.ttf",
}

_font_cache = {}


def get_font(path, size):
    key = (path, size)
    if key not in _font_cache:
        _font_cache[key] = ImageFont.truetype(path, size)
    return _font_cache[key]


# --------------------------------------------------------------- render bazowy
def render_receipt(lines, rng, width_chars):
    """Rysuje paragon na białym tle. Zwraca (obraz, boxy).

    boxy: lista dictów {field, text, box:[x0,y0,x1,y1]}
    """
    alt = rng.random() < 0.35
    f_reg = FONTS["alt"] if alt else FONTS["normal"]
    f_bold = FONTS["alt_bold"] if alt else FONTS["bold"]

    size = rng.randint(15, 22)
    font_n = get_font(f_reg, size)
    font_b = get_font(f_bold, size)
    font_big = get_font(f_bold, int(size * 1.22))

    cw = font_n.getlength("0")
    line_h = int(size * rng.uniform(1.22, 1.55))
    margin = int(cw * rng.uniform(1.5, 4.0))

    W = int(cw * width_chars + margin * 2)
    top_pad = int(line_h * rng.uniform(1.5, 4.0))
    bot_pad = int(line_h * rng.uniform(2.0, 5.0))
    H = top_pad + line_h * len(lines) + bot_pad

    paper = tuple(rng.randint(243, 255) for _ in range(1))[0]
    paper_rgb = (paper, paper - rng.randint(0, 4), paper - rng.randint(2, 8))
    ink = rng.randint(20, 75)
    ink_rgb = (ink + rng.randint(0, 12), ink + rng.randint(0, 10), ink + rng.randint(0, 18))

    im = Image.new("RGB", (W, H), paper_rgb)
    d = ImageDraw.Draw(im)

    avail = W - 2 * max(2, int(margin * 0.5))

    def fit_font(text, base_path, base_size):
        """Dobiera rozmiar tak, aby linia zmieściła się w szerokości papieru."""
        s = base_size
        while s > 7:
            f = get_font(base_path, s)
            if f.getlength(text) <= avail:
                return f
            s -= 1
        return get_font(base_path, 7)

    boxes = []
    y = top_pad
    for text, align, style, field in lines:
        if isinstance(text, tuple):
            # para (etykieta, wartość) — wartość dosunięta do prawej krawędzi
            label, value = text
            path, bs = ((f_bold, int(size * 1.22)) if style == "big"
                        else (f_bold, size) if style == "bold" else (f_reg, size))
            font = fit_font(label + "  " + value, path, bs)
            lw = font.getlength(label)
            vw = font.getlength(value)
            d.text((margin, y), label, font=font, fill=ink_rgb)
            xv = W - margin - vw
            d.text((xv, y), value, font=font, fill=ink_rgb)
            h = font.size * 1.15
            boxes.append({"field": field, "text": label,
                          "box": [float(margin), float(y), float(margin + lw), float(y + h)]})
            boxes.append({"field": (field + ".value") if field else None, "text": value,
                          "box": [float(xv), float(y), float(xv + vw), float(y + h)]})
        elif text:
            path, bs = ((f_bold, int(size * 1.22)) if style == "big"
                        else (f_bold, size) if style == "bold" else (f_reg, size))
            font = fit_font(text, path, bs)
            tw = font.getlength(text)
            if align == "c":
                x = (W - tw) / 2
            elif align == "r":
                x = W - margin - tw
            else:
                x = margin
            d.text((x, y), text, font=font, fill=ink_rgb)
            boxes.append({
                "field": field,
                "text": text,
                "box": [float(x), float(y), float(x + tw), float(y + font.size * 1.15)],
            })
        y += line_h

    # perforacja / postrzępiona górna i dolna krawędź (jak z drukarki termicznej)
    if rng.random() < 0.5:
        _ragged_edge(im, d, rng, paper_rgb)
    return im, boxes


def _ragged_edge(im, d, rng, paper_rgb):
    W, H = im.size
    for yy, direction in ((0, 1), (H - 1, -1)):
        x = 0
        while x < W:
            step = rng.randint(4, 14)
            depth = rng.randint(0, 6)
            if direction == 1:
                d.rectangle([x, 0, x + step, depth], fill=(255, 255, 255))
            else:
                d.rectangle([x, H - depth, x + step, H], fill=(255, 255, 255))
            x += step


# --------------------------------------------------------------- homografia
def _homography(src, dst):
    """Macierz 3x3 przekształcająca punkty src -> dst (4 pary)."""
    A, b = [], []
    for (x, y), (u, v) in zip(src, dst):
        A.append([x, y, 1, 0, 0, 0, -u * x, -u * y])
        b.append(u)
        A.append([0, 0, 0, x, y, 1, -v * x, -v * y])
        b.append(v)
    h = np.linalg.solve(np.array(A, dtype=float), np.array(b, dtype=float))
    return np.append(h, 1.0).reshape(3, 3)


def _apply_h(H, pts):
    p = np.hstack([np.asarray(pts, dtype=float), np.ones((len(pts), 1))])
    q = p @ H.T
    return q[:, :2] / q[:, 2:3]


# --------------------------------------------------------------- augmentacje
def _paper_texture(size, rng):
    w, h = size
    small = np.random.default_rng(rng.randint(0, 2**31)).normal(
        0, 1, (max(2, h // 12), max(2, w // 12)))
    tex = np.array(Image.fromarray(small).resize((w, h), Image.BICUBIC))
    return tex / (tex.std() + 1e-6)


def _background(size, rng):
    w, h = size
    palettes = [
        ((168, 132, 92), (120, 88, 56)),    # drewno
        ((215, 215, 218), (176, 176, 182)),  # blat jasny
        ((58, 60, 66), (30, 31, 36)),        # ciemny blat
        ((222, 214, 196), (196, 186, 165)),  # papier/karton
        ((92, 108, 96), (58, 70, 60)),       # zielony materiał
    ]
    c1, c2 = palettes[rng.randrange(len(palettes))]
    grad_y = np.linspace(0, 1, h)[:, None]
    grad_x = np.linspace(0, 1, w)[None, :]
    t = (grad_y * rng.uniform(0.2, 0.9) + grad_x * rng.uniform(0.1, 0.7))
    t = t / (t.max() + 1e-6)
    arr = np.zeros((h, w, 3), dtype=float)
    for i in range(3):
        arr[:, :, i] = c1[i] + (c2[i] - c1[i]) * t
    # słoje / ziarno
    grain = _paper_texture((w, h), rng) * rng.uniform(4, 14)
    arr += grain[:, :, None]
    if rng.random() < 0.5:  # słoje drewna
        freq = rng.uniform(0.01, 0.05)
        stripes = np.sin(np.arange(h) * freq + rng.uniform(0, 6))[:, None] * rng.uniform(3, 10)
        arr += stripes[:, :, None]
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))


def augment(im, boxes, rng, style):
    """Zwraca (obraz, boxy, opis_augmentacji)."""
    applied = []
    W0, H0 = im.size

    # ---- skalowanie do docelowej rozdzielczości
    target_w = rng.randint(430, 780) if style == "scan" else rng.randint(520, 900)
    scale = target_w / W0
    im = im.resize((int(W0 * scale), int(H0 * scale)), Image.LANCZOS)
    S = np.array([[scale, 0, 0], [0, scale, 0], [0, 0, 1]])
    H_total = S
    W, H = im.size

    # ---- zagniecenia / fala papieru (przed geometrią)
    if rng.random() < (0.55 if style == "photo" else 0.2):
        im = _creases(im, rng)
        applied.append("zagniecenia")

    # ---- geometria: perspektywa + obrót
    src = [(0, 0), (W, 0), (W, H), (0, H)]
    jitter = (0.035 if style == "photo" else 0.008)
    dst = [(x + rng.uniform(-1, 1) * W * jitter,
            y + rng.uniform(-1, 1) * H * jitter * 0.6) for x, y in src]
    ang = math.radians(rng.uniform(-9, 9) if style == "photo" else rng.uniform(-2.5, 2.5))
    cx, cy = W / 2, H / 2
    ca, sa = math.cos(ang), math.sin(ang)
    dst = [((x - cx) * ca - (y - cy) * sa + cx,
            (x - cx) * sa + (y - cy) * ca + cy) for x, y in dst]
    xs = [p[0] for p in dst]
    ys = [p[1] for p in dst]
    ox, oy = min(xs), min(ys)
    dst = [(x - ox, y - oy) for x, y in dst]
    out_w, out_h = int(max(xs) - ox) + 1, int(max(ys) - oy) + 1

    Hf = _homography(src, dst)
    Hi = np.linalg.inv(Hf)
    coeffs = (Hi / Hi[2, 2]).flatten()[:8]
    fill = (255, 255, 255) if style == "scan" else (250, 249, 246)
    im = im.transform((out_w, out_h), Image.PERSPECTIVE, tuple(coeffs),
                      resample=Image.BICUBIC, fillcolor=fill)
    H_total = Hf @ H_total
    applied.append(f"obrot={math.degrees(ang):.1f}st")
    if style == "photo":
        applied.append("perspektywa")

    # ---- tło (zdjęcie na stole) albo białe tło skanu
    if style == "photo":
        pad_l = rng.randint(10, 90)
        pad_r = rng.randint(10, 90)
        pad_t = rng.randint(10, 80)
        pad_b = rng.randint(10, 80)
        bg = _background((im.width + pad_l + pad_r, im.height + pad_t + pad_b), rng)
        # cień pod paragonem
        shadow = Image.new("L", bg.size, 0)
        ImageDraw.Draw(shadow).polygon(
            [(x + pad_l + 6, y + pad_t + 8) for x, y in dst], fill=110)
        shadow = shadow.filter(ImageFilter.GaussianBlur(rng.uniform(4, 12)))
        bg = Image.composite(Image.new("RGB", bg.size, (0, 0, 0)), bg, shadow)
        mask = Image.new("L", im.size, 0)
        ImageDraw.Draw(mask).polygon([tuple(p) for p in dst], fill=255)
        bg.paste(im, (pad_l, pad_t), mask)
        im = bg
        T = np.array([[1, 0, pad_l], [0, 1, pad_t], [0, 0, 1]], dtype=float)
        H_total = T @ H_total
        applied.append("tlo_fotografia")
    else:
        pad = rng.randint(6, 40)
        bg = Image.new("RGB", (im.width + 2 * pad, im.height + 2 * pad), (255, 255, 255))
        bg.paste(im, (pad, pad))
        im = bg
        T = np.array([[1, 0, pad], [0, 1, pad], [0, 0, 1]], dtype=float)
        H_total = T @ H_total

    # ---- fotometria (nie zmienia geometrii)
    arr = np.asarray(im).astype(np.float32)
    h, w = arr.shape[:2]

    if style == "photo" and rng.random() < 0.8:  # nierówne oświetlenie
        gy = np.linspace(rng.uniform(0.78, 1.0), rng.uniform(0.85, 1.12), h)[:, None]
        gx = np.linspace(rng.uniform(0.8, 1.05), rng.uniform(0.85, 1.1), w)[None, :]
        arr *= (gy * gx)[:, :, None]
        applied.append("nierowne_oswietlenie")

    if rng.random() < 0.35:  # wyblakły druk termiczny
        f = rng.uniform(0.55, 0.85)
        arr = 255 - (255 - arr) * f
        applied.append("wyblakly_druk")

    noise_sigma = rng.uniform(1.5, 9.0) if style == "photo" else rng.uniform(0.5, 3.5)
    arr += np.random.default_rng(rng.randint(0, 2**31)).normal(0, noise_sigma, arr.shape)
    applied.append(f"szum={noise_sigma:.1f}")

    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))

    blur = rng.uniform(0, 1.4) if style == "photo" else rng.uniform(0, 0.6)
    if blur > 0.25:
        im = im.filter(ImageFilter.GaussianBlur(blur))
        applied.append(f"rozmycie={blur:.2f}")

    if rng.random() < 0.4:
        c = rng.uniform(0.75, 1.3)
        im = ImageEnhance.Contrast(im).enhance(c)
        applied.append(f"kontrast={c:.2f}")

    if style == "photo" and rng.random() < 0.25:
        im = im.convert("L").convert("RGB")
        applied.append("skala_szarosci")

    # ---- przeliczenie boxów
    new_boxes = []
    for b in boxes:
        x0, y0, x1, y1 = b["box"]
        corners = _apply_h(H_total, [(x0, y0), (x1, y0), (x1, y1), (x0, y1)])
        nb = [float(corners[:, 0].min()), float(corners[:, 1].min()),
              float(corners[:, 0].max()), float(corners[:, 1].max())]
        new_boxes.append({
            "field": b["field"],
            "text": b["text"],
            "box": [round(v, 1) for v in nb],
            "quad": [[round(float(px), 1), round(float(py), 1)] for px, py in corners],
        })
    return im, new_boxes, applied


def _creases(im, rng):
    """Poziome/pionowe zagniecenia papieru jako modulacja jasności."""
    arr = np.asarray(im).astype(np.float32)
    h, w = arr.shape[:2]
    mod = np.ones((h, w), dtype=np.float32)
    for _ in range(rng.randint(1, 4)):
        if rng.random() < 0.7:
            pos = rng.randint(int(h * 0.1), int(h * 0.9))
            width = rng.randint(6, 30)
            prof = np.exp(-((np.arange(h) - pos) ** 2) / (2 * width ** 2))
            mod *= (1 - prof[:, None] * rng.uniform(0.05, 0.22))
            if rng.random() < 0.5:
                mod *= (1 + np.roll(prof, width)[:, None] * rng.uniform(0.02, 0.10))
        else:
            pos = rng.randint(int(w * 0.1), int(w * 0.9))
            width = rng.randint(6, 25)
            prof = np.exp(-((np.arange(w) - pos) ** 2) / (2 * width ** 2))
            mod *= (1 - prof[None, :] * rng.uniform(0.05, 0.20))
    arr *= mod[:, :, None]
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
