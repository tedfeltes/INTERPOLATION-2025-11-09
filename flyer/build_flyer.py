#!/usr/bin/env python3
"""Joey bachelor party flyer — clean rebuild: crisp photos, real Palestine energy."""
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance, ImageOps
import os
import math

W, H = 2160, 3600

ROOT_HI = "/tmp/bachelor-photos/Joey"  # full-res sources
ROOT = "/tmp/bachelor-all"
CUT = "/tmp/bachelor-cutouts"
FONT = "/tmp/fonts"
ASSETS = "/opt/cursor/artifacts/assets"
OUTS = [
    "/opt/cursor/artifacts/joey_bachelor_party_flyer.png",
    "/opt/cursor/artifacts/joey_bachelor_party_flyer_MAX.png",
    "/workspace/flyer/joey_bachelor_party_flyer.png",
]

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


def scale_to_height(im, h):
    r = h / im.size[1]
    return im.resize((max(1, int(im.size[0] * r)), h), Image.Resampling.LANCZOS)


def scale_to_width(im, w):
    r = w / im.size[0]
    return im.resize((w, max(1, int(im.size[1] * r))), Image.Resampling.LANCZOS)


def crisp_photo(path_hi, path_lo, max_h, radius=12, feather=4):
    """Use full-res photo, minimal edge feather only — stays recognizable."""
    p = path_hi if os.path.exists(path_hi) else path_lo
    im = load(p).convert("RGB")
    im = scale_to_height(im, max_h)
    w, h = im.size
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=255)
    if feather:
        mask = mask.filter(ImageFilter.GaussianBlur(feather))
    out = im.convert("RGBA")
    out.putalpha(mask)
    return out


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


def label(text, font, bg=PAL_GREEN, fg=(255, 255, 255, 255)):
    """Solid filled Palestinian-style label — not outline boxes."""
    d0 = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    bb = d0.textbbox((0, 0), text, font=font)
    tw, th = bb[2] - bb[0] + 28, bb[3] - bb[1] + 14
    chip = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    d = ImageDraw.Draw(chip)
    d.rounded_rectangle([0, 0, tw - 1, th - 1], radius=5, fill=(*bg, 235))
    d.text((12, 4), text, font=font, fill=fg)
    return chip


def arabic_title(canvas, y, text, font, color=PAL_WHITE, shadow=PAL_RED):
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    bb = d.textbbox((0, 0), text, font=font)
    tw = bb[2] - bb[0]
    x = (W - tw) // 2
    for dx, dy in [(-3, 0), (3, 0), (0, -3), (0, 3), (-2, -2), (2, 2)]:
        d.text((x + dx, y + dy), text, font=font, fill=(*shadow, 200))
    d.text((x, y), text, font=font, fill=(*color, 255))
    return Image.alpha_composite(canvas, layer)


def english_glow(canvas, y, text, font, fill, glow):
    d = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    bb = d.textbbox((0, 0), text, font=font)
    x = (W - (bb[2] - bb[0])) // 2
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).text((x, y), text, font=font, fill=(*glow, 180))
    layer = layer.filter(ImageFilter.GaussianBlur(8))
    sharp = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(sharp).text((x, y), text, font=font, fill=fill)
    return Image.alpha_composite(Image.alpha_composite(canvas, layer), sharp)


