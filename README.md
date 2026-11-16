# Jellyfilms

Self-hosted media server stack managed with Docker Compose and **Rootless Docker**.

## Services

| Service          | Purpose                          |
| ---------------- | -------------------------------- |
| **Jellyfin**     | Media streaming                  |
| **Sonarr**       | TV series and anime management   |
| **Radarr**       | Movie management                 |
| **Bazarr**       | Subtitle management              |
| **Prowlarr**     | Indexer management               |
| **qBittorrent**  | Torrent downloads                |
| **Seerr**        | Media requests                   |
| **FlareSolverr** | Cloudflare challenge handling    |
| **Caddy**        | Reverse proxy, HTTPS and DuckDNS |

## Permissions and isolation

Each LinuxServer container runs with a dedicated UID and a shared primary GID.

| Service     | PUID | PGID | Host UID |
| ----------- | ---: | ---: | -------: |
| Jellyfin    | 1000 | 1000 |   100999 |
| Sonarr      | 1001 | 1000 |   101000 |
| Radarr      | 1002 | 1000 |   101001 |
| Bazarr      | 1003 | 1000 |   101002 |
| Prowlarr    | 1004 | 1000 |   101003 |
| qBittorrent | 1005 | 1000 |   101004 |

Rootless Docker uses the following UID/GID mapping:

- Container ID `0` → host ID `1000`.
- Container ID `1000` → host ID `100999`.
- Container IDs `1001`–`1005` → host IDs `101000`–`101004`.

Media files belong to `<user>:<user>`. Application configuration directories under `data/` retain their respective service ownership.

**Access is controlled through POSIX ACLs**, not the shared primary group. Each service only gets access to the directories it needs:

| Directory                    | Access                                          |
| ---------------------------- | ----------------------------------------------- |
| `media/movies/`              | Jellyfin (read), Radarr and Bazarr (read/write) |
| `media/series/`              | Jellyfin (read), Sonarr and Bazarr (read/write) |
| `media/anime/`               | Jellyfin (read), Sonarr and Bazarr (read/write) |
| `media/raw/complete/Sonarr/` | Sonarr and qBittorrent (read/write)             |
| `media/raw/complete/Radarr/` | Radarr and qBittorrent (read/write)             |
| `media/raw/incomplete/`      | qBittorrent only                                |
| `media/raw/torrents/`        | qBittorrent only                                |

Default ACLs ensure that newly created files and directories inherit the appropriate permissions.

### Apply permissions

All media ACL configuration is centralized in `scripts/apply-acl.sh`.

Run from the project root:

```sh
sudo bash scripts/apply-acl.sh
```

Run it after restoring media files or whenever permissions need to be reapplied. Requires `acl` (`setfacl` and `getfacl`).

## Download paths

qBittorrent uses separate download categories:

| Category | qBittorrent path    |
| -------- | ------------------- |
| Sonarr   | `/downloads/sonarr` |
| Radarr   | `/downloads/radarr` |

These paths are mounted identically in qBittorrent and their respective \*arr containers. No Remote Path Mapping is required.

## Deployment

1. Install and configure Rootless Docker.
2. Restore the project, `.env`, Caddy configuration and application data.
3. Restore media files with ownership `<user>:<user>`:

```sh
sudo chown -R <user>:<user> media/
```

4. Apply ACLs:

```sh
sudo bash scripts/apply-acl.sh
```

5. Validate and start the stack:

```sh
docker --context rootless compose config --quiet
make start
```

## Management

```sh
make start   # Pull images, build Caddy and start services
make stop    # Stop services
```

Useful commands:

```sh
docker --context rootless compose ps -a
docker --context rootless compose logs --tail=100
docker --context rootless info
```

### Rootless Docker service

```sh
systemctl --user status docker.service
systemctl --user restart docker.service
journalctl --user -u docker.service -f
```

### LazyDocker

Configure the Rootless Docker socket in Fish:

```fish
set -Ux DOCKER_HOST "unix:///run/user/"(id -u)"/docker.sock"
```

Remove it with:

```fish
set -eU DOCKER_HOST
```

## Requirements

- Linux with systemd.
- Docker Engine in Rootless mode.
- Docker Compose plugin.
- `uidmap` (`newuidmap`, `newgidmap`).
- `acl` (`setfacl`, `getfacl`).
- `make`.

## Rootless Docker setup

Configure the subordinate UID/GID ranges in both `/etc/subuid` and `/etc/subgid`:

```text
<user>:100000:65536
```

Install Docker Rootless following the official instructions for your distribution.

Enable the user service and automatic startup:

```sh
systemctl --user enable --now docker.service
sudo loginctl enable-linger <user>
```

Create the Docker context:

```sh
docker context create rootless \
  --docker "host=unix:///run/user/$(id -u)/docker.sock"
```

Verify Rootless mode:

```sh
docker --context rootless info
```

