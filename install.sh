#!/bin/zsh
# Handy Deck installer (macOS). Safe to re-run; config is never overwritten.
set -euo pipefail

HERE="${0:A:h}"
BIN_DIR="$HOME/.local/bin"
CONF_DIR="$HOME/.config/handy-deck"
CONF_FILE="$CONF_DIR/config"
APPS_DIR="$HOME/Applications/Handy Deck"
CTL="$BIN_DIR/handy-ctl"

say() { print -P "%F{cyan}==>%f $*" }
warn() { print -P "%F{yellow}!!%f $*" }

[[ "$(uname)" == Darwin ]] || { print "macOS only."; exit 1 }

# 1. Locate Handy
HANDY_APP=""
for c in /Applications/Handy.app "$HOME/Applications/Handy.app"; do
  [[ -r "$c/Contents/Info.plist" ]] && { HANDY_APP="$c"; break }
done
if [[ -z "$HANDY_APP" ]]; then
  HANDY_APP="$(mdfind 'kMDItemCFBundleIdentifier == "com.pais.handy"' 2>/dev/null | head -n1 || true)"
fi
if [[ -z "$HANDY_APP" || ! -r "$HANDY_APP/Contents/Info.plist" ]]; then
  warn "Handy.app not found. Install it (brew install --cask handy) and re-run."
  exit 1
fi
say "Handy: $HANDY_APP"

# 2. Install controller
mkdir -p "$BIN_DIR"
install -m 0755 "$HERE/bin/handy-ctl" "$CTL"
xattr -d com.apple.quarantine "$CTL" 2>/dev/null || true
say "Installed $CTL"

# 3. Config (first run only)
mkdir -p "$CONF_DIR"
if [[ ! -f "$CONF_FILE" ]]; then
  cat > "$CONF_FILE" <<EOF
# handy-deck config (sourced by handy-ctl)
HANDY_APP="$HANDY_APP"

# Companion HTTP API. Set to "" to disable state push.
COMPANION_URL="http://127.0.0.1:8000"
COMPANION_VAR="handy_state"

# Push-to-talk: taps shorter than this cancel instead of transcribing.
MIN_HOLD_MS=250
EOF
  say "Wrote $CONF_FILE"
else
  say "Kept existing $CONF_FILE"
fi

# 4. Applets for the native Stream Deck "Open" action
mkdir -p "$APPS_DIR"
make_applet() { # <name> <subcommand>
  local app="$APPS_DIR/$1.app" plist
  rm -rf "$app"
  osacompile -o "$app" -e "do shell script quoted form of \"$CTL\" & \" $2\"" >/dev/null
  plist="$app/Contents/Info.plist"
  # Agent app: no Dock icon, no menu bar takeover.
  /usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :LSUIElement true" "$plist"
  # Editing Info.plist breaks the ad-hoc seal; re-sign so Apple Silicon will launch it.
  codesign --force --deep --sign - "$app" >/dev/null 2>&1
  say "Applet: $app"
}
make_applet "Handy Toggle"    toggle
make_applet "Handy AI Toggle" ai
make_applet "Handy Cancel"    cancel

mkdir -p "$APPS_DIR/icons"
cp -R "$HERE/icons/." "$APPS_DIR/icons/"
say "Button icons: $APPS_DIR/icons"

# 5. Health check
print
"$CTL" doctor || true

print
say "Companion 'Run shell command (local)' values:"
print "    Toggle:      $CTL toggle"
print "    AI toggle:   $CTL ai"
print "    PTT press:   $CTL ptt-down"
print "    PTT release: $CTL ptt-up"
print "    Cancel:      $CTL cancel"
