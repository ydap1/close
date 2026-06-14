#!/usr/bin/env bash
# Installs or uninstalls the 'close' command.

set -euo pipefail

SCRIPT_NAME="close"
SOURCE="./close.sh"
UNINSTALL=0

# Detect the right bin directory (Homebrew prefix or /usr/local/bin)
if command -v brew >/dev/null 2>&1; then
  BREW_BIN="$(brew --prefix)/bin"
else
  BREW_BIN=""
fi

if [[ -n "$BREW_BIN" && -d "$BREW_BIN" && ":$PATH:" == *":$BREW_BIN:"* ]]; then
  TARGET_DIR="$BREW_BIN"
else
  TARGET_DIR="/usr/local/bin"
fi
TARGET_PATH="$TARGET_DIR/$SCRIPT_NAME"

usage() {
  cat <<-EOF
Usage: $(basename "$0") [--uninstall] [--dir PATH]

  --uninstall     Remove 'close' from PATH instead of installing.
  --dir PATH      Install to PATH instead of the auto-detected directory ($TARGET_DIR).
  -h, --help      Show this help text.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --uninstall|-u) UNINSTALL=1; shift ;;
    --dir)
      [[ $# -lt 2 ]] && { echo "error: --dir requires a PATH argument" >&2; exit 2; }
      TARGET_DIR="$2"; TARGET_PATH="$TARGET_DIR/$SCRIPT_NAME"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

# Re-run with sudo if we don't have write access to the target dir
if [[ ! -w "$TARGET_DIR" ]]; then
  echo "Write access to $TARGET_DIR requires sudo — re-running with sudo..."
  exec sudo "$0" "$@"
fi

if [[ $UNINSTALL -eq 1 ]]; then
  if [[ -f "$TARGET_PATH" ]]; then
    rm "$TARGET_PATH"
    echo "Uninstalled: removed $TARGET_PATH"
  else
    echo "Nothing to uninstall — $TARGET_PATH not found."
  fi
  exit 0
fi

[[ -f "$SOURCE" ]] || {
  echo "error: $SOURCE not found. Run this script from the same directory as close.sh." >&2
  exit 1
}

cp "$SOURCE" "$TARGET_PATH"
chmod +x "$TARGET_PATH"

echo "Installed '$SCRIPT_NAME' → $TARGET_PATH"
echo ""
echo "Quick reference:"
echo "  close           quit all visible GUI apps"
echo "  close -n        dry run (show what would be closed)"
echo "  close -f        force-kill apps that don't quit cleanly"
echo "  close -F        immediate SIGKILL (no graceful shutdown)"
echo "  close -b        skip browsers"
echo "  close -e Slack  skip a specific app"
echo "  close -t 5      wait 5 seconds before checking for stragglers"
echo "  close -h        full help"
