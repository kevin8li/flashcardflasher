from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "FlashcardGenerator" / "AppIcons"
OUT_DIR.mkdir(parents=True, exist_ok=True)

FONT_CANDIDATES = [
    "/System/Library/Fonts/STHeiti Medium.ttc",
    "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "/System/Library/Fonts/PingFang.ttc",
    "/System/Library/Fonts/SFNS.ttf",
]


def font(size: int) -> ImageFont.FreeTypeFont:
    for candidate in FONT_CANDIDATES:
        path = Path(candidate)
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def text_center(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, text_font, fill):
    bbox = draw.textbbox((0, 0), text, font=text_font)
    width = bbox[2] - bbox[0]
    height = bbox[3] - bbox[1]
    draw.text((xy[0] - width / 2, xy[1] - height / 2 - bbox[1] / 2), text, font=text_font, fill=fill)


def rounded_shadow(base: Image.Image, box, radius: int, offset=(0, 18), blur=28, fill=(0, 0, 0, 90)):
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shifted = (box[0] + offset[0], box[1] + offset[1], box[2] + offset[0], box[3] + offset[1])
    shadow_draw.rounded_rectangle(shifted, radius=radius, fill=fill)
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(shadow)


def make_base() -> Image.Image:
    size = 1024
    image = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    pixels = image.load()

    top = (10, 83, 78)
    bottom = (12, 126, 111)
    for y in range(size):
        blend = y / (size - 1)
        for x in range(size):
            radial = ((x - 740) ** 2 + (y - 220) ** 2) ** 0.5 / 950
            glow = max(0, 1 - radial) * 34
            r = int(top[0] * (1 - blend) + bottom[0] * blend + glow * 0.20)
            g = int(top[1] * (1 - blend) + bottom[1] * blend + glow * 0.42)
            b = int(top[2] * (1 - blend) + bottom[2] * blend + glow * 0.38)
            pixels[x, y] = (min(r, 255), min(g, 255), min(b, 255), 255)

    draw = ImageDraw.Draw(image)

    # Subtle outer frame for the "outside" wordmark.
    draw.rounded_rectangle((92, 86, 932, 938), radius=206, outline=(238, 205, 111, 86), width=18)
    draw.rounded_rectangle((128, 122, 896, 902), radius=172, outline=(255, 255, 255, 42), width=7)

    # Back card.
    back = Image.new("RGBA", image.size, (0, 0, 0, 0))
    back_draw = ImageDraw.Draw(back)
    rounded_shadow(back, (258, 340, 770, 755), 74, offset=(0, 12), blur=20, fill=(0, 0, 0, 70))
    back_draw.rounded_rectangle((258, 340, 770, 755), radius=74, fill=(219, 240, 232, 255))
    back_draw.rounded_rectangle((306, 395, 720, 420), radius=12, fill=(13, 105, 95, 80))
    back_draw.rounded_rectangle((306, 454, 620, 477), radius=12, fill=(13, 105, 95, 58))
    back = back.rotate(8, resample=Image.Resampling.BICUBIC, center=(514, 548))
    image.alpha_composite(back)

    # Front card.
    card = Image.new("RGBA", image.size, (0, 0, 0, 0))
    card_draw = ImageDraw.Draw(card)
    rounded_shadow(card, (236, 318, 788, 790), 82, offset=(0, 24), blur=28, fill=(0, 0, 0, 92))
    card_draw.rounded_rectangle((236, 318, 788, 790), radius=82, fill=(250, 249, 241, 255))
    card_draw.rounded_rectangle((286, 368, 738, 405), radius=18, fill=(8, 92, 84, 34))
    card_draw.rounded_rectangle((322, 705, 704, 732), radius=14, fill=(214, 168, 67, 98))
    card = card.rotate(-5, resample=Image.Resampling.BICUBIC, center=(512, 554))
    image.alpha_composite(card)

    draw = ImageDraw.Draw(image)

    # App mark on the outside of the card.
    text_center(draw, (512, 210), "凯文卡", font(150), (255, 242, 190, 255))
    text_center(draw, (512, 211), "凯文卡", font(150), (247, 218, 140, 238))

    # Central study cue.
    text_center(draw, (512, 558), "文", font(276), (10, 89, 82, 255))
    text_center(draw, (512, 712), "wen", font(72), (198, 139, 40, 255))

    # Small sparkle accents.
    for center, radius in [((205, 245), 12), ((824, 284), 9), ((806, 744), 11), ((198, 795), 8)]:
        cx, cy = center
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=(255, 235, 170, 178))

    return image.convert("RGB")


ICON_SIZES = {
    "AppIcon20x20@2x.png": 40,
    "AppIcon20x20@3x.png": 60,
    "AppIcon29x29@2x.png": 58,
    "AppIcon29x29@3x.png": 87,
    "AppIcon40x40@2x.png": 80,
    "AppIcon40x40@3x.png": 120,
    "AppIcon60x60@2x.png": 120,
    "AppIcon60x60@3x.png": 180,
    "AppIcon76x76@2x.png": 152,
    "AppIcon83.5x83.5@2x.png": 167,
    "AppIcon1024x1024.png": 1024,
}


def main():
    base = make_base()
    for filename, size in ICON_SIZES.items():
        output = OUT_DIR / filename
        icon = base.resize((size, size), Image.Resampling.LANCZOS)
        icon.save(output)


if __name__ == "__main__":
    main()
