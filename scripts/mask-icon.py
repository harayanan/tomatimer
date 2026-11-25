# Masks full-bleed artwork into the macOS icon grid: 824 px rounded tile (radius ~22.5%) inside 1024, soft shadow.
import sys
from PIL import Image, ImageDraw, ImageFilter
src, dst = sys.argv[1], sys.argv[2]
crop = float(sys.argv[3]) if len(sys.argv) > 3 else 0.9   # fraction of artwork kept (zooms subject)
SS, N, BODY, OFF, R = 4, 1024, 824, 100, 185
mask = Image.new("L", (BODY * SS, BODY * SS), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, BODY * SS - 1, BODY * SS - 1), radius=R * SS, fill=255)
mask = mask.resize((BODY, BODY), Image.LANCZOS)

art = Image.open(src).convert("RGBA")
w = art.width; k = int(w * crop); x0 = (w - k) // 2; y0 = int((w - k) * 0.45)
art = art.crop((x0, y0, x0 + k, y0 + k)).resize((BODY, BODY), Image.LANCZOS)

# hairline inner highlight along the top edge
hl = Image.new("L", (BODY * SS, BODY * SS), 0)
ImageDraw.Draw(hl).rounded_rectangle((0, 0, BODY * SS - 1, BODY * SS - 1), radius=R * SS, outline=255, width=3 * SS)
hl = hl.resize((BODY, BODY), Image.LANCZOS)
fade = Image.linear_gradient("L").resize((BODY, BODY)).point(lambda v: max(0, 255 - v * 3))  # top only
hl = Image.composite(hl, Image.new("L", (BODY, BODY), 0), fade).point(lambda v: v * 50 // 255)
white = Image.new("RGBA", (BODY, BODY), (255, 255, 255, 255)); white.putalpha(hl)
art = Image.alpha_composite(art, white)

icon = Image.new("RGBA", (N, N), (0, 0, 0, 0))
sh = Image.new("RGBA", (N, N), (0, 0, 0, 0))
blk = Image.new("RGBA", (BODY, BODY), (0, 0, 0, 255)); blk.putalpha(mask.point(lambda v: v * 95 // 255))
sh.paste(blk, (OFF, OFF + 10), blk)
icon = Image.alpha_composite(icon, sh.filter(ImageFilter.GaussianBlur(16)))
body = art.copy(); body.putalpha(mask)
icon.alpha_composite(body, (OFF, OFF))
icon.save(dst)
print("wrote", dst)
