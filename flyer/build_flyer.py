#!/usr/bin/env python3
"""Joey bachelor party flyer — full rebuild from scratch."""
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance, ImageOps, ImageChops
import os
import random

W, H = 2160, 3800
random.seed(2026)

ROOT = "/tmp/bachelor-all"
CUT = "/tmp/bachelor-cutouts"
FONT = "/tmp/fonts"
OUTS = [
    "/opt/cursor/artifacts/joey_bachelor_party_flyer.png",
    "/opt/cursor/artifacts/joey_bachelor_party_flyer_MAX.png",
    "/workspace/flyer/joey_bachelor_party_flyer.png",
]

# Palestinian flag colors
PAL_GREEN = (0, 122, 61)
PAL_RED = (206, 17, 38)
PAL_BLACK = (0, 0, 0)
PAL_WHITE = (255, 255, 255)


def load(path):
    im = Image.open(path)
    try:
        im = ImageOps.exif_transpose(im)
    except Exception:
        pass
    return im.convert("RGBA")


def cover(im, tw, th, focus=(0.5, 0.45)):
    iw, ih = im.size
    s = max(tw / iw, th / ih)
    nw, nh = int(iw * s + 0.5), int(ih * s + 0.5)
    im2 = im.resize((nw, nh), Image.Resampling.LANCZOS)
    cx, cy = int(nw * focus[0]), int(nh * focus[1])
    left = max(0, min(cx - tw // 2, nw - tw))
    top = max(0, min(cy - th // 2, nh - th))
    return im2.crop((left, top, left + tw, top + th))


def rh(im, h):
    r = h / im.size[1]
    return im.resize((max(1, int(im.size[0] * r)), h), Image.Resampling.LANCZOS)


def rw(im, w):
    r = w / im.size[0]
    return im.resize((w, max(1, int(im.size[1] * r))), Image.Resampling.LANCZOS)


def grade(im, hot=False):
    r, g, b, a = im.split()
    if hot:
        r = r.point(lambda p: min(255, int(p * 1.12 + 8)))
        g = g.point(lambda p: min(255, int(p * 0.94)))
        b = b.point(lambda p: min(255, int(p * 1.08 + 6)))
    else:
        r = r.point(lambda p: min(255, int(p * 1.04 + 4)))
        b = b.point(lambda p: min(255, int(p * 1.1 + 10)))
    out = Image.merge("RGBA", (r, g, b, a))
    return ImageEnhance.Color(ImageEnhance.Contrast(out).enhance(1.1)).enhance(1.2)


def neon_glow(im, color=(0, 255, 230), blur=16, strength=0.4):
    """Neon rim only — transparent outside subject."""
    a = im.split()[-1]
    aura = Image.new("RGBA", im.size, (*color, 0))
    exp = a.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.GaussianBlur(blur))
    exp = exp.point(lambda p: int(p * strength))
    aura.putalpha(exp)
    base = Image.new("RGBA", im.size, (0, 0, 0, 0))
    return Image.alpha_composite(Image.alpha_composite(base, aura), im)


def paste(base, im, xy, opacity=1.0):
    if opacity < 1:
        a = im.split()[-1].point(lambda p: int(p * opacity))
        im = im.copy()
        im.putalpha(a)
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    layer.paste(im, (int(xy[0]), int(xy[1])), im)
    return Image.alpha_composite(base, layer)


def paste_c(base, im, cx, cy, opacity=1.0):
    return paste(base, im, (cx - im.size[0] // 2, cy - im.size[1] // 2), opacity)


def label(text, font, neon=(0, 255, 230)):
    d0 = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    bb = d0.textbbox((0, 0), text, font=font)
    tw, th = bb[2] - bb[0] + 32, bb[3] - bb[1] + 16
    chip = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    d = ImageDraw.Draw(chip)
    d.rounded_rectangle([0, 0, tw - 1, th - 1], radius=6, fill=(8, 0, 20, 210), outline=(*neon, 255), width=2)
    d.text((12, 5), text, font=font, fill=(255, 255, 255, 255))
    d.ellipse([tw - 14, th // 2 - 3, tw - 6, th // 2 + 3], fill=(0, 255, 140, 255))
    return chip


def text_glow(canvas, xy, text, font, fill, glow, blur=12):
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).text(xy, text, font=font, fill=(*glow, 210))
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    sharp = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(sharp)
    x, y = xy
    for dx, dy in [(-2, 0), (2, 0), (0, -2), (0, 2)]:
        sd.text((x + dx, y + dy), text, font=font, fill=(0, 0, 0, 170))
    sd.text(xy, text, font=font, fill=fill)
    return Image.alpha_composite(Image.alpha_composite(canvas, layer), sharp)


def center_text(canvas, y, text, font, fill, glow, blur=12):
    bb = ImageDraw.Draw(Image.new("RGBA", (1, 1))).textbbox((0, 0), text, font=font)
    x = (W - (bb[2] - bb[0])) // 2
    return text_glow(canvas, (x, y), text, font, fill, glow, blur)


def mixed_stamp(en, ar, jp, f_en, f_ar, f_jp, color=(255, 40, 180)):
    d0 = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    b1 = d0.textbbox((0, 0), en, font=f_en)
    b2 = d0.textbbox((0, 0), ar, font=f_ar)
    b3 = d0.textbbox((0, 0), jp, font=f_jp)
    tw = max(b1[2] - b1[0], b2[2] - b2[0], b3[2] - b3[0]) + 32
    th = (b1[3] - b1[1]) + (b2[3] - b2[1]) + (b3[3] - b3[1]) + 36
    img = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    y = 8
    for t, f in [(en, f_en), (ar, f_ar), (jp, f_jp)]:
        for dx, dy in [(-2, 0), (2, 0), (0, -2), (0, 2)]:
            d.text((16 + dx, y + dy), t, font=f, fill=(0, 0, 0, 220))
        d.text((16, y), t, font=f, fill=(*color, 255) if t == en else (255, 255, 255, 240))
        y += d.textbbox((0, 0), t, font=f)[3] - d.textbbox((0, 0), t, font=f)[1] + 6
    return img


def keffiyeh_overlay(w, h, opacity=28):
    """Subtle keffiyeh fishnet pattern."""
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    step = 28
    for x in range(-h, w + h, step):
        d.line([(x, 0), (x + h, h)], fill=(255, 255, 255, opacity), width=1)
        d.line([(x, h), (x + h, 0)], fill=(255, 255, 255, opacity), width=1)
    return layer


def palestinian_flag_neon(w, h):
    """Stylized neon Palestinian flag stripe block."""
    flag = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(flag)
    # Triangle on hoist
    d.polygon([(0, 0), (0, h), (int(w * 0.35), h // 2)], fill=(*PAL_RED, 220))
    # Stripes
    sh = h // 3
    d.rectangle([int(w * 0.35), 0, w, sh], fill=(*PAL_BLACK, 200))
    d.rectangle([int(w * 0.35), sh, w, sh * 2], fill=(*PAL_WHITE, 200))
    d.rectangle([int(w * 0.35), sh * 2, w, h], fill=(*PAL_GREEN, 200))
    return flag.filter(ImageFilter.GaussianBlur(1))


def build_chaos_hero():
    """Full chaos photo with Joey on right — transparent, no black box."""
    full = grade(load(f"{ROOT}/p10_doll_party.jpg"), hot=True)
    cut = load(f"{CUT}/p10_doll_party_cut.png")
    a = cut.split()[-1].resize(full.size, Image.Resampling.LANCZOS)
    a = a.filter(ImageFilter.MaxFilter(19))
    # Preserve right side (Joey)
    rx0 = int(full.size[0] * 0.38)
    right = Image.new("L", full.size, 0)
    rp = right.load()
    ww, hh = full.size
    for x in range(rx0, ww):
        v = min(255, int(255 * ((x - rx0) / max(1, (ww - rx0) * 0.18))))
        for y in range(hh):
            rp[x, y] = v
    mask = ImageChops.lighter(a, right).filter(ImageFilter.GaussianBlur(2))
    out = full.copy()
    out.putalpha(mask)
    return out


def build_background():
    heli = load(f"{ROOT}/p04_heli.jpg")
    bg = cover(heli, W, H, focus=(0.5, 0.42))
    bg = ImageEnhance.Brightness(bg).enhance(0.82)
    bg = ImageEnhance.Contrast(bg).enhance(1.1)
    bg = ImageEnhance.Color(bg).enhance(1.12)
    bg = bg.convert("RGBA")

    # Light top vignette for title readability only
    vig = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    vd = ImageDraw.Draw(vig)
    for i in range(320):
        vd.line([(0, i), (W, i)], fill=(0, 0, 20, int(65 * (1 - i / 320))))
    bg = Image.alpha_composite(bg, vig)

    # Keffiyeh heritage overlay
    bg = Image.alpha_composite(bg, keffiyeh_overlay(W, H, opacity=22))

    # Palestinian flag accent — left vertical band
    flag = palestinian_flag_neon(180, H - 80)
    bg = paste(bg, flag, (20, 40), 0.55)

    # Neon frame
    fx = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fx)
    fd.rectangle([12, 12, W - 13, H - 13], outline=(*PAL_GREEN, 200), width=4)
    fd.rectangle([24, 24, W - 25, H - 25], outline=(0, 255, 230, 120), width=2)
    for x, y, sx, sy in [(34, 34, 1, 1), (W - 35, 34, -1, 1), (34, H - 35, 1, -1), (W - 35, H - 35, -1, -1)]:
        fd.line([(x, y), (x + sx * 90, y)], fill=(*PAL_RED, 230), width=5)
        fd.line([(x, y), (x, y + sy * 90)], fill=(*PAL_RED, 230), width=5)
    return Image.alpha_composite(bg, fx)


def main():
    canvas = build_background()

    # Fonts
    f_mega = ImageFont.truetype(f"{FONT}/Orbitron.ttf", 148)
    f_ar_lg = ImageFont.truetype(f"{FONT}/NotoNaskhArabic.ttf", 72)
    f_ar = ImageFont.truetype(f"{FONT}/NotoNaskhArabic.ttf", 44)
    f_jp = ImageFont.truetype(f"{FONT}/ZenKakuGothicNew-Bold.ttf", 36)
    f_sub = ImageFont.truetype(f"{FONT}/Audiowide-Regular.ttf", 28)
    f_lab = ImageFont.truetype(f"{FONT}/Rajdhani-Bold.ttf", 28)
    f_body = ImageFont.truetype(f"{FONT}/Rajdhani-Bold.ttf", 36)
    f_stamp = ImageFont.truetype(f"{FONT}/Orbitron.ttf", 34)

    # Load transparent cutouts
    photos = {
        "bar": grade(load(f"{CUT}/p05_bar_cut.png")),
        "cabin": grade(load(f"{CUT}/p03_cabin_doll_cut.png"), hot=True),
        "deck": grade(load(f"{CUT}/p02_deck_doll_cut.png")),
        "wall": grade(load(f"{CUT}/p01_doll_wall_cut.png"), hot=True),
        "ride": grade(load(f"{CUT}/p06_ride_energy_cut.png")),
        "screen": grade(load(f"{CUT}/p07_ride_screen_cut.png")),
        "face": grade(load(f"{CUT}/p08_ride_face_cut.png"), hot=True),
        "dclose": grade(load(f"{CUT}/p09_doll_close_cut.png"), hot=True),
    }
    chaos = build_chaos_hero()

    # Optional anime/money assets (transparent only, gutters)
    extras = {}
    for key, fname in [
        ("girl", "anime_char_girl_cut.png"),
        ("money", "benjamin_stacks_cut.png"),
        ("optimus", "optimus_anime_cut.png"),
        ("ufo", "ufo_alien_cap_cut.png"),
    ]:
        p = f"{CUT}/{fname}"
        if os.path.exists(p):
            extras[key] = load(p)

    # ===== TITLE — Palestinian heritage front and center =====
    canvas = center_text(canvas, 40, "فلسطين · فخر · ثقافة", f_ar_lg, (255, 255, 255, 255), PAL_GREEN, 14)
    canvas = center_text(canvas, 130, "Palestinian Pride · Authentic Heritage · Bachelor Party", f_sub, (255, 230, 200, 250), PAL_RED, 6)
    canvas = center_text(canvas, 175, "JOEY'S", f_mega, (255, 255, 255, 255), (255, 50, 180), 16)
    canvas = center_text(canvas, 320, "BACHELOR", f_mega, (0, 255, 235, 255), (0, 200, 255), 16)
    canvas = center_text(canvas, 465, "PARTY", f_mega, (255, 70, 210, 255), (255, 40, 180), 16)
    canvas = center_text(canvas, 540, "حفلة العزوبية · バチェラー · WUZ POPPIN JIMBO", f_ar, (255, 255, 255, 245), PAL_GREEN, 8)

    # Heritage stamp left gutter
    stamp = mixed_stamp("PALESTINE", "فلسطيني أصيل", "夜遊宴", f_stamp, f_ar, f_jp, PAL_RED)
    canvas = paste(canvas, stamp.rotate(-8, expand=True, resample=Image.Resampling.BICUBIC), (40, 620), 0.95)

    # Side extras — transparent, never over hero
    if "money" in extras:
        canvas = paste(canvas, neon_glow(rh(extras["money"], 420), (255, 210, 60)), (1780, 160), 1.0)
        canvas = paste(canvas, neon_glow(rh(extras["money"], 380), (255, 210, 60)), (40, 3000), 1.0)
    if "girl" in extras:
        canvas = paste(canvas, neon_glow(rh(extras["girl"], 780), (255, 40, 180)), (1560, 520), 0.85)
    if "optimus" in extras:
        canvas = paste(canvas, neon_glow(rh(extras["optimus"], 760), (255, 90, 40)), (-60, 900), 0.85)
    if "ufo" in extras:
        canvas = paste(canvas, neon_glow(rw(extras["ufo"], 380), (100, 255, 80)), (1700, 50), 1.0)

    # ===== HERO: CHAOS MODE — full Joey, transparent, NO black plate =====
    hero_h = 1320
    hero = rh(chaos, hero_h)
    hero = neon_glow(hero, (255, 170, 70), 20, 0.42)
    hero_y = 620
    canvas = paste_c(canvas, hero, W // 2, hero_y + hero.size[1] // 2, 1.0)
    canvas = paste_c(canvas, label("CHAOS MODE // JOEY FULL FRAME", f_lab, (255, 170, 70)), W // 2, hero_y - 18)
    canvas = paste_c(canvas, label("فخر فلسطيني · STACKIN · NO CROP", f_lab, (*PAL_GREEN,)), W // 2, hero_y + hero.size[1] + 10)

    band = hero_y + hero.size[1] + 55
    canvas = center_text(canvas, band, "金 · SWAG · BUSSIN · MILLY ROCK · CANT TOUCH MY SWAG", f_sub, (255, 230, 120, 250), (255, 180, 40), 5)

    # ===== ROW 1 — BIG transparent cutouts, labels above, spaced apart =====
    r1y = band + 70
    p_cabin = neon_glow(rh(photos["cabin"], 920), (255, 70, 190), 14, 0.42)
    canvas = paste(canvas, p_cabin.rotate(-2, expand=True, resample=Image.Resampling.BICUBIC), (80, r1y), 1.0)
    canvas = paste(canvas, label("ANIME UNIT ONLINE", f_lab, (255, 70, 190)), (100, r1y - 34))

    p_deck = neon_glow(rh(photos["deck"], 920), (80, 200, 255), 14, 0.42)
    canvas = paste(canvas, p_deck.rotate(2, expand=True, resample=Image.Resampling.BICUBIC), (1120, r1y), 1.0)
    canvas = paste(canvas, label("PARTY BOSS DETECTED", f_lab, (80, 200, 255)), (1140, r1y - 34))

    # ===== ROW 2 — thrill / energy / joy — BIG, separated =====
    r2y = r1y + 980
    p_screen = neon_glow(rw(photos["screen"], 720), (90, 200, 255), 12, 0.4)
    canvas = paste(canvas, p_screen.rotate(-4, expand=True, resample=Image.Resampling.BICUBIC), (60, r2y), 1.0)
    canvas = paste(canvas, label("THRILL FEED", f_lab, (90, 200, 255)), (80, r2y - 34))

    p_ride = neon_glow(rw(photos["ride"], 920), (0, 255, 220), 12, 0.4)
    canvas = paste_c(canvas, p_ride.rotate(3, expand=True, resample=Image.Resampling.BICUBIC), W // 2, r2y + 120, 1.0)
    canvas = paste_c(canvas, label("ENERGY SPIKE", f_lab, (0, 255, 220)), W // 2, r2y - 20)

    p_face = neon_glow(rh(photos["face"], 460), (255, 80, 200), 12, 0.42)
    canvas = paste(canvas, p_face.rotate(8, expand=True, resample=Image.Resampling.BICUBIC), (1680, r2y), 1.0)
    canvas = paste(canvas, label("JOY+", f_lab, (255, 80, 200)), (1700, r2y - 34))

    # ===== ROW 3 — skin render LEFT | wall RIGHT — far apart =====
    r3y = r2y + 420
    canvas = center_text(canvas, r3y, "SKIN RENDER × スキン  ·  FLY LIKE A G6 × 空へ", f_sub, (255, 180, 220, 250), (255, 80, 180), 5)
    r3y += 50

    p_skin = neon_glow(rh(photos["dclose"], 860), (255, 100, 210), 14, 0.45)
    canvas = paste(canvas, p_skin.rotate(-6, expand=True, resample=Image.Resampling.BICUBIC), (100, r3y), 1.0)
    canvas = paste(canvas, label("SKIN RENDER // スキン", f_lab, (255, 100, 210)), (120, r3y - 34))

    p_wall = neon_glow(rh(photos["wall"], 860), (255, 60, 190), 14, 0.42)
    canvas = paste(canvas, p_wall.rotate(5, expand=True, resample=Image.Resampling.BICUBIC), (1180, r3y), 1.0)
    canvas = paste(canvas, label("BOSS MOB // 空へ", f_lab, (255, 190, 60)), (1200, r3y - 34))

    # ===== MAIN CREW bottom =====
    r4y = r3y + 940
    p_bar = neon_glow(rw(photos["bar"], 1380), (0, 255, 230), 16, 0.42)
    canvas = paste_c(canvas, p_bar, W // 2, r4y + p_bar.size[1] // 2, 1.0)
    canvas = paste_c(canvas, label("MAIN CREW // ALPHA // 本隊", f_lab, (0, 255, 230)), W // 2, r4y - 28)

    # Status + heritage footer
    canvas = paste(canvas, label("SQUAD: ONLINE", f_lab, (0, 255, 180)), (80, H - 90))
    canvas = paste(canvas, label("STATUS: UNHINGED", f_lab, (255, 160, 60)), (1680, H - 90))
    canvas = paste(canvas, label("ID: JOEY-01", f_lab, (*PAL_GREEN,)), (880, 30))

    canvas = center_text(canvas, H - 150, "SAVE THE DATE · DETAILS INCOMING · BRING YOUR BEST CHAOS", f_body, (255, 255, 255, 255), (255, 60, 180), 7)
    canvas = center_text(canvas, H - 95, "فلسطين · 未来へ · TO THE FUTURE · SWAG TO THE MOON", f_ar, (180, 255, 250, 255), PAL_GREEN, 8)

    # Light scanlines
    scan = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(scan)
    for y in range(0, H, 4):
        sd.line([(0, y), (W, y)], fill=(0, 0, 0, 8))
    canvas = Image.alpha_composite(canvas, scan)

    final = canvas.convert("RGB")
    for p in OUTS:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        final.save(p, "PNG", optimize=True)

    story = cover(final.convert("RGBA"), 1080, 1920, (0.5, 0.4)).convert("RGB")
    story.save("/opt/cursor/artifacts/joey_bachelor_party_flyer_story.png", "PNG", optimize=True)
    story.save("/workspace/flyer/joey_bachelor_party_flyer_story.png", "PNG", optimize=True)

    final.resize((720, int(720 * H / W))).save("/tmp/flyer_rebuild_review.jpg", quality=90)
    print("REBUILD OK", final.size, "photos:", len(photos) + 1)


if __name__ == "__main__":
    main()