def draw_solid_palestinian_flag(w, h):
    """Fully filled flag — not outlines."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(0, 0), (0, h), (int(w * 0.38), h // 2)], fill=(*PAL_RED, 255))
    sh = h // 3
    x0 = int(w * 0.38)
    d.rectangle([x0, 0, w, sh], fill=(*PAL_BLACK, 255))
    d.rectangle([x0, sh, w, sh * 2], fill=(*PAL_WHITE, 255))
    d.rectangle([x0, sh * 2, w, h], fill=(*PAL_GREEN, 255))
    return img


def keffiyeh_texture(w, h, alpha=35):
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    step = 24
    for x in range(-h, w + h, step):
        d.line([(x, 0), (x + h, h)], fill=(255, 255, 255, alpha), width=2)
        d.line([(x, h), (x + h, 0)], fill=(255, 255, 255, alpha), width=2)
    return layer


def tatreez_band(w, h):
    """Filled tatreez-style geometric band."""
    if os.path.exists(f"{ASSETS}/tatreez_pattern.png"):
        tex = load(f"{ASSETS}/tatreez_pattern.png")
        return cover(tex, w, h)
    img = Image.new("RGBA", (w, h), (*PAL_WHITE, 255))
    d = ImageDraw.Draw(img)
    cols = [PAL_RED, PAL_GREEN, PAL_BLACK]
    sz = 36
    for row in range(h // sz + 1):
        for col in range(w // sz + 1):
            cx, cy = col * sz + sz // 2, row * sz + sz // 2
            c = cols[(row + col) % 3]
            d.polygon([(cx, cy - sz // 3), (cx + sz // 3, cy), (cx, cy + sz // 3), (cx - sz // 3, cy)], fill=(*c, 255))
            if (row + col) % 2 == 0:
                d.rectangle([cx - 4, cy - 4, cx + 4, cy + 4], fill=(*PAL_BLACK, 255))
    return img


def palestine_hero_banner(w):
    h = 140
    banner = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    flag = draw_solid_palestinian_flag(w, h)
    tat = tatreez_band(w, 28)
    banner = Image.alpha_composite(banner, flag)
    banner.paste(tat, (0, h - 28), tat)
    return banner


def build_background():
    heli = load(f"{ROOT_HI}/IMG_5700.PNG")
    bg = cover(heli, W, H, focus=(0.5, 0.42))
    bg = ImageEnhance.Brightness(bg).enhance(0.88)
    bg = ImageEnhance.Contrast(bg).enhance(1.06)
    bg = bg.convert("RGBA")
    bg = Image.alpha_composite(bg, keffiyeh_texture(W, H, alpha=28))
    return bg


def build_chaos_hero():
    """Full chaos photo — crisp, Joey visible, light edge only."""
    return crisp_photo(
        f"{ROOT_HI}/IMG_5800.JPG",
        f"{ROOT}/p10_doll_party.jpg",
        max_h=980,
        radius=14,
        feather=3,
    )


def main():
    canvas = build_background()

    f_mega = ImageFont.truetype(f"{FONT}/Orbitron.ttf", 132)
    f_ar_xl = ImageFont.truetype(f"{FONT}/NotoNaskhArabic.ttf", 88)
    f_ar = ImageFont.truetype(f"{FONT}/NotoNaskhArabic.ttf", 52)
    f_ar_md = ImageFont.truetype(f"{FONT}/NotoNaskhArabic.ttf", 38)
    f_lab = ImageFont.truetype(f"{FONT}/Rajdhani-Bold.ttf", 26)
    f_body = ImageFont.truetype(f"{FONT}/Rajdhani-Bold.ttf", 34)
    f_sub = ImageFont.truetype(f"{FONT}/Audiowide-Regular.ttf", 26)

    # ===== PALESTINE BANNER — solid filled, top =====
    banner = palestine_hero_banner(W)
    canvas.paste(banner, (0, 0), banner)

    # Arabic on banner
    canvas = arabic_title(canvas, 18, "فلسطين في قلبي · فخر أصيل", f_ar_xl)
    canvas = arabic_title(canvas, 78, "أمي · تراثي · كرامتي", f_ar_md, PAL_WHITE, PAL_GREEN)

    y = 155
    canvas = english_glow(canvas, y, "Palestinian Pride · Authentic Heritage · Bachelor Party", f_sub, (255, 245, 230, 255), PAL_RED)
    y += 42
    canvas = english_glow(canvas, y, "JOEY'S", f_mega, (255, 255, 255, 255), (255, 50, 180))
    y += 130
    canvas = english_glow(canvas, y, "BACHELOR PARTY", f_mega, (0, 255, 235, 255), (0, 200, 255))
    y += 130
    canvas = arabic_title(canvas, y, "حفلة العزوبية · WUZ POPPIN JIMBO", f_ar_md, PAL_WHITE, PAL_RED)

    # ===== TRADITIONAL PALESTINIAN MOTHER — prominent, crisp cutout =====
    mother_path = f"{CUT}/palestinian_mother_cut.png"
    if os.path.exists(mother_path):
        mother = load(mother_path)
        mother = scale_to_height(mother, 720)
        # Solid tatreez frame behind mother (filled, not outline)
        frame = Image.new("RGBA", (mother.size[0] + 40, mother.size[1] + 40), (0, 0, 0, 0))
        tat = tatreez_band(frame.size[0], frame.size[1])
        frame.paste(tat, (0, 0))
        frame.paste(mother, (20, 20), mother)
        mx, my = 60, 520
        canvas = paste(canvas, frame, (mx, my), 1.0)
        canvas = paste(canvas, label("أمي · Palestinian Mother · Pride", f_lab, PAL_RED), (mx, my - 32))
        canvas = paste(canvas, label("فخر فلسطيني", f_lab, PAL_GREEN), (mx, my + frame.size[1] + 6))

    # Solid vertical flag strip right side — FILLED
    flag_strip = draw_solid_palestinian_flag(120, 520)
    canvas.paste(flag_strip, (W - 140, 520), flag_strip)

    # ===== CHAOS HERO — crisp, moderate size, Joey in frame =====
    hero = build_chaos_hero()
    hero_x = W // 2 + 80  # offset right so mother has space
    hero_y = 780
    canvas = paste_c(canvas, hero, hero_x, hero_y + hero.size[1] // 2, 1.0)
    canvas = paste_c(canvas, label("CHAOS MODE · JOEY FULL FRAME", f_lab, PAL_RED), hero_x, hero_y - 28)
    canvas = paste_c(canvas, label("فلسطيني · NO CROP · STILL IN IT", f_lab, PAL_GREEN), hero_x, hero_y + hero.size[1] + 8)

    # Tatreez divider band — solid filled
    div_y = hero_y + hero.size[1] + 45
    div = tatreez_band(W - 80, 36)
    canvas.paste(div, (40, div_y), div)
    canvas = arabic_title(canvas, div_y + 44, "من فلسطين · بكل فخر · SWAG · BUSSIN · MILLY ROCK", f_ar_md, PAL_WHITE, PAL_GREEN)

    # ===== SECONDARY PHOTOS — smaller, crisp, spaced, labels above =====
    photos = [
        ("cabin", "IMG_1071.jpeg", "p03_cabin_doll.jpg", "ANIME UNIT ONLINE", PAL_GREEN, 520, div_y + 110, 0),
        ("deck", "IMG_1069.jpeg", "p02_deck_doll.jpg", "PARTY BOSS DETECTED", PAL_RED, 1180, div_y + 110, 0),
        ("bar_mid", "IMG_5706.PNG", "p05_bar.jpg", "MAIN CREW // ALPHA", PAL_GREEN, 640, div_y + 680, 0),
        ("skin", "IMG_5784.PNG", "p09_doll_close.jpg", "SKIN RENDER", PAL_RED, 120, div_y + 1180, 0),
        ("wall", "IMG_0279.jpg", "p01_doll_wall.jpg", "BOSS MOB", PAL_GREEN, 920, div_y + 1180, 0),
        ("ride", "IMG_5780.PNG", "p06_ride_energy.jpg", "ENERGY SPIKE", (0, 200, 255), 1580, div_y + 1180, 0),
        ("screen", "IMG_5781.PNG", "p07_ride_screen.jpg", "THRILL FEED", PAL_RED, 120, div_y + 1680, 0),
        ("face", "IMG_5783.PNG", "p08_ride_face.jpg", "JOY+", PAL_GREEN, 720, div_y + 1680, 0),
    ]

    for _, hi, lo, lbl, col, px, py, _ in photos:
        im = crisp_photo(f"{ROOT_HI}/{hi}", f"{ROOT}/{lo}", max_h=480, radius=10, feather=3)
        canvas = paste(canvas, im, (px, py), 1.0)
        canvas = paste(canvas, label(lbl, f_lab, col), (px, py - 28))

    # Bottom tatreez + footer
    foot_band = tatreez_band(W - 80, 32)
    canvas.paste(foot_band, (40, H - 120), foot_band)
    canvas = arabic_title(canvas, H - 105, "فلسطين · إلى المستقبل · SWAG TO THE MOON", f_ar_md, PAL_WHITE, PAL_GREEN)
    canvas = english_glow(canvas, H - 55, "SAVE THE DATE · DETAILS INCOMING · BRING YOUR BEST CHAOS", f_body, (255, 255, 255, 255), PAL_RED)

    canvas = paste(canvas, label("SQUAD: ONLINE", f_lab, PAL_GREEN), (80, H - 165))
    canvas = paste(canvas, label("STATUS: UNHINGED", f_lab, PAL_RED), (1680, H - 165))

    final = canvas.convert("RGB")
    for p in OUTS:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        final.save(p, "PNG", optimize=True)

    story = cover(final.convert("RGBA"), 1080, 1920, (0.5, 0.38)).convert("RGB")
    story.save("/opt/cursor/artifacts/joey_bachelor_party_flyer_story.png", "PNG", optimize=True)
    story.save("/workspace/flyer/joey_bachelor_party_flyer_story.png", "PNG", optimize=True)

    final.resize((720, int(720 * H / W))).save("/tmp/flyer_v4_review.jpg", quality=92)
    print("v4 OK", final.size)


if __name__ == "__main__":
    main()
