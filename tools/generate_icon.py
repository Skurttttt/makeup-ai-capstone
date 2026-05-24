"""
Generates assets/images/app_icon.png from assets/images/brand_logo.png.
Cover-scales and center-crops the brand image to 1024x1024.
Run from project root:  python tools/generate_icon.py
"""
from PIL import Image

SIZE = 1024

src = Image.open("assets/images/brand_logo.png").convert("RGBA")
w, h = src.size

# Cover-scale: enlarge so both dimensions >= SIZE
scale = max(SIZE / w, SIZE / h)
nw, nh = int(w * scale), int(h * scale)
scaled = src.resize((nw, nh), Image.LANCZOS)

# Center-crop to SIZE x SIZE
x = (nw - SIZE) // 2
y = (nh - SIZE) // 2
icon = scaled.crop((x, y, x + SIZE, y + SIZE))

icon.save("assets/images/app_icon.png", "PNG")
print(f"Saved assets/images/app_icon.png  ({SIZE}x{SIZE})")
