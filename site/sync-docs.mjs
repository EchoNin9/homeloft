// Copies the repo's markdown (docs/ and a few root files) into Starlight's content folder.
// The markdown stays GitHub-native: the first "# Heading" becomes the page title, links to other
// synced pages become site URLs, and links to anything else in the repo point at GitHub.
import { cpSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, posix } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_URL = 'https://github.com/EchoNin9/homeloft/blob/main/';
const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const OUT = join(ROOT, 'site/src/content/docs');

// repo path -> site slug
export function pages(root = ROOT) {
  const map = {
    'CHANGELOG.md': 'changelog',
    'CONTRIBUTING.md': 'contributing',
    'CODE_OF_CONDUCT.md': 'code-of-conduct',
  };
  for (const f of readdirSync(join(root, 'docs'))) if (f.endsWith('.md')) map[`docs/${f}`] = f.slice(0, -3);
  return map;
}

export function transform(text, src, map) {
  const lines = text.split('\n');
  const h1 = lines.findIndex((l) => l.startsWith('# '));
  if (h1 < 0) throw new Error(`${src}: no "# Title" line`);
  const title = lines[h1].slice(2).trim();
  lines.splice(h1, 1);
  let fenced = false;
  const body = lines
    .map((l) => {
      if (l.trimStart().startsWith('```')) fenced = !fenced;
      if (fenced) return l;
      return l.replace(/(!?)\]\(([^)\s]+)\)/g, (all, bang, href) => {
        if (/^([a-z]+:|#|\/)/.test(href)) return all;
        const [path, hash = ''] = href.split('#');
        const target = posix.normalize(posix.join(posix.dirname(src), path));
        if (map[target]) return `](/${map[target]}/${hash && '#' + hash})`;
        if (target.startsWith('docs/assets/')) return `${bang}](./${target.slice(5)})`; // copied next to the pages
        return `${bang}](${REPO_URL}${target}${hash && '#' + hash})`;
      });
    })
    .join('\n');
  return `---\ntitle: ${JSON.stringify(title)}\n---\n${body}`;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const map = pages();
  rmSync(OUT, { recursive: true, force: true });
  mkdirSync(OUT, { recursive: true });
  for (const [src, slug] of Object.entries(map))
    writeFileSync(join(OUT, `${slug}.md`), transform(readFileSync(join(ROOT, src), 'utf8'), src, map));
  cpSync(join(ROOT, 'docs/assets'), join(OUT, 'assets'), { recursive: true });
  cpSync(join(ROOT, 'site/index.mdx'), join(OUT, 'index.mdx'));
  console.log(`synced ${Object.keys(map).length} pages`);
}
