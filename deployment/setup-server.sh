#!/usr/bin/env bash
# Registers satellital-capture on a server that already has the shared
# company-deploy mechanism (section 5 of the multi-project deployment guide).
# Run on the server from a copy of this directory: sudo bash setup-server.sh
set -euo pipefail

APP=satellital-capture
FIRST_HOST_PORT=3002   # search start for the loopback port published by the container
FIRST_PROXY_PORT=8081  # search start for the private Caddy port on the Tailscale address
HERE="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_DEST=/etc/company-deploy/compose/$APP.yaml
ENV_DIR=/opt/$APP
PROJECTS=/etc/company-deploy/projects.json
CADDYFILE=/etc/caddy/Caddyfile

[[ $EUID -eq 0 ]] || { echo 'Run with sudo.'; exit 1; }
[[ -x /usr/local/sbin/company-deploy && -f $PROJECTS ]] || {
  echo 'The shared deployment mechanism is not installed on this server.'; exit 1;
}

port_in_use() { ss -Hltn "sport = :$1" | grep -q .; }

# Also skip ports reserved by other apps' Compose files, even if they are stopped
host_port_taken() {
  port_in_use "$1" || grep -rqs --exclude="$APP.yaml" -- "127.0.0.1:$1:" /etc/company-deploy/compose/
}

proxy_port_taken() {
  port_in_use "$1" || grep -Eqs -- ":$1([^0-9]|$)" "$CADDYFILE"
}

next_free() {
  local port=$1 taken=$2
  while "$taken" "$port"; do
    port=$((port + 1))
    (( port < 65536 )) || { echo 'No free port found.' >&2; exit 1; }
  done
  echo "$port"
}

# 1. Loopback port: keep the one already installed, otherwise take the next free one
HOST_PORT="$(grep -oPs '127\.0\.0\.1:\K[0-9]+(?=:8080)' "$COMPOSE_DEST" || true)"
[[ -n $HOST_PORT ]] || HOST_PORT="$(next_free "$FIRST_HOST_PORT" host_port_taken)"
echo "Loopback port: $HOST_PORT"

# 2. Protected Compose file
install -d -o root -g root -m 755 /etc/company-deploy/compose
sed "s/127\.0\.0\.1:[0-9]*:8080/127.0.0.1:$HOST_PORT:8080/" "$HERE/compose.yaml" > "$COMPOSE_DEST.tmp"
install -o root -g root -m 644 "$COMPOSE_DEST.tmp" "$COMPOSE_DEST"
rm -f "$COMPOSE_DEST.tmp"
echo "Installed $COMPOSE_DEST"

# 3. Empty application config (the app needs no variables)
install -d -o root -g root -m 755 "$ENV_DIR"
[[ -e $ENV_DIR/.env ]] || install -o root -g root -m 644 /dev/null "$ENV_DIR/.env"

# 4. Add the allowlist entry, keeping every existing project
cp -p "$PROJECTS" "$PROJECTS.bak.$(date +%Y%m%d%H%M%S)"
python3 - "$PROJECTS" "$HERE/project-entry.json" <<'EOF'
import json, os, sys, tempfile
path, entry_path = sys.argv[1], sys.argv[2]
with open(path) as f:
    config = json.load(f)
with open(entry_path) as f:
    entry = json.load(f)
config.setdefault('projects', {}).update(entry)
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
with os.fdopen(fd, 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')
os.chmod(tmp, 0o644)
os.replace(tmp, path)
print('Registered:', ', '.join(sorted(config['projects'])))
EOF

# 5. Private Caddy site bound to the Tailscale address
if [[ -f $CADDYFILE ]] && ! grep -q "127.0.0.1:$HOST_PORT" "$CADDYFILE"; then
  PROXY_PORT="$(next_free "$FIRST_PROXY_PORT" proxy_port_taken)"
  ts_ip="$(tailscale ip -4 | head -n1)"
  backup="$CADDYFILE.bak.$(date +%Y%m%d%H%M%S)"
  cp -p "$CADDYFILE" "$backup"
  cat >> "$CADDYFILE" <<EOF

http://$ts_ip:$PROXY_PORT {
	bind $ts_ip
	reverse_proxy 127.0.0.1:$HOST_PORT
}
EOF
  if caddy validate --config "$CADDYFILE" --adapter caddyfile >/dev/null; then
    systemctl reload caddy
    echo "Caddy: http://$ts_ip:$PROXY_PORT"
  else
    cp -p "$backup" "$CADDYFILE"
    echo 'Caddy validation failed; the previous Caddyfile was restored.'; exit 1
  fi
fi

echo 'Server ready for satellital-capture.'
