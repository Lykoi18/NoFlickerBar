#!/bin/bash
# NoFlickerBar installer: downloads the latest release binary, verifies its checksum,
# and runs it as a per-user LaunchAgent.
#
#   curl -fsSL https://raw.githubusercontent.com/Lykoi18/NoFlickerBar/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/Lykoi18/NoFlickerBar/main/install.sh | bash -s -- --uninstall
set -euo pipefail

REPO="Lykoi18/NoFlickerBar"
VERSION="${NOFLICKERBAR_VERSION:-latest}"
BINDIR="${BINDIR:-$HOME/.local/bin}"
LABEL="io.github.lykoi18.noflickerbar"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"
POLL="${POLL:-0.25}"
DIM_STEP="${DIM_STEP:-2}"

say() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

uninstall() {
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    rm -f "$PLIST" "$BINDIR/noflickerbar"
    say "NoFlickerBar removed"
}

[ "$(uname -s)" = Darwin ] || die "macOS only"
if [ "${1:-}" = "--uninstall" ]; then uninstall; exit 0; fi
[ -z "${1:-}" ] || die "unknown option: $1 (use --uninstall)"

if [ -f "$HOME/Library/LaunchAgents/homebrew.mxcl.noflickerbar.plist" ]; then
    die "NoFlickerBar already runs as a Homebrew service; use 'brew upgrade noflickerbar' instead"
fi

if [ "$VERSION" = latest ]; then
    BASE="https://github.com/$REPO/releases/latest/download"
else
    BASE="https://github.com/$REPO/releases/download/v${VERSION#v}"
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

say "Downloading NoFlickerBar ($VERSION)..."
curl -fsSL "$BASE/noflickerbar" -o "$TMP/noflickerbar"
curl -fsSL "$BASE/noflickerbar.sha256" -o "$TMP/noflickerbar.sha256"
(cd "$TMP" && shasum -a 256 -c noflickerbar.sha256 >/dev/null) || die "checksum mismatch"

mkdir -p "$BINDIR" "$(dirname "$PLIST")"
install -m 755 "$TMP/noflickerbar" "$BINDIR/noflickerbar"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BINDIR/noflickerbar</string>
        <string>$POLL</string>
        <string>$DIM_STEP</string>
    </array>
    <key>LimitLoadToSessionType</key>
    <string>Aqua</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>ThrottleInterval</key>
    <integer>10</integer>
</dict>
</plist>
EOF

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$PLIST"
say "NoFlickerBar $("$BINDIR/noflickerbar" --version) installed and running"
say "Uninstall: curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh | bash -s -- --uninstall"
