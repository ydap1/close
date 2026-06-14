#!/usr/bin/env bash
# close — quit or kill all visible GUI apps on macOS

set -euo pipefail

VERSION="2.0.0"
SCRIPT_NAME="$(basename "$0")"

DRY_RUN=0
FORCE=0
IMMEDIATE=0
NO_BROWSER=0
QUIET=0
TIMEOUT=2
EXTRA_EXCLUDES=()

# Colors — disabled when stdout is not a TTY or NO_COLOR is set
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; YELLOW=''; GREEN=''; CYAN=''; BOLD=''; RESET=''
fi

log()  { [[ $QUIET -eq 0 ]] && printf '%s\n' "$*" || true; }
info() { [[ $QUIET -eq 0 ]] && printf "${CYAN}→${RESET} %s\n" "$*" || true; }
ok()   { [[ $QUIET -eq 0 ]] && printf "${GREEN}✓${RESET} %s\n" "$*" || true; }
die()  { printf "${RED}error:${RESET} %s\n" "$*" >&2; exit 1; }

show_help() {
  cat <<-EOF
${BOLD}Usage:${RESET} $SCRIPT_NAME [options]

${BOLD}Options:${RESET}
  -n, --dry-run              Show which GUI apps would be targeted; do not quit/kill.
  -f, --force                Ask apps to quit, then force-kill any that remain.
  -F, --immediate            Immediately SIGKILL all targeted apps (no graceful quit).
  -b, --no-browser           Exclude common web browsers.
  -e NAME, --exclude NAME    Exclude an additional app by name (repeatable).
  -t SECS, --timeout SECS    Seconds to wait for graceful quit before checking [default: $TIMEOUT].
  -q, --quiet                Suppress non-error output.
  -v, --version              Print version and exit.
  -h, --help                 Show this help text and exit.

${BOLD}Short flags can be chained:${RESET}
  $SCRIPT_NAME -fb    force-quit, keep browsers open
  $SCRIPT_NAME -nF    dry-run in immediate-kill mode
  Note: -e and -t take an argument and must be last in a chain, e.g. -be Safari
EOF
}

