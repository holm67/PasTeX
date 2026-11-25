#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

usage() {
    cat <<'HELP'
Usage: ./build.sh [all|default|debug|release] [gtk2|gtk3|qt5|qt6]

  all      Build default, debug and all four Linux releases (default).
  default  Build bin/default/pastex with the selected widget set.
  debug    Build bin/debug/pastex with the selected widget set.
  release  Build all four releases, or just the widget set supplied.

The default widget set is gtk2. LAZBUILD and LAZFLAGS may be overridden.
Examples: ./build.sh
          ./build.sh default qt6
          ./build.sh release qt5
HELP
}
pastex_build_mode="${1:-all}"
pastex_widget_set="${2:-gtk2}"
case "$pastex_build_mode" in
    -h|--help) usage; exit 0 ;;
    all|default|debug|release) ;;
    *) usage >&2; exit 2 ;;
esac
case "$pastex_widget_set" in
    gtk2|gtk3|qt5|qt6) ;;
    *) usage >&2; exit 2 ;;
esac
if (( $# > 2 )); then usage >&2; exit 2; fi
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
if [[ "$pastex_build_mode" == release && $# == 2 ]]; then
    pastex_build_mode="release-$pastex_widget_set"
fi
exec make "$pastex_build_mode" "WIDGETSET=$pastex_widget_set"
