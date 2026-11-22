#!/bin/sh
# Railway mounts the persistent volume at /data as root. The service runs as the
# unprivileged `node` user, so make the store directory writable before dropping
# privileges. The chown is a no-op (and never fatal) when the directory is
# already writable, so this also works for local `docker run` mounts.
set -e

STORE_DIR=$(dirname "${TRACK_STORE_PATH:-/data/purchases.json}")
mkdir -p "$STORE_DIR"
chown -R node:node "$STORE_DIR" 2>/dev/null || true

# Run the billing service as the non-root node user.
exec su node -s /bin/sh -c 'node src/index.js'