# ---- Expand grouped short flags (e.g. -fb → -f -b) ----
RAW_ARGS=("$@")
PARSED_ARGS=()
for arg in "${RAW_ARGS[@]+"${RAW_ARGS[@]}"}"; do
  if [[ "$arg" == "--" || "$arg" == --* ]]; then
    PARSED_ARGS+=("$arg")
  elif [[ "$arg" == -[!-]* && ${#arg} -gt 2 ]]; then
    letters="${arg#-}"
    for ((i=0; i<${#letters}; i++)); do
      PARSED_ARGS+=("-${letters:$i:1}")
    done
  else
    PARSED_ARGS+=("$arg")
  fi
done

if [[ ${#PARSED_ARGS[@]} -gt 0 ]]; then
  set -- "${PARSED_ARGS[@]}"
else
  set --
fi

# ---- Parse flags ----
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)    DRY_RUN=1; shift ;;
    -f|--force)      FORCE=1; shift ;;
    -F|--immediate)  IMMEDIATE=1; FORCE=1; shift ;;
    -b|--no-browser) NO_BROWSER=1; shift ;;
    -e|--exclude)
      [[ $# -lt 2 ]] && die "--exclude requires a NAME argument"
      EXTRA_EXCLUDES+=("$2"); shift 2 ;;
    -t|--timeout)
      [[ $# -lt 2 ]] && die "--timeout requires a SECS argument"
      [[ "$2" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "--timeout value must be a number"
      TIMEOUT="$2"; shift 2 ;;
    -q|--quiet)      QUIET=1; shift ;;
    -v|--version)    echo "$SCRIPT_NAME $VERSION"; exit 0 ;;
    -h|--help)       show_help; exit 0 ;;
    --)              shift; break ;;
    -*)              die "Unknown option: $1 (try --help)" ;;
    *)               break ;;
  esac
done

[[ "$(uname -s)" == "Darwin" ]] || die "This script is for macOS only."

# ---- Build exclusion list ----
EXCLUDE_PROGS=(
  "Terminal" "iTerm2" "iTerm" "Hyper" "Alacritty" "kitty" "WezTerm"
  "tmux" "Screen" "ssh"
)

if [[ $NO_BROWSER -eq 1 ]]; then
  EXCLUDE_PROGS+=(
    "Safari" "Safari Technology Preview"
    "Google Chrome" "Google Chrome Canary"
    "Firefox" "Firefox Developer Edition" "Firefox Nightly"
    "Brave Browser" "Microsoft Edge" "Chromium"
    "Opera" "Vivaldi" "Tor Browser" "Arc"
  )
fi

EXCLUDE_PROGS+=("${EXTRA_EXCLUDES[@]+"${EXTRA_EXCLUDES[@]}"}")

# ---- Collect visible GUI apps ----
_trim() {
  local s="$*"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

raw=$(osascript -e 'tell application "System Events" to get name of (application processes whose background only is false)') || raw=""
IFS=',' read -ra RAW_APPS <<< "$raw"

TO_QUIT=()
for raw_app in "${RAW_APPS[@]+"${RAW_APPS[@]}"}"; do
  app="$(_trim "$raw_app")"
  [[ -z "$app" ]] && continue
  skip=0
  for ex in "${EXCLUDE_PROGS[@]}"; do
    [[ "$app" == "$ex" ]] && skip=1 && break
  done
  [[ $skip -eq 1 ]] && continue
  TO_QUIT+=("$app")
done

if [[ ${#TO_QUIT[@]} -eq 0 ]]; then
  log "No GUI apps to quit (after exclusions)."
  exit 0
fi

log "${BOLD}Targeted apps (${#TO_QUIT[@]}):${RESET}"
for a in "${TO_QUIT[@]}"; do
  log "  ${CYAN}·${RESET} $a"
done
log ""

if [[ $DRY_RUN -eq 1 ]]; then
  log "Dry run — nothing was closed."
  exit 0
fi

# ---- Immediate mode: SIGKILL everything ----
if [[ $IMMEDIATE -eq 1 ]]; then
  info "Sending SIGKILL to ${#TO_QUIT[@]} app(s)..."
  for app in "${TO_QUIT[@]}"; do
    if [[ "$app" == "Finder" ]]; then
      # Finder always restarts after SIGKILL; a graceful quit is cleaner
      osascript -e 'tell application "Finder" to quit' >/dev/null 2>&1 || true
    else
      killall -9 "$app" >/dev/null 2>&1 || true
    fi
  done
  ok "Done."
  exit 0
fi

# ---- Graceful quit: send all requests, then wait once ----
info "Requesting quit from ${#TO_QUIT[@]} app(s)..."
for app in "${TO_QUIT[@]}"; do
  osascript -e "tell application \"$app\" to quit" >/dev/null 2>&1 || true
done

sleep "$TIMEOUT"

# ---- Check what's still running ----
STILL_RUNNING=()
for app in "${TO_QUIT[@]}"; do
  pgrep -x "$app" >/dev/null 2>&1 && STILL_RUNNING+=("$app") || true
done

if [[ ${#STILL_RUNNING[@]} -eq 0 ]]; then
  ok "All apps quit successfully."
  exit 0
fi

log "Apps still running after ${TIMEOUT}s:"
for a in "${STILL_RUNNING[@]}"; do
  log "  ${YELLOW}·${RESET} $a"
done
log ""

if [[ $FORCE -eq 1 ]]; then
  info "Force-killing ${#STILL_RUNNING[@]} remaining app(s)..."
  for app in "${STILL_RUNNING[@]}"; do
    killall -9 "$app" >/dev/null 2>&1 || true
  done
  ok "Force-kill complete."
else
  log "Run with ${BOLD}-f${RESET} / ${BOLD}--force${RESET} to force-kill remaining apps."
fi
