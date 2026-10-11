// DocB's highlighter: highlight.js with the languages, aliases and custom grammars of
// swift-docc-render (src/utils/syntax-highlight.js), so a listing tokenizes as on the web.
import hljs from 'highlight.js/lib/core';
import bash from 'highlight.js/lib/languages/bash';
import c from 'highlight.js/lib/languages/c';
import cpp from 'highlight.js/lib/languages/cpp';
import css from 'highlight.js/lib/languages/css';
import diff from 'highlight.js/lib/languages/diff';
import http from 'highlight.js/lib/languages/http';
import java from 'highlight.js/lib/languages/java';
import javascript from 'highlight.js/lib/languages/javascript';
import json from 'highlight.js/lib/languages/json';
import llvm from 'highlight.js/lib/languages/llvm';
import objectivec from 'highlight.js/lib/languages/objectivec';
import perl from 'highlight.js/lib/languages/perl';
import php from 'highlight.js/lib/languages/php';
import python from 'highlight.js/lib/languages/python';
import ruby from 'highlight.js/lib/languages/ruby';
import scss from 'highlight.js/lib/languages/scss';
import shell from 'highlight.js/lib/languages/shell';
import typescript from 'highlight.js/lib/languages/typescript';
import xml from 'highlight.js/lib/languages/xml';
import yaml from 'highlight.js/lib/languages/yaml';
import markdown from './markdown.js';
import pkl from './pkl.js';
import swift from './swift.js';

const Languages = {
  bash: ['sh', 'zsh'],
  c: ['h'],
  cpp: ['cc', 'c++', 'h++', 'hpp', 'hh', 'hxx', 'cxx'],
  css: [],
  diff: ['patch'],
  http: ['https'],
  java: ['jsp'],
  javascript: ['js', 'jsx', 'mjs', 'cjs'],
  json: [],
  llvm: [],
  markdown: ['md', 'mkdown', 'mkd'],
  objectivec: ['mm', 'objc', 'obj-c', 'objective-c', 'occ'],
  perl: ['pl', 'pm'],
  php: [],
  pkl: [],
  python: ['py', 'gyp', 'ipython'],
  ruby: ['rb', 'gemspec', 'podspec', 'thor', 'irb'],
  scss: [],
  shell: ['console', 'shellsession'],
  swift: [],
  typescript: ['typescript', 'ts', 'tsx', 'mts', 'cts'],
  xml: ['html', 'xhtml', 'rss', 'atom', 'xjb', 'xsd', 'xsl', 'plist', 'wsf', 'svg'],
  yaml: ['yml', 'yaml'],
};
const grammars = { bash, c, cpp, css, diff, http, java, javascript, json, llvm, markdown, objectivec, perl, php, pkl, python, ruby, scss, shell, swift, typescript, xml, yaml };
for (const name of Object.keys(Languages)) hljs.registerLanguage(name, grammars[name]);
hljs.configure({ classPrefix: 'syntax-' });

function languageByAlias(language) {
  if (language in Languages) return language;
  const entry = Object.entries(Languages).find(([, aliases]) => aliases.includes(language));
  return entry ? entry[0] : null;
}

const entities = { '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#x27;': "'" };
const unescape = (text) => text.replace(/&(?:amp|lt|gt|quot|#x27);/g, (m) => entities[m]);

// The web's markup as a flat list of [text, scopes], scopes outermost first, with its
// stylesheet's per-language rules applied: in Swift the "class" span wrapping a whole
// declaration line and a parameter's internal name after its label have no color of
// their own, and meta attributes take the keyword color; in JSON keys take the string color.
function tokens(html, language) {
  const out = [];
  const stack = [];
  const root = { last: null };
  const scopes = () => stack.map((frame) => frame.scope).filter((scope) => scope);
  const re = /<span class="([^"]*)">|<\/span>/g;
  let match;
  let position = 0;
  while ((match = re.exec(html))) {
    if (match.index > position) out.push([unescape(html.slice(position, match.index)), scopes()]);
    if (match[0] === '</span>') {
      stack.pop();
    } else {
      const cls = match[1].split(' ').find((name) => name.startsWith('syntax-'));
      const original = cls ? cls.slice('syntax-'.length) : '';
      let scope = original;
      const parent = stack.length ? stack[stack.length - 1] : root;
      const previous = parent.last;
      parent.last = original;
      if (language === 'swift') {
        if (scope === 'class') scope = '';
        if (scope === 'params' && (previous === 'params' || previous === 'keyword')) scope = '';
        if (scope === 'meta') scope = 'keyword';
      }
      if (language === 'json' && scope === 'attr') scope = 'string';
      stack.push({ scope, last: null });
    }
    position = re.lastIndex;
  }
  if (position < html.length) out.push([unescape(html.slice(position)), scopes()]);
  return out;
}

globalThis.docbHighlight = function (code, language) {
  const name = languageByAlias(language || '');
  if (!name) return [[code, []]];
  return tokens(hljs.highlight(code, { language: name, ignoreIllegals: true }).value, name);
};
