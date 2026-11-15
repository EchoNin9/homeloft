import assert from 'node:assert/strict';
import { transform } from './sync-docs.mjs';

const map = { 'docs/quickstart.md': 'quickstart', 'CHANGELOG.md': 'changelog' };
const out = transform(
  '# Hello "x"\n\nSee [qs](quickstart.md#step-2), [log](../CHANGELOG.md), [nas](../nas/.env.example), [web](https://x.y), ![s](assets/a.png)\n```\n[keep](quickstart.md)\n```\n',
  'docs/security.md',
  map,
);
assert.equal(
  out,
  '---\ntitle: "Hello \\"x\\""\n---\n\nSee [qs](/quickstart/#step-2), [log](/changelog/), [nas](https://github.com/EchoNin9/homeloft/blob/main/nas/.env.example), [web](https://x.y), ![s](./assets/a.png)\n```\n[keep](quickstart.md)\n```\n',
);
assert.match(transform('# T\n![s](docs/assets/a.png)', 'CONTRIBUTING.md', map), /\]\(\.\/assets\/a\.png\)/);
assert.throws(() => transform('no title', 'x.md', map));
console.log('sync-docs ok');
