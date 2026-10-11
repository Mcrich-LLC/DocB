#!/usr/bin/env nix-shell
#!nix-shell -i bash -p nodejs pnpm esbuild
# Bundles highlight.js with the languages and custom grammars of swift-docc-render into the
# script DocBHighlight evaluates. Run from anywhere; writes Sources/DocBHighlight/highlight.min.js.
set -euo pipefail
cd "$(dirname "$0")"
pnpm install --frozen-lockfile --silent
esbuild entry.js --bundle --format=iife --minify --target=safari17 --log-level=warning \
  --banner:js='/* highlight.js 11.11.1 (BSD-3-Clause, see Tools/highlight/highlight.js-LICENSE) with the swift, markdown and pkl grammars of swift-docc-render and @apple/highlightjs-pkl (Apache-2.0). Built by Tools/highlight/build.sh; do not edit. */' \
  --outfile=../../Sources/DocBHighlight/highlight.min.js
