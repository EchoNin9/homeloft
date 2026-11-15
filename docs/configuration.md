# Configuration reference

Homeloft is configured in three places: the **cloud module's inputs** (your `terraform.tfvars`), the
**NAS `.env`** file, and the web app's **`config.json`** (which the module writes for you).
The source of truth is the code: [`variables.tf`](../cloud/terraform/modules/homeloft/variables.tf),
[`nas/.env.example`](../nas/.env.example) and [`web/README.md`](../web/README.md#configjson).

## Cloud module inputs

| Input | Default | What it does |
|---|---|---|
| `home_ids` | **required** | Homes to provision, one IoT Thing, certificate and policy each. Each id matches `^[a-z0-9-]{1,32}$` |
| `name_prefix` | `"homeloft"` | Prefix for every resource name. IoT Things are named `{name_prefix}-{homeId}`, which is also the MQTT client id |
| `device_csrs` | `{}` | Map `homeId => PEM CSR`. AWS signs the CSR, so the device's private key never enters state. **Without a CSR for a home, AWS generates the key and it is stored in plaintext in state** |
| `allowed_services` | lights, switches, scenes, thermostat, covers, fans | `domain.service` pairs the API may send. Deliberately conservative: no `lock.unlock`, alarms or scripts. The bridge has its own list too |
| `allowed_groups` | `["admin"]` | Cognito groups allowed to call the API. Created with the pool |
| `mfa` | `"ON"` | TOTP MFA for the created pool. `ON`: users set up an authenticator at first sign-in, then need a code every time. `OPTIONAL`: only already-enrolled users are asked. `OFF`: password only |
| `cognito_branding` | `true` | Style the sign-in page like the dashboard. Uses managed login and the Essentials tier (free for the first 10,000 monthly users) |
| `cognito_domain_prefix` | `null` | Hosted sign-in domain prefix. Default `{name_prefix}-{account_id}`. Globally unique per region |
| `enable_password_auth` | `false` | Enable `USER_PASSWORD_AUTH` for CLI or curl testing. Apps use the hosted UI with PKCE |
| `existing_user_pool_id` | `null` | Bring your own Cognito pool. The module then creates no pool, client or domain |
| `existing_user_pool_client_ids` | `[]` | Client ids the API accepts. Required with `existing_user_pool_id` |
| `existing_cognito_domain` | `""` | Hosted UI host of your pool, written into `config.json` only |
| `create_web_hosting` | `true` | Private S3 bucket and CloudFront distribution for the dashboard, with a generated `config.json` |
| `web_domain` | `null` | Custom domain for the dashboard, e.g. `home.example.com`. Creates an ACM certificate; the stack must be in `us-east-1`. See [Quickstart: custom domain](quickstart.md#10-custom-domain-optional) |
| `route53_zone_id` | `null` | Route 53 zone for `web_domain`, so the DNS records are created for you. Leave it `null` for other DNS hosts and create the `web_dns_records` output by hand |
| `web_callback_urls` | `[]` | Extra app URLs: OAuth callback and sign-out URLs on the created pool, and API CORS origins |
| `native_redirect_uris` | `[]` | Custom-scheme redirect URIs for mobile apps, e.g. `homeloft://auth` |
| `history_entities` | drive temperatures, doors, lights, `sun.sun`, containers | Entity id globs to keep history for: raw points for 35 days, daily summaries for 15 months. `[]` turns history off |
| `history_utc_offset_hours` | `0` | Fixed UTC offset where daily summaries split, e.g. `-5`. No DST handling. Match it to `TZ` on the NAS |
| `api_access_logs` | `true` | API Gateway access logs (route, status, latency, caller IP; never tokens or bodies) in CloudWatch |
| `log_retention_days` | `30` | Retention for the access log group |
| `tags` | `{}` | Tags for every taggable resource |

### Outputs

| Output | Use it for |
|---|---|
| `api_url` | API base URL (routes are under `/v1`) |
| `iot_endpoint`, `thing_names` | `IOT_ENDPOINT` and `IOT_THING_NAME` in the NAS `.env` |
| `certificate_pems` | The device certificate for each home |
| `private_keys` | Only for homes without a CSR. Sensitive |
| `user_pool_id`, `user_pool_client_id`, `cognito_domain` | Your own apps, and creating users |
| `web_url`, `web_bucket`, `web_distribution_id` | Deploying and opening the dashboard |
| `web_domain_status`, `web_dns_records` | Custom domain progress, and the records to create at an external DNS host |
| `table_name` | Inspecting data with the AWS CLI |

## NAS `.env`

Copy `nas/.env.example` to `.env` next to `docker-compose.yml`. Never commit it.

| Key | Example | What it does |
|---|---|---|
| `DATA_ROOT` | `/volume1/docker/homeloft` | Where every service keeps its data |
| `TZ` | `Europe/London` | IANA time zone for the containers |
| `HOME_ID` | `my-home` | Must be one of the module's `home_ids` |
| `IOT_ENDPOINT` | `…-ats.iot.<region>.amazonaws.com` | From the `iot_endpoint` output |
| `IOT_THING_NAME` | `homeloft-my-home` | From `thing_names`. It is also the MQTT client id |
| `HA_URL` | `ws://127.0.0.1:8123/api/websocket` | Home Assistant WebSocket URL |
| `HA_TOKEN` | | A long-lived access token from your HA profile |
| `BRIDGE_ALLOWED_DOMAINS` | `light,switch,sensor,…` | Entity domains the bridge exports and accepts commands for |
| `BRIDGE_ENTITY_EXCLUDE` | `sensor.wud_*,…` | Comma-separated globs on `entity_id` to never export |
| `BRIDGE_ALLOWED_SERVICES` | `light.turn_on,…` | The only services the cloud can ever call. `lock.unlock` and alarms are left out on purpose |
| `ZIGBEE_DEVICE` | `/dev/ttyUSB0` | With `--profile zigbee` |
| `ADGUARD_IP`, `ADGUARD_PARENT`, `LAN_SUBNET`, `LAN_GATEWAY` | | With `--profile adguard`. A free LAN IP outside DHCP, on a NIC other than the NAS's main one |
| `WUD_MQTT_PASSWORD`, `WUD_ADMIN_PASSWORD` | | Update checker ([Upgrading](upgrading.md#third-party-containers)) |
| `BACKUP_AT`, `BACKUP_KEEP` | `03:30`, `14` | Daily backup time and how many archives to keep |
| `BACKUP_S3_URI` | `s3://bucket/homeloft/` | Optional upload, only when you run `backup.sh` on the host with the AWS CLI |

## Web `config.json`

The module writes it next to `index.html` when `create_web_hosting` is on. For your own hosting, see
[`web/README.md`](../web/README.md#configjson): `apiUrl`, `clientId` and `cognitoDomain` are required.
