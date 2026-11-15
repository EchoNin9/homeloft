# Upgrading

Homeloft has two kinds of upgrades: **Homeloft itself** (cloud module, web app and bridge, which share one
version) and **the third-party containers** on the NAS (Home Assistant, Mosquitto, Zigbee2MQTT and the rest).

Before any upgrade, take a backup on the NAS: `sudo docker compose exec backup bash /backup.sh`.

## Homeloft releases

Each release is a `vX.Y.Z` tag with notes in the [Changelog](../CHANGELOG.md). The version follows SemVer:

| Bump | Meaning | Order |
|---|---|---|
| patch, minor | Fixes and features. The `/v1` contract only gains fields | Cloud first, then the bridge, whenever convenient |
| major | A breaking change to the [contract](contract.md) | Cloud and bridge together, in one sitting. The release notes say what breaks |

**Cloud and web**, from a checkout of the new tag:

```sh
git fetch --tags && git checkout vX.Y.Z
cd cloud/terraform/examples/standalone
tofu init -backend-config=backend.hcl && tofu plan    # read it: nothing important should be replaced
tofu apply
cd ../../../.. && ./scripts/deploy-web.sh
curl -s "$(cd cloud/terraform/examples/standalone && tofu output -raw api_url)/v1/health"   # {"ok":true,"version":"X.Y.Z"}
```

If you use the module from your own stack, change the `?ref=vX.Y.Z` in its `source` instead. With the
[GitHub deploy workflow](quickstart.md#9-auto-deploy-from-github-optional), merging the new version to `main` does the same.

**NAS**, from the stack folder: copy the new `nas/bridge` folder and `nas/docker-compose.yml` into it. Copy them
as the user that owns the folder, or with `sudo` and then `chown` the files back, because `tar` and `cp` can't replace
files owned by another DSM user. Then build the bridge and start what changed:

```sh
sudo DOCKER_BUILDKIT=0 docker build -t homeloft-bridge:X.Y.Z bridge   # legacy builder: DSM has no seccomp for BuildKit
sudo docker compose pull --ignore-pull-failures                      # the bridge image is local, so its pull "fails"
sudo docker compose up -d                                            # add --profile adguard / zigbee if you use them
sudo docker compose logs --tail 20 bridge    # connected to Home Assistant, connected to IoT Core, snapshot sent
```

On a non-Synology host, `sudo docker compose build bridge` works instead of the legacy build. If HA restarted too,
the first `snapshot sent` can be small; a second one follows once HA has finished starting.

## Third-party containers

The `wud` service (What's Up Docker) checks every container's image daily at 06:00. When a newer image
exists, the dashboard shows an amber update badge (and a count on **Updates** in the sidebar). Clicking
either shows the commands to run. It only notifies: nothing in the cloud can upgrade the NAS.

Setup, once:
1. Add an MQTT user for it. Put the password in `.env` as `WUD_MQTT_PASSWORD`, then run
   `sudo docker run --rm -v /volume1/docker/homeloft/mosquitto/passwd:/p eclipse-mosquitto:2 mosquitto_passwd -b /p wud "$PW"`
   and `sudo docker kill -s HUP homeloft-mosquitto-1`.
2. Set `WUD_ADMIN_PASSWORD` in `.env`. WUD 9 won't start without one, even though its UI is off.
3. `sudo mkdir -p /volume1/docker/homeloft/wud && sudo docker compose up -d wud`.
4. Add `update` to `BRIDGE_ALLOWED_DOMAINS`, and `sensor.wud_*,binary_sensor.wud_*` to
   `BRIDGE_ENTITY_EXCLUDE`. Then run `sudo docker compose up -d bridge`.

Upgrading, from the stack folder:

| The update says | Do |
|---|---|
| `<svc> · new :<tag>` (same tag, new image) | `sudo docker compose pull <svc> && sudo docker compose up -d <svc>` |
| `<svc> <old> → <new>` | Change the image tag in `docker-compose.yml` (and in the repo), then `sudo docker compose up -d <svc>` |
| bridge | Not checked by WUD. See [Homeloft releases](#homeloft-releases) |

Then `sudo docker image prune -f`.

## Rolling back

- **Containers:** put the old image tag back and `sudo docker compose up -d <svc>`. Restore the backup if the
  upgrade changed the service's config ([Synology backups](synology.md#7-backups)).
- **Homeloft:** check out the previous tag and repeat the cloud and bridge steps. Within one major version,
  any bridge works with any cloud.
