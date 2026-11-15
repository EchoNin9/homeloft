# Homeloft web

React 19 + Vite 8 + TypeScript 7 dashboard for Homeloft, plus a dependency-free API client you can embed in other apps. The HTTP API it speaks is defined in `../docs/contract.md`.

```
src/client/      HomeloftClient (no React, no deps) - copy or import anywhere
src/auth/        Cognito Hosted UI auth-code + PKCE (no Amplify)
src/components/  <HomeloftDashboard /> (+ dashboard.css)
src/App.tsx      standalone shell: config.json -> login -> dashboard
mock/            dev-only fake API (vite plugin)
```

## Standalone use

```sh
npm install
cp public/config.example.json public/config.json   # fill in your values (git-ignored)
npm run dev          # http://localhost:5173
npm run build        # static site in dist/ -> upload to S3 (config.json lives next to index.html)
npm test -- --run    # client + PKCE unit tests
npm run typecheck
```

No AWS yet? `npm run dev:mock` serves a fake API with sample lights, a thermostat, covers, scenes and sensors, and skips login. `light.flaky_bulb` always fails so you can see the revert + error toast. A second home (`cabin`) is offline.

Register the app URL (`redirectUri`, default `origin + pathname`) as both an allowed callback URL and sign-out URL on the Cognito app client. The client must have the authorization-code grant enabled and no secret.

### config.json

Loaded from `/config.json` at startup, so one build works for everyone.

| Field | Required | Meaning |
|---|---|---|
| `apiUrl` | yes | API base **without** `/v1`, e.g. `https://abc.execute-api.us-east-1.amazonaws.com` |
| `clientId` | yes | Cognito app client id (public client, PKCE) |
| `cognitoDomain` | yes | Hosted UI domain, with or without `https://` |
| `region` | no | AWS region (informational) |
| `userPoolId` | no | Cognito user pool id (informational) |
| `redirectUri` | no | OAuth redirect/sign-out URI; default is the current page URL |

If the file is missing or invalid the app shows a setup screen instead of failing. Tokens are kept in `sessionStorage` and refreshed with the refresh token; the ID token is sent as the bearer token (`createAuth({ tokenType: 'access' })` switches to the access token). Tokens are never logged.

## Embedding the dashboard

Copy or import `src/client`, `src/components` (and `src/auth` if you want the built-in login) into your SPA. The components use no React 19-only APIs, so a React 18 or 19 host app works:

```tsx
import { HomeloftClient } from './homeloft/client';
import { HomeloftDashboard } from './homeloft/components';

const client = new HomeloftClient({
  apiUrl: 'https://abc.execute-api.us-east-1.amazonaws.com',
  getToken: async () => myCognitoSession.idToken, // host app's existing session
});

<HomeloftDashboard client={client} homeId="main-house" />  // homeId optional -> shows a picker
```

Props: `client` (required), `homeId` (pin a home), `pollMs` (default 5000). Styles ship in `dashboard.css`, imported by the component and scoped under `.hl-dash`; theme it by overriding the `--hl-*` CSS variables. Light/dark follows `prefers-color-scheme`. The standalone app also accepts a `getToken` prop (`<App getToken={...} />`) to skip the built-in login.

Behaviour: polls every 5 s while the tab is visible (pauses when hidden, refreshes on return, exponential backoff up to 60 s on errors); toggles, brightness and thermostat changes are optimistic and revert with a toast if the command fails; controls are disabled while a home is offline.

## Embedding only the client

`src/client` has no dependencies and uses the global `fetch` (or pass `fetch`).

```ts
import { HomeloftClient, HomeloftError } from './client';

const c = new HomeloftClient({ apiUrl, getToken });
const [home] = await c.listHomes();
const { entities } = await c.listEntities(home.homeId, { domain: 'light' });
const { id } = await c.sendCommand(home.homeId, {
  domain: 'light', service: 'turn_on', target: { entity_id: 'light.kitchen' }, data: { brightness: 200 },
});
const result = await c.waitForCommand(home.homeId, id, { timeoutMs: 10000, intervalMs: 500 });
if (result.status === 'error') console.warn(result.error); // e.g. "not_allowed: ..."
```

- `health()` is the only call that sends no `Authorization` header.
- Non-2xx responses throw `HomeloftError` with `status` and `code` (the contract's `error` string, or `http_<status>`). Network failures are `status 0, code "network_error"`; `waitForCommand` timeouts are `status 0, code "timeout"`.
- `waitForCommand` resolves with the final status for both `ok` and `error` (the bridge rejecting a command is a normal outcome, not an exception) and rejects only on timeout or HTTP/network failure.
- Entity and command ids are `encodeURIComponent`-ed.
