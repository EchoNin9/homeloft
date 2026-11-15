# Troubleshooting

Start with the logs: `sudo docker compose logs --tail 50 bridge` on the NAS, and the
CloudWatch log groups of the `ingest` and `api` Lambdas in AWS. Most problems below show up in one of them.
For problems specific to DSM, also read [Synology gotchas](synology.md#synology-gotchas).

## Cloud and sign-in

| Symptom | Usual cause | Fix |
|---|---|---|
| `tofu init`: `Unsupported argument "use_lockfile"` | OpenTofu or Terraform older than 1.10 | Upgrade, or replace `use_lockfile` with a DynamoDB `dynamodb_table` |
| Sign-in page shows an error instead of the form | The domain is on managed login, but the app client has no style | Re-run `tofu apply`; the branding resource creates the style. Or set `cognito_branding = false` |
| `tofu apply`: Cognito domain already exists | The hosted UI prefix is globally unique per region | Set `cognito_domain_prefix` in the module call |
| META `online` missing | The IoT rule isn't firing | CloudWatch log group of the topic rule error action, and the ingest Lambda logs |
| Login: `redirect_mismatch` | The web URL isn't in the client's callback URLs | Re-apply; custom domains go in `web_callback_urls` |
| UI shows 403 | User isn't in the `admin` group, or a stale token from before the group was added | Add to the group, then sign out and back in |
| UI shows CORS error | API called from an origin the module doesn't know | Add the origin to `web_callback_urls` |
| Toggle reverts, toast says `stale` | NAS clock is off by more than 60 s | DSM → Regional Options → NTP |
| Toggle reverts, toast says `not_allowed` | Service isn't in `allowed_services` (API) or `BRIDGE_ALLOWED_SERVICES` (bridge) | Add it to both |

## Bridge

| Symptom | Usual cause | Fix |
|---|---|---|
| Exits immediately with `invalid configuration` | A variable or certificate file is missing or wrong | The message lists every bad or missing variable and file |
| TLS errors, `not authorized` or connection refused to IoT | Client id isn't the Thing name, wrong endpoint, or wrong file permissions | `IOT_THING_NAME` must equal the Thing name; use the account's `-ats` endpoint with `AmazonRootCA1.pem`; certificates must be readable by UID 10001. Clock drift also breaks TLS: enable NTP |
| `PermissionError` reading `private.key` | Certificates owned by the wrong user | `chown 10001` the certs folder and key ([Synology step 2](synology.md#2-cloud-credentials)) |
| Connects, then drops every few seconds | Two bridges using the same client id | Run only one bridge per home |
| `auth_invalid`, or `Home Assistant rejected the access token` | Token pasted with whitespace, or revoked | Create a new long-lived token, then recreate the container after editing `.env` |
| Can't reach `127.0.0.1:8123` | HA isn't up, or `HA_URL` has the wrong port | HA must run with `network_mode: host` |
| `snapshot sent: 0 entities` | Domain filter excludes everything, or HA was still loading when the bridge connected | Check `BRIDGE_ALLOWED_DOMAINS` and `BRIDGE_ENTITY_EXCLUDE`; otherwise restart the bridge |
| Commands come back `not_allowed` | Service not in `BRIDGE_ALLOWED_SERVICES`, or the entity is excluded or outside the allowed domains | Adjust `.env`, then `sudo docker compose up -d bridge` |
| Commands come back `stale` | NAS clock more than 60 s behind (or 10 s ahead of) the cloud | Fix NTP |

## On the NAS

| Symptom | Check |
|---|---|
| `compose up`: `Pool overlaps with other one on this address space` | An older project's AdGuard macvlan network still exists. Stop that project with its profiles (`--profile adguard down`), or `docker network rm` the old network |
| `compose up`: `Bind mount failed: …/wud does not exist` | Create the folder first: `sudo mkdir -p /volume1/docker/homeloft/wud` |
| Mosquitto exits | Missing or wrongly owned `passwd` file ([Synology step 3](synology.md#3-mosquitto-password-file)); see `docker logs` |
| Mosquitto logs `Error saving in-memory database ... Permission denied` | `mosquitto/data` isn't writable by UID 1883 (see [Synology gotchas](synology.md#synology-gotchas)) |
| `sudo: docker: command not found` | Use `/usr/local/bin/docker` (see [Synology gotchas](synology.md#synology-gotchas)) |
| **Service down** badge for a container that no longer exists | HA and the cloud both keep the last state of a removed container. Restart HA and delete the cloud item ([container monitoring](synology.md#9-container-monitoring)) |
| Container sensors or update tiles show `unavailable` after a recreate | WUD re-adds recreated containers on its next scan (06:00), or run `sudo docker compose restart wud` |
| Zigbee device not found | `ls /dev/tty*` on the NAS; the driver isn't loaded ([Synology step 6](synology.md#6-zigbee-optional)), or `.env` has the wrong device path |
| Ports 8123 or 1883 busy | Another package uses them. HA on host networking can't change port without editing HA's `http:` config |
