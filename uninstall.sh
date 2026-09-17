#!/bin/zsh
# Removes handy-deck. Leaves Handy itself and your Companion buttons alone.
set -euo pipefail
rm -f  "$HOME/.local/bin/handy-ctl"
rm -rf "$HOME/Applications/Handy Deck"
rm -rf "$HOME/Library/Application Support/handy-deck"
if [[ "${1:-}" == "--purge" ]]; then
  rm -rf "$HOME/.config/handy-deck"
  print "Removed handy-deck (including config)."
else
  print "Removed handy-deck. Config kept at ~/.config/handy-deck (use --purge to delete)."
fi
