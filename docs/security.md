# Security model

Homeloft lets you control a house from the internet, so the design starts from one rule:
**nothing on your home network accepts a connection from the internet.** This page explains
what protects what, which defaults you get, and which trade-offs are deliberate.

To report a vulnerability, see [SECURITY.md](../SECURITY.md).

## Trust boundaries

```
 Browser ──HTTPS──► CloudFront (SPA)          Browser ──HTTPS + JWT──► API Gateway ──► API Lambda ──► DynamoDB
                                                                                            │
                                                                                            └─ iot:Publish homeloft/{homeId}/cmd
 NAS: Home Assistant ◄─ws (loopback)─ bridge ──MQTT/TLS, X.509, outbound only──► AWS IoT Core ──► ingest Lambda ──► DynamoDB
```

| Boundary | What crosses it | Control |
|---|---|---|
| Internet → NAS | nothing | The bridge only dials out (8883/TLS to IoT Core). No port forwarding and no inbound rules. Mosquitto listens on `127.0.0.1` only. |
| NAS → AWS | state batches, command acks, online status | A per-home X.509 certificate. The IoT policy pins the client ID to the Thing name and limits publish/subscribe to `homeloft/{homeId}/…` for that home. Created from a CSR on the NAS, so the private key never leaves it and never reaches OpenTofu state. |
| AWS → NAS | commands | Two allowlists: the API's `allowed_services` and the bridge's own `BRIDGE_ALLOWED_SERVICES` and entity filter. The bridge also rejects stale (>60 s), future-dated, replayed, malformed or multi-target commands. A compromised cloud side still can't call a service the bridge doesn't allow. |
| Browser → API | reads, commands, view prefs | A Cognito JWT checked by API Gateway (issuer + audience), then the caller must be in an `allowed_groups` group. Home IDs, entity IDs, services and body sizes are validated in the Lambda. 10 rps / burst 20 per stage. |
| Browser ↔ SPA | the app and its tokens | CloudFront with Origin Access Control (the bucket is private) and HTTPS only. A response headers policy sets CSP (`self`, your Cognito domain and API Gateway hosts in the stack's region), HSTS, nosniff and `frame-ancestors 'none'`. |

## Defaults that matter

| Default | Where | Why |
|---|---|---|
| No `lock.unlock`, no `alarm_control_panel.*`, no `script.*` in either allowlist | module `allowed_services`, bridge `DEFAULT_SERVICES` | The things that hurt most if a token leaks. Add them only on purpose. |
| `update.install` is never allowlisted | both | The dashboard shows updates; applying them is a human job. |
| TOTP MFA required (`mfa = "ON"`) | Cognito | Managed login walks each user through authenticator setup at first sign-in. |
| Admin-created users only, no self sign-up | Cognito | A private install. |
| 1 h access/ID tokens, 30 d refresh, user-existence errors hidden | Cognito client | Short-lived bearer tokens. |
| Prefs keyed by `HMAC(sub)` | API Lambda | The table never stores Cognito user IDs. |
| PITR + encryption at rest | DynamoDB | Recovery and defence in depth. |
| State bucket: versioned, encrypted, public access blocked, TLS-only policy, `prevent_destroy` | bootstrap | OpenTofu state can hold sensitive values. |
| GitHub deploy via OIDC (no stored keys), trust pinned to one repo + branch | bootstrap | No long-lived AWS keys in CI. |
| Bridge container: read-only root, non-root UID 10001, `cap_drop: ALL`, `no-new-privileges` | compose | It is the only container that talks to the internet. |
| Docker socket only through a read-only proxy (`POST=0`, loopback) | compose | `monitor` and `wud` need to read state, not control Docker. |
| API access logs (route, status, IP, caller `sub`; no tokens or bodies) | API Gateway | An audit trail of who did what. |

## Supply chain

- Every GitHub Action is pinned to a commit SHA, and workflows run with read-only tokens.
- CI runs gitleaks over the full history, `npm audit` (runtime, high+), `pip-audit` and
  CodeQL (`security-extended`, public repos).
- Dependabot opens weekly PRs into `develop` for npm, pip, the bridge image, the compose image
  tags and the Actions.
- The Lambdas use only boto3 from the runtime, so there are no third-party packages to patch.
- The public deploy workflow runs only when a fork sets `AWS_DEPLOY_ROLE_ARN`. It masks the
  account ID and never prints plan or apply output, so Actions logs don't map your AWS resources.

## Accepted risks and known limits

- **One trust level.** Every user in an allowed group can see and control every home in the
  stack. Per-home permissions are not built. Run one stack per household if that matters.
- **Tokens in `localStorage`.** This is standard for a SPA with PKCE. CSP is the mitigation: a
  successful XSS would still expose a 1-hour token.
- **CSP allows any API Gateway host in the region** (`https://*.execute-api.<region>.amazonaws.com`),
  not just yours. The exact endpoint would create a dependency cycle (API CORS ↔ CloudFront).
  Serving `/v1` through CloudFront would let `connect-src` be `'self'`; that's on the backlog.
- **The deploy role is broad.** IAM, S3 and DynamoDB are scoped to the `name_prefix`, but API
  Gateway, IoT, Cognito, CloudFront, Lambda, Logs, ACM and EventBridge are `*`, because they lack
  useful resource-level scoping at create time. Keep the trust pinned to your repo and branch.
- **`random_password.prefs_hmac` lives in state.** So does the IoT private key **if** you skip the
  CSR. Use the CSR path ([quickstart](quickstart.md), step 2).
- **The MQTT topic root is the fixed string `homeloft/`.** Two stacks in one AWS account must not
  reuse a `homeId`.
- **The Docker socket proxy allows GETs under `CONTAINERS=1`.** A compromised `monitor` or `wud`
  could read container logs and exports, but not start, exec or change anything.
- **Home Assistant runs with host networking, and it and Zigbee2MQTT run as root.** That is
  upstream's supported layout. Keep HA's own auth on and its port off the internet.
- **Updates are notify-only.** You still have to apply them; see
  [upgrading.md](upgrading.md).

## If something leaks

| Leaked | Do |
|---|---|
| HA long-lived token | HA → Profile → Security → delete it, create a new one, update `HA_TOKEN` in the NAS `.env`, `docker compose up -d bridge monitor`. |
| IoT private key | Create a new CSR on the NAS, swap it in `device_csrs`, apply (this creates a new certificate), install it, then delete the old certificate in IoT Core. |
| A user's password or TOTP device | Cognito → user → reset password / remove MFA, or `admin-user-global-sign-out`. |
| AWS access key | IAM → deactivate, then delete. CloudTrail → look up events by access key. CI is unaffected (OIDC). |
