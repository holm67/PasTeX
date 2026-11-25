# SPDX-License-Identifier: GPL-3.0-or-later
"""Build light/dark, uncompressed ICO resources from the ribbon SVG masters."""
from pathlib import Path
from tempfile import TemporaryDirectory
import subprocess
from PIL import Image
from export_icons import legacy_ico

directory = Path(__file__).resolve().parent
with TemporaryDirectory() as tmp:
    for svg in sorted((directory / 'toolbar').glob('*.svg')):
        for theme, color in [('light', '#202020'), ('dark', '#eeeeee')]:
            master = Path(tmp) / 'icon.svg'
            master.write_text(svg.read_text().replace('#173653', color))
            png = Path(tmp) / 'icon.png'
            subprocess.run(['convert', '-background', 'none', '-density', '768', str(master), str(png)], check=True)
            with Image.open(png) as image:
                (svg.parent / f'{svg.stem}-{theme}.ico').write_bytes(legacy_ico(image.convert('RGBA'), (16, 24, 32)))
subprocess.run(['lazres', str(directory.parent / 'src/toolbaricons.lrs')]+[str(p) for p in sorted((directory / 'toolbar').glob('*.ico'))], check=True)
