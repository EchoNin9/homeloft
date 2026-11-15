# Quickstart: first deploy (to milestone M1)

Goal: the web UI on CloudFront signs in, shows your real Home Assistant entities, and toggles a
real device. Every phase ends with a **smoke test**. Don't move on until it passes; the table at
the end maps each failure to its usual cause.

Time: about 1–2 hours. Commands assume the repo root unless a `cd` says otherwise.

## 0. Prerequisites

- [ ] AWS account and an admin CLI profile: `export AWS_PROFILE=... AWS_REGION=us-east-1`.
      Any IoT Core region works; use the same region everywhere below.
- [ ] **OpenTofu ≥ 1.10** (`tofu version`). Terraform ≥ 1.10 also works if you set `TOFU=terraform`
      for the scripts.
- [ ] Node 20+ and npm, and `jq`.
- [ ] Synology DSM 7.2+ with Container Manager installed and SSH enabled.
- [ ] Your home's **time zone**, in two forms. You'll need both:
      - the IANA name (e.g. `America/Vancouver`), for `TZ` in the NAS `.env`;
      - its UTC offset in whole hours (e.g. `-7`), for `history_utc_offset_hours` in `terraform.tfvars`.
        Daily history summaries split at that local midnight.

      The offset is fixed, with no DST. If your zone changes its clocks, pick the offset you're on
      most of the year. Summaries then split an hour off local midnight for the rest of the year.
