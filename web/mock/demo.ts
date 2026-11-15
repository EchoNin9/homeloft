import { createMockApi } from './mockApi';

/** Static demo (`npm run build:demo`): answer config.json and /v1/* in the browser, so no server is needed. */
export function installDemoApi() {
  const handle = createMockApi();
  const realFetch = window.fetch.bind(window);
  window.fetch = async (input, init) => {
    const req = new Request(input, init);
    const r = await handle(req.method, new URL(req.url), () => req.text());
    if (!r) return realFetch(input, init);
    return new Response(JSON.stringify(r.body), { status: r.status, headers: { 'Content-Type': 'application/json' } });
  };
}
