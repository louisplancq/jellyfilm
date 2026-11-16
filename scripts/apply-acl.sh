#!/usr/bin/env bash
# Reapplies the reference permissions of the stack.
#   media/ : POSIX ACLs only (no shared group). Additive: file owners are
#            never changed, existing entries are kept.
#   data/  : each data/<service> directory belongs entirely to its service,
#            and other host users cannot enter data/.
# Idempotent: safe to run as often as needed (stop the stack first).
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "ERROR: run with sudo"; exit 1; }
command -v setfacl >/dev/null || { echo "ERROR: setfacl not installed"; exit 1; }

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Host UIDs (rootless: container UID + 99999)
LOUIS=1000
JELLYFIN=100999   # container 1000
SONARR=101000     # container 1001
RADARR=101001     # container 1002
BAZARR=101002     # container 1003
PROWLARR=101003   # container 1004
QBIT=101004       # container 1005
CADDY=101005      # container 1006
SEERR=101006      # container 1007
USERS_GID=100999  # container group 1000 ("users")

for d in media media/raw media/raw/complete media/raw/complete/radarr \
         media/raw/complete/sonarr media/raw/incomplete media/raw/torrents \
         media/movies media/series media/anime data; do
    [[ -d "$d" ]] || { echo "ERROR: missing directory: $d"; exit 1; }
done

# user_entries PERMS UID... -> "u:UID:PERMS,u:UID:PERMS"
user_entries() {
    local perms="$1"; shift
    local out="" u
    for u in "$@"; do out+="u:$u:$perms,"; done
    echo "${out%,}"
}

# grant_access_recursive PATH UID...
# Gives the listed users access to PATH and everything below it.
# Directories: rwx + default ACL (inherited by new files). Files: rw-.
grant_access_recursive() {
    local path="$1"; shift
    local dirs files defaults
    dirs="$(user_entries rwx "$@"),g::---,m::rwx,o::---"
    defaults="$(user_entries rwx "$@" | sed 's/u:/d:u:/g'),d:g::---,d:m::rwx,d:o::---"
    files="$(user_entries rw- "$@"),g::---,m::rw-,o::---"
    find "$path" -type d -exec setfacl -m "$dirs,$defaults" {} +
    find "$path" -type f -exec setfacl -m "$files" {} +
}

# own_recursive OWNER PATH...
# Makes OWNER the owner of PATH and everything below it.
own_recursive() {
    local owner="$1"; shift
    local p
    for p in "$@"; do
        mkdir -p "$p"
        chown -R "$owner" "$p"
    done
}

echo "== media: parent directories (traverse only)"
chmod 0710 media media/raw
setfacl -x u:1002 media 2>/dev/null || true   # stray entry, no matching service
setfacl -m "$(user_entries --x $JELLYFIN $SONARR $RADARR $BAZARR $QBIT),g::---,m::--x,o::---" media
setfacl -m "$(user_entries --x $SONARR $RADARR $QBIT),g::---,m::--x,o::---" media/raw

echo "== media: downloads"
chmod 0770 media/raw/complete media/raw/complete/radarr media/raw/complete/sonarr \
           media/raw/incomplete media/raw/torrents
chmod g-s media/raw/complete/radarr           # access is ACL-only, no setgid group
grant_access_recursive media/raw/complete        $LOUIS $QBIT
grant_access_recursive media/raw/complete/radarr $LOUIS $QBIT $RADARR
grant_access_recursive media/raw/complete/sonarr $LOUIS $QBIT $SONARR
grant_access_recursive media/raw/incomplete      $LOUIS $QBIT
grant_access_recursive media/raw/torrents        $LOUIS $QBIT

echo "== media: libraries"
chmod 0770 media/movies media/series media/anime
grant_access_recursive media/movies $LOUIS $JELLYFIN $RADARR $BAZARR
grant_access_recursive media/series $LOUIS $JELLYFIN $SONARR $BAZARR
grant_access_recursive media/anime  $LOUIS $JELLYFIN $SONARR $BAZARR

echo "== data: one owner per service"
own_recursive $JELLYFIN:$USERS_GID data/jellyfin/config
own_recursive $SONARR:$USERS_GID   data/sonarr
own_recursive $RADARR:$USERS_GID   data/radarr
own_recursive $BAZARR:$USERS_GID   data/bazarr
own_recursive $PROWLARR:$USERS_GID data/prowlarr
own_recursive $QBIT:$USERS_GID     data/qbittorent
own_recursive $CADDY:$USERS_GID    data/caddy/data data/caddy/config
own_recursive $SEERR:$USERS_GID    data/seerr
setfacl -Rb data/seerr                         # Seerr no longer shares Jellyfin's UID

echo "== data: no access for other host users"
find data -maxdepth 1 -type d -exec chmod o-rwx {} +
[[ -f .env ]] && chmod 600 .env

echo "Permissions reapplied."
