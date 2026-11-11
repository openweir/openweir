#!/bin/sh
# OpenWeir proxy installer. Usage:
#   sh install-proxy.sh --panel <panel URL> --token <token>
#   sh install-proxy.sh --uninstall
# The panel serves this script at <panel>/api/v1/node/proxy/install.sh with --panel preset.
set -eu

PANEL=""
NAME="openweir-proxy"
BIN_DIR="/usr/local/bin"
CONFIG_DIR="/etc/openweir"
CONFIG="/etc/openweir/proxy.yml"
SVC_USER=""
STATE_DIR=""
ASSET_DIR="/usr/local/share/openweir"
GEODATA="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download"
TOKEN=""
UNINSTALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --panel) PANEL="$2"; shift 2 ;;
    --token) TOKEN="$2"; shift 2 ;;
    --uninstall) UNINSTALL=1; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

[ "$(id -u)" -eq 0 ] || { echo "Run as root" >&2; exit 1; }
command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }

if command -v systemctl >/dev/null 2>&1; then INIT=systemd
elif command -v rc-service >/dev/null 2>&1; then INIT=openrc
else echo "systemd or OpenRC is required" >&2; exit 1; fi

if [ "$UNINSTALL" -eq 1 ]; then
  if [ "$INIT" = systemd ]; then
    systemctl disable --now "$NAME" 2>/dev/null || true
    rm -f "/etc/systemd/system/$NAME.service"; systemctl daemon-reload
  else
    rc-service "$NAME" stop 2>/dev/null || true; rc-update del "$NAME" 2>/dev/null || true
    rm -f "/etc/init.d/$NAME"
  fi
  rm -f "$BIN_DIR/$NAME" "$CONFIG" "/usr/local/bin/$NAME"
  if [ -n "$SVC_USER" ]; then
    rm -rf "$BIN_DIR" "$CONFIG_DIR" "$STATE_DIR"
  fi
  if [ -n "$ASSET_DIR" ]; then
    rm -f "$ASSET_DIR/geoip.dat" "$ASSET_DIR/geosite.dat"; rmdir "$ASSET_DIR" 2>/dev/null || true
  fi
  echo "$NAME removed"
  exit 0
fi

[ -n "$PANEL" ] || { echo "--panel is required" >&2; exit 1; }
[ -n "$TOKEN" ] || { echo "--token is required" >&2; exit 1; }
PANEL="${PANEL%/}"
case "$(uname -m)" in
  x86_64|amd64) ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

CLAIM=$(curl -fsS -X POST -H "content-type: application/json" \
  -d "{\"token\":\"$TOKEN\",\"arch\":\"$ARCH\"}" "$PANEL/api/v1/node/proxy/install/claim") \
  || { echo "The install token is invalid or expired; generate a new command in the admin" >&2; exit 1; }
field() { printf '%s' "$CLAIM" | sed -n "s/.*\"$1\":\"\{0,1\}\([^\",}]*\).*/\1/p"; }
API_HOST=$(field api_host); SERVER_ID=$(field server_id); SECRET_KEY=$(field secret_key)
URL=$(field download_url); SUMS=$(field checksums_url)

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
curl -fsSL -o "$TMP/$NAME" "$URL"
curl -fsSL -o "$TMP/SHA256SUMS" "$SUMS"
EXPECTED=$(grep " $(basename "$URL")\$" "$TMP/SHA256SUMS" | cut -d' ' -f1)
ACTUAL=$(sha256sum "$TMP/$NAME" | cut -d' ' -f1)
[ -n "$EXPECTED" ] && [ "$EXPECTED" = "$ACTUAL" ] || { echo "Checksum mismatch, aborting" >&2; exit 1; }

# Geodata for geoip: / geosite: rules. An unverified file is never installed; a failed download
# keeps the current file, and the node reports the missing asset until it is in place.
if [ -n "$ASSET_DIR" ]; then
  mkdir -p "$ASSET_DIR"
  for f in geoip.dat geosite.dat; do
    if curl -fsSL -o "$TMP/$f" "$GEODATA/$f" && curl -fsSL -o "$TMP/$f.sha256sum" "$GEODATA/$f.sha256sum" \
      && [ "$(cut -d' ' -f1 "$TMP/$f.sha256sum")" = "$(sha256sum "$TMP/$f" | cut -d' ' -f1)" ]; then
      install -m 0644 "$TMP/$f" "$ASSET_DIR/$f.new" && mv -f "$ASSET_DIR/$f.new" "$ASSET_DIR/$f"
    else
      echo "Warning: could not download or verify $f; geoip:/geosite: rules need it in $ASSET_DIR" >&2
    fi
  done
fi

if [ -n "$SVC_USER" ] && ! id "$SVC_USER" >/dev/null 2>&1; then
  if command -v useradd >/dev/null 2>&1; then
    useradd --system --user-group --no-create-home --home-dir /nonexistent --shell /usr/sbin/nologin "$SVC_USER"
  else
    addgroup -S "$SVC_USER" && adduser -S -D -H -h /nonexistent -s /sbin/nologin -G "$SVC_USER" "$SVC_USER"
  fi
fi

mkdir -p "$BIN_DIR" "$CONFIG_DIR"
install -m 0755 "$TMP/$NAME" "$BIN_DIR/$NAME"
umask 077
cat > "$CONFIG" <<EOF
Api:
  Provider: openweir
  ApiHost: "$API_HOST"
  ServerID: $SERVER_ID
  SecretKey: "$SECRET_KEY"
  Timeout: 30
EOF
chmod 600 "$CONFIG"
if [ -n "$SVC_USER" ]; then
  # The program rewrites its config on secret rotation and swaps its binary on upgrade
  chown -R "$SVC_USER:$SVC_USER" "$BIN_DIR" "$CONFIG_DIR"
  chmod 700 "$CONFIG_DIR"
  ln -sf "$BIN_DIR/$NAME" "/usr/local/bin/$NAME"
  if [ -n "$STATE_DIR" ]; then
    mkdir -p "$STATE_DIR"; chown "$SVC_USER:$SVC_USER" "$STATE_DIR"; chmod 700 "$STATE_DIR"
  fi
fi

if [ "$INIT" = systemd ]; then
  cat > "/etc/systemd/system/$NAME.service" <<'EOF'
[Unit]
Description=OpenWeir proxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/openweir-proxy server --config /etc/openweir/proxy.yml
Restart=always
RestartSec=5s
LimitNOFILE=65536
NoNewPrivileges=true
ProtectHome=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable "$NAME" >/dev/null
  systemctl restart "$NAME"
else
  if [ -n "$SVC_USER" ]; then
    command -v setcap >/dev/null 2>&1 && setcap cap_net_bind_service=+ep "$BIN_DIR/$NAME" || true
  fi
  cat > "/etc/init.d/$NAME" <<'EOF'
#!/sbin/openrc-run
description="OpenWeir proxy"
command="/usr/local/bin/openweir-proxy"
command_args="server --config /etc/openweir/proxy.yml"
supervisor=supervise-daemon
respawn_delay=5
pidfile="/run/${RC_SVCNAME}.pid"
output_log="/var/log/${RC_SVCNAME}.log"
error_log="/var/log/${RC_SVCNAME}.log"
rc_ulimit="-n 65536"

depend() {
	need net
	after firewall
}

start_pre() {
	checkpath --file --mode 0640 "${output_log}"
}
EOF
  chmod +x "/etc/init.d/$NAME"
  rc-update add "$NAME" default >/dev/null
  rc-service "$NAME" restart
fi

echo "$NAME installed for server $SERVER_ID; it will show as online once it reaches the panel"
