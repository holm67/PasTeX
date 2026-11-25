# SPDX-License-Identifier: GPL-3.0-or-later
"""Export 24px ribbon glyphs and embed them in the Lazarus form.

SVG masters live in toolbar/. Requires ImageMagick and Pillow only when
authoring icons; applications load the embedded BMPs without external files.
"""
from io import BytesIO
from pathlib import Path
import re
import struct
import subprocess

from PIL import Image


def main():
    directory = Path(__file__).resolve().parent
    form = directory.parent / 'src/mainform.lfm'
    source = form.read_text()
    pattern = r'(\s*object \w+: T(?:BitBtn|SpeedButton)\n)(.*?)(\n\s*end)'
    names = {'New': 'new', 'Open': 'open', 'Save': 'save', 'Undo': 'undo',
             'Redo': 'redo', 'Cut': 'cut', 'Copy': 'copy', 'Paste': 'paste', 'Selectall': 'selectall', 'Bold': 'bold', 'Italic': 'italic', 'Heading': 'heading',
             'Source': 'source', 'Equation': 'equation', 'Preview': 'preview',
             'Paragraph': 'paragraph', 'Insertequation': 'equation',
             'Fraction': 'fraction', 'Squareroot': 'root', 'Superscript': 'superscript',
             'Subscript': 'subscript', 'Alpha': 'alpha', 'Beta': 'beta', 'Pi': 'pi',
             'Sum': 'sum', 'Integral': 'integral', 'Infinity': 'infinity',
             'Documentsettings': 'settings', 'Compilerlog': 'log'}

    def embed(match):
        body = match[2]
        button = re.search(r'object (\w+):', match[1])[1]
        name = next((value for key, value in names.items()
                     if button.endswith(key + 'Button')), None)
        if name is None:
            return match[0]
        png = directory / 'toolbar' / (name + '.png')
        subprocess.run(['convert', '-background', 'none',
                        str(png.with_suffix('.svg')), str(png)], check=True)
        with Image.open(png) as image:
            rgba = image.convert('RGBA')
            bitmap = Image.new('RGB', rgba.size, (255, 0, 255))
            # Keep partially covered edge pixels opaque; magenta is the mask.
            bitmap.paste(rgba.convert('RGB'), mask=rgba.getchannel('A').point(lambda a: 255 if a > 96 else 0))
            stream = BytesIO()
            bitmap.save(stream, format='BMP')
        data = stream.getvalue()
        encoded = (struct.pack('<I', len(data)) + data).hex().upper()
        indent = re.search(r'\n( +)\w', '\n' + body)[1]
        glyph = indent + 'Glyph.Data = {\n' + '\n'.join(
            indent + '  ' + encoded[i:i + 64] for i in range(0, len(encoded), 64)
        ) + '\n' + indent + '}'
        body = re.sub(r'\n *Glyph.Data = \{.*?\}', '', body, flags=re.S)
        return match[1] + body + '\n' + glyph + match[3]

    form.write_text(re.sub(pattern, embed, source, flags=re.S))


if __name__ == '__main__':
    main()
