"""Review sheet only; never installs or changes the app icon."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math
import hashlib
import sys

root = Path(__file__).resolve().parent
output = root / 'output'
reference = Image.open(root / 'reference-approved.png').convert('RGB').resize((1024, 1024), Image.Resampling.LANCZOS)
render = Image.open(output / 'icon.png').convert('RGBA')
assert render.size == (1024, 1024)
assert render.getchannel('A').getextrema() == (255, 255), 'Icon must be opaque across its entire square'
# Check the approved frame was not carried into the artwork: corners stay dark.
assert all(max(render.getpixel(point)[:3]) < 100 for point in [(0, 0), (1023, 0), (0, 1023), (1023, 1023)])
render.convert('RGB').save(output / 'icon.png')
if '--verify-installed' in sys.argv:
    installed = Image.open(root.parents[1] / 'TrollRoute/Assets.xcassets/AppIcon.appiconset/TrollRoute.png')
    # Windows and Linux PNG encoders produce different compressed bytes. Compare
    # the actual artwork, including every pixel, rather than the compression.
    assert installed.mode == 'RGB' and installed.size == (1024, 1024)
    assert installed.tobytes() == render.convert('RGB').tobytes(), 'Installed icon differs from the approved layers'
(output / 'render.sha256').write_text(hashlib.sha256((output / 'icon.png').read_bytes()).hexdigest() + '\n')
board = Image.new('RGB', (2144, 1490), '#17191e')
draw = ImageDraw.Draw(board)
font = ImageFont.load_default(size=27)
small = ImageFont.load_default(size=23)
draw.text((32, 22), 'APPROVED REFERENCE  /  1024 px', font=font, fill='white')
draw.text((1088, 22), 'APPROVED VECTOR RENDER  /  1024 px', font=font, fill='white')
board.paste(reference, (32, 68))
board.paste(render.convert('RGB'), (1088, 68))

# Continuous-corner superellipse for visual review of iOS clipping, not baked into
# the exported icon. OS rasterization can differ slightly from this preview mask.
scale = 3
size = 180
mask = Image.new('L', (size * scale, size * scale))
points = []
for index in range(720):
    angle = index * math.tau / 720
    c, s = math.cos(angle), math.sin(angle)
    points.append(((0.5 + 0.5 * math.copysign(abs(c) ** (2 / 4.5), c)) * (size * scale - 1),
                   (0.5 + 0.5 * math.copysign(abs(s) ** (2 / 4.5), s)) * (size * scale - 1)))
ImageDraw.Draw(mask).polygon(points, fill=255)
mask = mask.resize((size, size), Image.Resampling.LANCZOS)
icon = render.convert('RGB').resize((size, size), Image.Resampling.LANCZOS)
for x, background, text in [(32, '#e1e8f1', '#242932'), (1088, '#202938', '#ffffff')]:
    draw.rounded_rectangle((x, 1120, x + 1024, 1450), radius=22, fill=background)
    draw.text((x + 270, 1203), 'HOME SCREEN SIZE', fill=text, font=font)
    draw.text((x + 270, 1245), '60 pt at 3x - iOS-style mask preview', fill=text, font=small)
    board.paste(icon, (x + 54, 1158), mask)
    draw.text((x + 90, 1350), 'TrollRoute', fill=text, font=small)
board.save(output / 'comparison.png')
print('PASS: opaque 1024px square, no outer rim; comparison includes light/dark Home Screen previews')
