#!/usr/bin/env python3
"""Rebuild the embedded native font bundle from an installed TeX distribution."""
# SPDX-License-Identifier: GPL-3.0-or-later
import gzip
import hashlib
import io
from pathlib import Path
import re
import struct
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def locate(name):
    path = subprocess.check_output(['kpsewhich', name], text=True).strip()
    if not path:
        raise FileNotFoundError(name)
    return Path(path)


def resource(name, data):
    identifier = name.encode('utf-16le') + b'\0\0'
    header = b'\xff\xff\x0a\0' + identifier
    header += bytes(-len(header) % 4)
    header += struct.pack('<IHHII', 0, 0x30, 0, 0, 0)
    return struct.pack('<II', len(data), len(header) + 8) + header + data + bytes(-len(data) % 4)


def main():
    files = {}
    # Original, unmodified outlines and metrics; no pre-rendered glyph images.
    for family in ('cmr', 'cmmi', 'cmsy', 'cmbx', 'cmbxti', 'cmbxsl', 'cmb', 'cmu', 'cmsltt', 'cmvtt', 'cmti', 'cmsl', 'cmtt', 'cmss',
                   'cmssi', 'cmssbx', 'cmcsc', 'cmbsy', 'cmmib', 'cmex', 'msam', 'msbm', 'eufm', 'rsfs'):
        for size in (5, 6, 7, 8, 9, 10, 12):
            for extension in ('tfm', 'pfb'):
                name = f'{family}{size}.{extension}'
                try:
                    files[name] = locate(name).read_bytes()
                except (FileNotFoundError, subprocess.CalledProcessError):
                    pass
    lm = locate('lmroman10-regular.otf').parent
    for path in sorted(lm.glob('*.otf')):
        files[path.name] = path.read_bytes()
    # Font positions and NFSS size selections are data, not an embedded TeX engine.
    families = dict(operators='cmr', letters='cmmi', symbols='cmsy', largesymbols='cmex', AMSa='msam', AMSb='msbm')
    def slot(value):
        return int(value[1:], 16) if value.startswith('"') else ord(value[1]) if value.startswith('`') else int(value)
    for name in ('fontmath.ltx', 'amssymb.sty', 'amsmath.sty'):
        text = re.sub(r'(?<!\\)%[^\n]*', '', locate(name).read_text())
        lines = []
        for match in re.finditer(r'\\DeclareMath(?:Symbol|Delimiter)\s*(?:\{([^{}]+)\}|(\\[a-zA-Z]+|\\.))\s*\{([^{}]+)\}\s*\{([^{}]+)\}\s*\{([^{}]+)\}', text):
            command, token, kind, family, code = match.groups()
            if family in families:
                lines.append('\t'.join(('S', command or token, families[family], str(slot(code)), kind)))
        for match in re.finditer(r'\\DeclareMathDelimiter\s*\{([^{}]+)\}\s*\{[^{}]+\}\s*\{([^{}]+)\}\s*\{([^{}]+)\}\s*\{([^{}]+)\}\s*\{([^{}]+)\}', text):
            command, small, small_code, large, large_code = match.groups()
            if small in families and large in families:
                lines.append('\t'.join(('D', command, families[small], str(slot(small_code)), families[large], str(slot(large_code)))))
        for match in re.finditer(r'\\(?:let\s*|DeclareRobustCommand\s*\{)(\\[a-zA-Z]+)\}?\s*=?\s*(\\[a-zA-Z]+)', text):
            lines.append('\t'.join(('L', *match.groups())))
        files[name + '.symbols'] = ('\n'.join(lines) + '\n').encode()
    shapes = []
    for encoding, families_list in (('OT1', ('cmr', 'cmss', 'cmtt')), ('TU', ('lmr', 'lmss', 'lmtt'))):
        for family in families_list:
            text = re.sub(r'%[^\n]*', '', locate((encoding + family).lower() + '.fd').read_text())
            for match in re.finditer(r'\\DeclareFontShape\s*\{([^{}]*)\}\s*\{([^{}]*)\}\s*\{([^{}]*)\}\s*\{([^{}]*)\}\s*\{((?:[^{}]|\{[^{}]*\})*)\}', text):
                enc, fam, series, shape, definition = match.groups()
                shapes.append('/'.join((enc, fam, series, shape)) + '\t' + re.sub(r'\s+', ' ', definition).strip())
    files['font-shapes.tsv'] = ('\n'.join(shapes) + '\n').encode()
    kernel = locate('latex.ltx').read_text()
    rules = ['/'.join((a, b)) + '\t' + primary + '|' + alternate for a, b, primary, alternate in
             re.findall(r'\\DeclareFontShapeChangeRule\s*\{([^{}]*)\}\s*\{([^{}]*)\}\s*\{([^{}]*)\}\s*\{([^{}]*)\}', kernel)]
    files['shape-rules.tsv'] = ('\n'.join(rules) + '\n').encode()
    notices = {
        'AMS-OFL.txt': locate('cmr10.pfb').parents[5] / 'doc/fonts/amsfonts/OFL.txt.gz',
        'AMS-README.txt': locate('cmr10.pfb').parents[5] / 'doc/fonts/amsfonts/README.gz',
        'GUST-FONT-LICENSE.txt': lm.parents[3] / 'doc/fonts/lm/GUST-FONT-LICENSE.TXT',
        'LM-README.txt': lm.parents[3] / 'doc/fonts/lm/README-Latin-Modern.TXT',
        'LM-MANIFEST.txt': lm.parents[3] / 'doc/fonts/lm/MANIFEST-Latin-Modern.TXT',
        'RSFS-README.txt': locate('fontmath.ltx').parents[3] / 'doc/fonts/rsfs/README',
        'RSFS-TYPE1.txt': locate('fontmath.ltx').parents[3] / 'doc/fonts/rsfs/README.type1',
        'LPPL.txt': locate('fontmath.ltx').parents[3] / 'doc/latex/base/lppl.txt.gz',
    }
    for name, path in notices.items():
        files['licenses/' + name] = gzip.decompress(path.read_bytes()) if path.suffix == '.gz' else path.read_bytes()
    files['licenses/NOTICE.txt'] = b'Unmodified Computer Modern/AMS (SIL OFL), Latin Modern (GUST Font License), and RSFS fonts. Font declaration metadata is derived from LaTeX/AMS sources. The corresponding licenses, credits and manifests accompany this bundle. These assets retain their own licenses.\n'
    archive = io.BytesIO()
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as output:
        for name, data in sorted(files.items()):
            entry = zipfile.ZipInfo(name, (2025, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            output.writestr(entry, data)
    data = archive.getvalue()
    identity = hashlib.sha256(data).hexdigest()[:16].encode()
    target = ROOT / 'resources/native-fonts.res'
    target.parent.mkdir(exist_ok=True)
    (target.parent / 'FONT-LICENSES.txt').write_text('\n\n'.join(name + '\n' + data.decode(errors='replace')
        for name, data in sorted(files.items()) if name.startswith('licenses/')))
    target.write_bytes(bytes.fromhex('0000000020000000ffff0000ffff000000000000000000000000000000000000') +
                       resource('NATIVEFONTS', data) + resource('NATIVEFONTID', identity))
    print(f'{target.relative_to(ROOT)}: {len(files)} files, {len(data):,} compressed bytes')


if __name__ == '__main__':
    main()