- [ ] Home Assistant isn't running yet, or you'll move an existing install into
      `/volume1/docker/homeloft/homeassistant` ([Moving an existing install](#moving-an-existing-install)).

## 1. State bucket (one time per AWS account)

OpenTofu state for every Homeloft stack lives in one S3 bucket. The bucket is versioned,
encrypted, blocks public access, allows TLS only, and expires old state versions after 90 days.
Locking uses S3 lockfiles, so no DynamoDB table is needed.

```sh
cd cloud/terraform/bootstrap
tofu init && tofu apply                   # creates homeloft-tfstate-<account>-<region>
tofu output -raw backend_hcl              # you'll paste this in step 3
```

Then move the bootstrap stack's own state into the bucket, so nothing is kept only on your
laptop:

```sh
printf 'terraform {\n  backend "s3" {}\n}\n' > backend_override.tf   # gitignored
tofu init -migrate-state \
  -backend-config="bucket=$(tofu output -raw bucket)" \
  -backend-config="key=homeloft/bootstrap.tfstate" \
  -backend-config="region=$AWS_REGION" \
  -backend-config="encrypt=true" -backend-config="use_lockfile=true"
rm -f terraform.tfstate terraform.tfstate.backup
```

**Smoke test:** `aws s3 ls s3://<bucket>/homeloft/` lists `bootstrap.tfstate`, and
`aws s3api get-bucket-versioning --bucket <bucket>` shows `"Status": "Enabled"`.

## 2. Device key and CSR (on the NAS, so the private key never leaves it)

```sh
ssh you@nas
sudo mkdir -p /volume1/docker/homeloft/bridge/certs && cd /volume1/docker/homeloft/bridge/certs
sudo openssl req -new -newkey rsa:2048 -nodes \
  -keyout private.key -out home.csr -subj "/CN=homeloft-home"
sudo chmod 600 private.key
```

Copy **only** `home.csr` to your deploy machine, at
`cloud/terraform/examples/standalone/certs/home.csr` (gitignored).

**Smoke test:** `openssl req -in home.csr -noout -verify` prints `verify OK`.

## 3. Cloud stack

```sh
cd cloud/terraform/examples/standalone
cp backend.hcl.example backend.hcl            # paste the backend_hcl output from step 1
cp terraform.tfvars.example terraform.tfvars  # region, home_ids, device_csr_files, history_utc_offset_hours
tofu init -backend-config=backend.hcl
tofu plan -out=plan.bin                       # look it over: ~40 resources, nothing destroyed
tofu apply plan.bin
```

**Smoke tests**
- [ ] `curl -s "$(tofu output -raw api_url)/v1/health"` returns `{"ok": true, ...}`.
- [ ] `aws s3 ls s3://<state-bucket>/homeloft/` now also lists `standalone.tfstate`.
- [ ] `tofu output private_keys` is empty, because you used a CSR.

Note these values for the NAS: `tofu output -raw iot_endpoint` and `tofu output -json thing_names`
(for example `{"home":"homeloft-home"}`).

## 4. Certificate to the NAS

```sh
tofu output -json certificate_pems | jq -r '.home' > cert.pem
curl -sO https://www.amazontrust.com/repository/AmazonRootCA1.pem
scp cert.pem AmazonRootCA1.pem you@nas:/tmp/
```

Then on the NAS:

```sh
cd /volume1/docker/homeloft/bridge/certs
sudo mv /tmp/cert.pem /tmp/AmazonRootCA1.pem . && sudo rm -f home.csr
sudo chown -R 10001:10001 . && sudo chmod 700 . && sudo chmod 600 private.key
ls   # AmazonRootCA1.pem  cert.pem  private.key
```

**Smoke test (on the NAS):** the cert matches the key. These two hashes must be identical:

```sh
sudo openssl x509 -noout -pubkey -in cert.pem | openssl sha256
sudo openssl pkey -pubout -in private.key | openssl sha256
```

## 5. Your login

```sh
POOL=$(tofu output -raw user_pool_id)
aws cognito-idp admin-create-user --user-pool-id "$POOL" --username you@example.com \
  --user-attributes Name=email,Value=you@example.com Name=email_verified,Value=true
aws cognito-idp admin-add-user-to-group --user-pool-id "$POOL" --username you@example.com --group-name admin
```

Cognito emails you a temporary password. You'll set a new one at first sign-in in step 7.

**Smoke test:** `aws cognito-idp admin-list-groups-for-user --user-pool-id "$POOL" --username you@example.com`
lists `admin`.

**Sign-in page branding.** With the default `cognito_branding = true`, the module styles the sign-in page
like the dashboard: Homeloft logo, teal buttons, dark theme. It uses Cognito
*managed login*, which needs the pool's **Essentials** tier. Essentials is free for the first 10,000 monthly
active users and is the default for new pools. To keep AWS's classic hosted UI and the Lite tier, set
`cognito_branding = false` in the module call. The logo files are in
`cloud/terraform/modules/homeloft/branding/`. The setting has no effect with `existing_user_pool_id`:
style your own pool in the Cognito console (Managed login → Styles).

## 6. NAS stack

Follow [synology.md](synology.md) steps 1, 3, 4 and 5 (skip step 2: certificates are already done).
Set these values in `.env`:

| `.env` key | Value |
|---|---|
| `HOME_ID` | `home` (must match `home_ids`) |
| `IOT_ENDPOINT` | `tofu output -raw iot_endpoint` |
| `IOT_THING_NAME` | `homeloft-home`, from `thing_names` |
| `HA_TOKEN` | the long-lived token from HA (synology.md step 5) |

**Smoke tests**
- [ ] `sudo docker logs homeloft-bridge-1` shows `connected to Home Assistant`, `connected to IoT Core`
      and `snapshot sent: N entities` with N > 0. If N is 0 on a first start, the bridge reached
      Home Assistant before HA finished loading: `sudo docker restart homeloft-bridge-1` and check again.
- [ ] From the deploy machine, the cloud sees the home as online:
  ```sh
  aws dynamodb get-item --table-name "$(tofu output -raw table_name)" \
    --key '{"PK":{"S":"HOME#home"},"SK":{"S":"META"}}' --query 'Item.online'
  ```
  This returns `{"BOOL": true}`.

## 7. Web UI

```sh
./scripts/deploy-web.sh        # builds web/, syncs to the bucket, invalidates CloudFront
```

This leaves the module-managed `config.json` in the bucket untouched.

**Smoke tests**
- [ ] `curl -s "$(cd cloud/terraform/examples/standalone && tofu output -raw web_url)/config.json"`
      shows your `apiUrl`, `userPoolId` and `clientId`.
- [ ] Open `web_url` and sign in with the temporary password from the email. You then set a new
      password and, because the module sets `mfa = "ON"`, scan a QR code with an authenticator app
      (any TOTP app) and enter its 6-digit code. Your home shows as **online** with entities grouped by domain.

## 8. End to end (this is M1)

- [ ] Toggle a light or switch in the web UI. The physical device changes within about 2 s and
      the toggle stays put rather than reverting.
- [ ] Bridge log shows `command c_... light.turn_on -> ok`.
- [ ] Change the device from the HA UI or a wall switch. The web UI reflects it within about 5 s,
      one poll cycle.

When all three pass, tick M1 in [mobile.md](mobile.md). Mobile work can then start.

## 9. Auto-deploy from GitHub (optional)

`.github/workflows/deploy.yml` runs on a push to `main` that touches `cloud/`, `web/` or
`scripts/deploy-web.sh` (not `*.md`, tests or mock data). It runs `tofu apply` on the standalone
stack, then `scripts/deploy-web.sh`. It refuses any plan that deletes or replaces the IoT
certificate, the DynamoDB table or the user pool.

1. The account needs GitHub's OIDC provider (`token.actions.githubusercontent.com`) once.
2. In `bootstrap/terraform.tfvars` set `github_repo = "owner/repo"` and apply the bootstrap
   stack. It creates role `github-actions-homeloft-deploy`, which only `main` of that repo can
   assume. IAM, S3 and DynamoDB access is limited to `homeloft-*` names. Newer repos use
   GitHub's immutable OIDC subject. Run `gh api repos/OWNER/REPO/actions/oidc/customization/sub`,
   and if `use_immutable_subject` is true, set `github_sub_prefix` to the `sub_claim_prefix` it
   prints. Otherwise the role can't be assumed (`Not authorized to perform sts:AssumeRoleWithWebIdentity`).
3. Copy the stack's gitignored files to where CI reads them:
   `aws s3 cp examples/standalone/terraform.tfvars s3://<state-bucket>/homeloft/local-files/examples/standalone/terraform.tfvars`
   (same for `backend.hcl`). **From now on the S3 copy is what deploys.** Re-upload after you edit
   the local file.
4. Repo variables: `AWS_DEPLOY_ROLE_ARN` (bootstrap output `deploy_role_arn`) and
   `TOFU_STATE_BUCKET`.
5. Re-apply the bootstrap stack whenever its deploy policy changes. The deploy role can only
   create what the policy lists, so apply bootstrap **before** merging the module change that
   needs it. Example: `events:*` for the daily history rollup schedule.

**History:** the module keeps history for entities matching `history_entities` (globs, with
defaults for drive temps, doors, lights, `sun.sun` and NAS containers). Set it to `[]` to turn
history off. Daily summaries split at local midnight for `history_utc_offset_hours` (a fixed offset, no DST,
default 0 = UTC). A daily `homeloft-rollup` Lambda runs at 00:15 local. Smoke test after a day:
`aws lambda invoke --function-name homeloft-rollup /dev/stdout` returns `"rollups": N` with N > 0.

## 10. Custom domain (optional)

The web app answers on its CloudFront address (`https://dxxxx.cloudfront.net`) until you give it a
domain. Use a subdomain, such as `homeloft.example.com`: some DNS hosts can't point a bare domain
at CloudFront. The stack must be in `us-east-1`, which is where CloudFront certificates live.

Set `web_domain` in `terraform.tfvars`. Then pick where its DNS is hosted:

**A. Route 53 (AWS hosts the DNS).** Also set `route53_zone_id` to the hosted zone's id. One apply
creates the certificate, validates it, and adds `A`/`AAAA` alias records. The deploy role needs the
`Route53Records` statement, so re-apply the bootstrap stack first (step 9.5).

**B. Any other DNS host (ClouDNS, Cloudflare, your registrar…).** Leave `route53_zone_id` unset.
1. Apply (or, with auto-deploy, upload the tfvars to S3 and run the **deploy** workflow by hand).
   This creates the certificate and prints `web_domain_status = PENDING_VALIDATION` and
   `web_dns_records`, two `CNAME`s. The deploy workflow also shows them on the run's summary page.
2. Create both `CNAME` records at the DNS host, exactly as printed:
   - **Certificate validation:** `_xxxx.homeloft.example.com.` → `_yyyy.acm-validations.aws.`
     Keep it: ACM uses it again to renew the certificate every year.
   - **The site:** `homeloft.example.com.` → `dxxxx.cloudfront.net.`
   On ClouDNS: open the zone, then **Add new record**, type **CNAME**. **Host** is the name without
   the zone (e.g. `homeloft`, or `_xxxx.homeloft`), and **Points to** is the value, with its trailing dot.
3. Wait for ACM to validate it, usually a few minutes:
   `aws acm list-certificates --region us-east-1 --query "CertificateSummaryList[?DomainName=='homeloft.example.com'].Status"`
   shows `ISSUED`.
4. Apply again (or re-run the deploy workflow). CloudFront takes on the domain, and
   `web_domain_status` becomes `LIVE`. The CloudFront change takes about 5–10 minutes to roll out.

Either way, the domain is added to the Cognito sign-in redirect URLs and API CORS on the first
apply. The CloudFront address keeps working too.

## 11. View prefs sync (automatic) and optional KMS encryption

Groups, favourites, hidden items, saved searches and sort sync to your account through
`GET`/`PUT /v1/homes/{homeId}/prefs` (`docs/contract.md`, "Prefs"). Nothing to set up: the module
generates `PREFS_HMAC_KEY` (`random_password.prefs_hmac`) and stores prefs under
`USER#{HMAC(sub)}`, so the table never holds your Cognito user id. Your browser's existing
local prefs are uploaded the first time you open the dashboard after the deploy.

- [ ] Smoke test: rearrange a group, then open the site in another browser (or a private window).
      The same groups show up.
- Never `tofu taint` or replace `random_password.prefs_hmac`. A new key orphans every saved
  item, and each browser re-uploads its local copy.

**Optional: encrypt prefs with your own KMS key** (not built; ~$1/month plus $0.03 per 10,000
requests). The table already has AWS-owned encryption at rest. This step adds a key that only
the API role can use, and every decrypt is logged in CloudTrail. It needs a small code change:
1. Module: add an `aws_kms_key` (with `enable_key_rotation = true`) and an alias, give the API
   role `kms:Encrypt` and `kms:Decrypt` on it, and pass its ARN to the API Lambda as `PREFS_KMS_KEY`.
2. `cloud/lambdas/api/handler.py`, `put_prefs`: `boto3.client("kms").encrypt(KeyId=…, Plaintext=<the
   prefs string>, EncryptionContext={"pk": <PK>, "sk": <SK>})`. Store the `CiphertextBlob` as
   binary `prefs_enc` and drop `prefs`. The context binds the ciphertext to its own item.
3. `get_prefs`: `decrypt` `prefs_enc` (same context) when it's there; otherwise read the plain
   `prefs`, so existing items keep working until their next save.
4. Contract: add `prefs_enc` to the `USER#` row. Add a moto test that the stored item holds no
   plaintext. Deploy, then save any change in each browser to re-encrypt.

boto3 only, so the Lambda zip packaging doesn't change.

## Moving an existing install

Already running Home Assistant (and maybe Mosquitto, Zigbee2MQTT or AdGuard) from another compose
project? Keep their data and swap the stack around them. Prepare everything first, so the downtime
is only the swap (about 2 minutes):

1. Do steps 1–5 as written, but put the new key in a side folder (e.g. `bridge/certs.new`) and the
   new stack in `stack.new`. Build the bridge image ahead of time (synology.md step 5, legacy builder).
2. Copy your old `.env` into `stack.new/.env` and change `DATA_ROOT`, `IOT_THING_NAME` and `IOT_ENDPOINT`.
   Keys like `HA_TOKEN` and the AdGuard network settings carry over.
3. Take a backup, then stop the old project **including its profiled services**. A plain
   `docker compose down` leaves `adguard` and `zigbee2mqtt` (and AdGuard's LAN network) running:
   ```sh
   sudo docker compose --profile adguard --profile zigbee down
   ```
4. Move the data folder to `/volume1/docker/homeloft` (keep `homeassistant/`, `mosquitto/`,
   `zigbee2mqtt/`, `adguard/`, `backups/`), put `stack.new` and `certs.new` in place, and
   `sudo mkdir -p /volume1/docker/homeloft/wud`.
5. `sudo docker compose --profile adguard up -d --no-build` (add `--profile zigbee` if you use it).
   HA keeps its config, pairings and the MQTT login, so the existing token keeps working.

History and dashboard prefs live in DynamoDB. They don't move with the NAS. To carry them from an
older deployment, export the old table with `aws dynamodb scan` before tearing it down. Prefs rows are
keyed by `HMAC(PREFS_HMAC_KEY, sub)`, so they have to be re-keyed for the new user and key.

## Troubleshooting

See [Troubleshooting](troubleshooting.md).

## Teardown

`tofu destroy` in `examples/standalone` removes everything except the state bucket, which has
`prevent_destroy`. Delete the bucket by hand only once no stack uses it.
