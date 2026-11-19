#!/usr/bin/env bash

set -e

command -v setfacl >/dev/null || { echo "ERREUR : setfacl n'est pas installé"; exit 1; }

# Réinitialise les ACL des seuls dossiers concernés
for d in media/movies media/series media/anime \
         media/raw/complete media/raw/incomplete media/raw/torrents; do
    test -d "$d" || { echo "Dossier manquant : $d"; exit 1; }
    setfacl -Rb "$d"
    setfacl -kR "$d"
done

# Fonction : droits existants + droits par défaut pour les nouveaux fichiers
apply_tree() {
    path="$1"; access="$2"; files="$3"; defaults="$4"
    find "$path" -type d -exec setfacl -m "$access" {} +
    find "$path" -type f -exec setfacl -m "$files" {} +
    find "$path" -type d -exec setfacl -m "$defaults" {} +
}

# Films : Jellyfin lecture ; Radarr et Bazarr lecture/écriture
apply_tree media/movies \
'u:100999:r-x,u:101001:rwx,u:101002:rwx,g::---,m::rwx,o::---' \
'u:100999:r--,u:101001:rw-,u:101002:rw-,g::---,m::rw-,o::---' \
'd:u:100999:r-x,d:u:101001:rwx,d:u:101002:rwx,d:g::---,d:m::rwx,d:o::---'

# Séries et anime : Jellyfin lecture ; Sonarr et Bazarr lecture/écriture
for d in media/series media/anime; do
    apply_tree "$d" \
    'u:100999:r-x,u:101000:rwx,u:101002:rwx,g::---,m::rwx,o::---' \
    'u:100999:r--,u:101000:rw-,u:101002:rw-,g::---,m::rw-,o::---' \
    'd:u:100999:r-x,d:u:101000:rwx,d:u:101002:rwx,d:g::---,d:m::rwx,d:o::---'
done

# Téléchargements terminés : qBittorrent + service concerné uniquement
apply_tree media/raw/complete \
'u:101004:rwx,g::---,m::rwx,o::---' \
'u:101004:rw-,g::---,m::rw-,o::---' \
'd:u:101004:rwx,d:g::---,d:m::rwx,d:o::---'

apply_tree media/raw/complete/sonarr \
'u:101004:rwx,u:101000:rwx,g::---,m::rwx,o::---' \
'u:101004:rw-,u:101000:rw-,g::---,m::rw-,o::---' \
'd:u:101004:rwx,d:u:101000:rwx,d:g::---,d:m::rwx,d:o::---'

apply_tree media/raw/complete/radarr \
'u:101004:rwx,u:101001:rwx,g::---,m::rwx,o::---' \
'u:101004:rw-,u:101001:rw-,g::---,m::rw-,o::---' \
'd:u:101004:rwx,d:u:101001:rwx,d:g::---,d:m::rwx,d:o::---'

# Téléchargements temporaires et torrents : qBittorrent uniquement
for d in media/raw/incomplete media/raw/torrents; do
    apply_tree "$d" \
    'u:101004:rwx,g::---,m::rwx,o::---' \
    'u:101004:rw-,g::---,m::rw-,o::---' \
    'd:u:101004:rwx,d:g::---,d:m::rwx,d:o::---'
done

# Traversée des dossiers parents sans autoriser leur consultation
setfacl -m 'u:100999:--x,u:101000:--x,u:101001:--x,u:101002:--x,u:101004:--x,g::---,m::--x,o::---' media
setfacl -m 'u:101000:--x,u:101001:--x,u:101004:--x,g::---,m::--x,o::---' media/raw

echo "ACL configurées."
echo "Propriétaires inchangés."
