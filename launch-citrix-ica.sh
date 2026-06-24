#!/bin/zsh

# Citrix ICA Auto Launcher for macOS
# Watches ~/Downloads via a LaunchAgent and launches downloaded .ica files
# with Citrix Workspace.app, then deletes the .ica after handoff.

set -u
setopt NULL_GLOB

DOWNLOADS="$HOME/Downloads"
LOGDIR="$HOME/Library/Logs"
LOGFILE="$LOGDIR/citrix-ica-launcher.log"
LOCKDIR="/tmp/citrix-ica-launcher.lockdir"
STATE_DIR="/tmp/citrix-ica-launcher-state"

CITRIX_APP="/Applications/Citrix Workspace.app"

mkdir -p "$LOGDIR" "$STATE_DIR"

log() {
  print -- "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOGFILE"
}

cleanup_lock() {
  rmdir "$LOCKDIR" 2>/dev/null || true
}

make_key() {
  local file="$1"
  stat -f "%N:%z:%m" "$file" 2>/dev/null | /sbin/md5 -q
}

is_stable() {
  local file="$1"
  local s1
  local s2

  [[ -f "$file" ]] || return 1

  s1=$(stat -f "%z" "$file" 2>/dev/null || echo -1)
  sleep 1
  s2=$(stat -f "%z" "$file" 2>/dev/null || echo -1)

  [[ "$s1" -gt 0 && "$s1" -eq "$s2" ]]
}

launch_ica() {
  local file="$1"
  local key
  local marker
  local rc

  key=$(make_key "$file")
  marker="$STATE_DIR/$key"

  if [[ -e "$marker" ]]; then
    log "Already handled this ICA version; skipping: $file"
    return 0
  fi

  touch "$marker"

  log "Launching ICA via Citrix Workspace.app: $file"

  /usr/bin/open -g -a "$CITRIX_APP" "$file" \
    >>/tmp/citrix-ica-open.out \
    2>>/tmp/citrix-ica-open.err

  rc=$?
  log "open returned rc=$rc for $file"

  if [[ "$rc" -ne 0 ]]; then
    log "Open failed; leaving ICA in place and clearing marker: $file"
    rm -f "$marker"
    return 1
  fi

  # Give Citrix time to ingest the ICA file.
  sleep 15

  if [[ -f "$file" ]]; then
    log "Deleting ICA after handoff: $file"
    rm -f "$file"
  else
    log "ICA already gone: $file"
  fi

  rm -f "$marker"
}

main() {
  log "SCRIPT STARTED user=$(whoami) uid=$(id -u) HOME=$HOME DOWNLOADS=$DOWNLOADS PWD=$(pwd)"

  if ! mkdir "$LOCKDIR" 2>/dev/null; then
    log "Lock exists; another run is active. Exiting."
    exit 0
  fi
  trap cleanup_lock EXIT INT TERM

  # WatchPaths can fire before the browser has finished renaming/writing.
  sleep 2

  if [[ ! -d "$DOWNLOADS" ]]; then
    log "ERROR: Downloads folder does not exist or is inaccessible: $DOWNLOADS"
    exit 1
  fi

  local files
  files=("$DOWNLOADS"/*.ica)

  log "Found ${#files[@]} ICA file(s)"

  for file in "${files[@]}"; do
    [[ -f "$file" ]] || continue

    log "Candidate: $file"

    if is_stable "$file"; then
      launch_ica "$file"
    else
      log "Skipping unstable or empty ICA: $file"
    fi
  done
}

main "$@"
