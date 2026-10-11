The highlighter DocB runs is the web renderer's: highlight.js with the language set, aliases
and custom grammars of [swift-docc-render](https://github.com/swiftlang/swift-docc-render)
(`src/utils/syntax-highlight.js` and `src/utils/custom-highlight-lang/`), so a listing
tokenizes as it does on developer.apple.com. `entry.js` adds the flattening to tokens and the
stylesheet's per-language rules (`src/styles/base/_syntax.scss`); `swift.js`, `markdown.js`
and `pkl.js` are copied from swift-docc-render. `./build.sh` writes the bundle.
