# SPDX-License-Identifier: GPL-3.0-or-later
"""Export the vector master and update the embedded Lazarus form icon.

Authoring dependencies: ImageMagick (`convert`) and Python Pillow.
Normal Lazarus builds use the committed assets and do not need these tools.
"""
from pathlib import Path
import re
import struct
import subprocess

from PIL import Image


def legacy_ico(image, sizes=(16, 24, 32, 48, 64, 128, 256)):
    """Classic BI_RGB frames, including the AND mask expected by Lazarus."""
    entries, frames = [], []
    offset = 6 + 16 * len(sizes)
    for size in sizes:
        frame = image.resize((size, size), Image.Resampling.LANCZOS)
        pixels = frame.load()
        stride = ((size + 31) // 32) * 4
        color, mask = bytearray(), bytearray()
        for y in range(size - 1, -1, -1):
            row_mask = bytearray(stride)
            for x in range(size):
                r, g, b, a = pixels[x, y]
                color.extend((b, g, r, a))
                if a == 0:
                    row_mask[x // 8] |= 0x80 >> (x % 8)
            mask.extend(row_mask)
        header = struct.pack('<IiiHHIIiiII', 40, size, size * 2,
                             1, 32, 0, len(color), 0, 0, 0, 0)
        data = header + color + mask
        entries.append(struct.pack('<BBBBHHII', size % 256, size % 256,
                                   0, 0, 1, 32, len(data), offset))
        frames.append(data)
        offset += len(data)
    return struct.pack('<HHH', 0, 1, len(sizes)) + b''.join(entries + frames)


def main():
    directory = Path(__file__).resolve().parent
    subprocess.run([
        "convert", "-background", "none", str(directory / "pastex.svg"),
        "-resize", "256x256", str(directory / "pastex.png"),
    ], check=True)
    with Image.open(directory / "pastex.png") as image:
        (directory / "pastex.ico").write_bytes(legacy_ico(image.convert("RGBA")))
    data = (directory / "pastex.ico").read_bytes()
    # Lazarus Project Options uses this conventional project-local copy.
    (directory.parent / "pastex.ico").write_bytes(data)
    encoded = (struct.pack("<I", len(data)) + data).hex().upper()
    lines = ["    " + encoded[i:i + 64] for i in range(0, len(encoded), 64)]
    replacement = "  Icon.Data = {\n" + "\n".join(lines) + "\n  }"
    form = directory.parent / "src" / "mainform.lfm"
    source, count = re.subn(
        r"^  Icon\.Data = \{.*?^  \}", replacement,
        form.read_text(encoding="utf-8"), count=1, flags=re.MULTILINE | re.DOTALL,
    )
    if count != 1:
        raise RuntimeError("Cannot find the main form's Icon.Data property")
    form.write_text(source, encoding="utf-8")
    vector = (directory / "pastex.svg").read_text().replace("\n", " ")
    chunks = [vector[i:i + 100].replace("'", "''")
              for i in range(0, len(vector), 100)]
    (directory.parent / "src/vectorartwork.lrs").write_text(
        "LazarusResources.Add('pastex-vector','SVG',[\n  '" +
        "'\n  +'".join(chunks) + "']);\n")


if __name__ == "__main__":
    main()
