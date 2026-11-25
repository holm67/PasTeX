# PasTeX

PasTeX is a visual LaTeX editor for Linux and Windows. It offers in-place text
and equation editing, continuous and paged previews, and a source/PDF workspace
with SyncTeX.

## Build

Install Free Pascal and Lazarus with LCL and SynEdit. On Linux, select Qt6,
Qt5, GTK2, or GTK3 and install the corresponding runtime libraries.

```sh
./build.sh default qt6
./bin/default/pastex examples/math.tex
```

On Windows, run `./build-windows.ps1 -Mode Default` in PowerShell, then open
`bin/default/pastex.exe`. TeX and PDF tools enable compiled preview and export.

- [User guide](docs/user-guide.tex)
- [Developer reference](docs/developer-guide.tex)
- [Examples](examples/)

[GPL-3.0-or-later](LICENSE). Bundled fonts retain their
[original licenses](resources/FONT-LICENSES.txt).
