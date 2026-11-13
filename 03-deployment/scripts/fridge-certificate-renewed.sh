#!/bin/sh
set -eu
case "${RENEWED_LINEAGE:-}" in
  /etc/letsencrypt/live/fridge.fenlengtech.com)
    /usr/sbin/nginx -t
    /usr/bin/systemctl reload nginx
    ;;
esac
