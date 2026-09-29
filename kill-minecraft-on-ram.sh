#!/usr/bin/env bash
set -euo pipefail

THRESHOLD=92           # percent
INTERVAL=5             # seconds between checks
DRY_RUN=false
ONCE=false
MEMINFO_PATH=${MC_MEMINFO_PATH:-/proc/meminfo}
PROC_ROOT=${MC_PROC_ROOT:-/proc}
# Match common MC launchers / java invocations. Adjust if needed.
PATTERNS=(
  "minecraft"
  "net.minecraft"
  "org.prismlauncher.PrismLauncher"
  "org.multimc.MultiMC"
)

usage() {
  printf 'Usage: %s [--dry-run] [--once]\n' "${0##*/}"
}

parse_args() {
  for arg in "$@"; do
    case "$arg" in
      --dry-run) DRY_RUN=true ;;
      --once) ONCE=true ;;
      --help) usage; exit 0 ;;
      *) usage >&2; exit 2 ;;
    esac
  done
}

get_mem_used_pct() {
  # Uses /proc/meminfo (more reliable than parsing free output).
  local total available used_pct
  total=$(awk '/^MemTotal:/ {print $2}' "$MEMINFO_PATH")
  available=$(awk '/^MemAvailable:/ {print $2}' "$MEMINFO_PATH")
  if [[ -z "$total" || -z "$available" || "$total" -le 0 ]]; then
    printf 'Invalid memory data: %s\n' "$MEMINFO_PATH" >&2
    return 1
  fi
  # used% = (total-available)/total * 100
  used_pct=$(( ( (total - available) * 100 ) / total ))
  echo "$used_pct"
}

find_mc_pids() {
  # Find java processes whose cmdline contains any pattern above
  local pids=()
  while IFS= read -r pid; do
    local cmd
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    cmd=$(tr '\0' ' ' < "$PROC_ROOT/$pid/cmdline" 2>/dev/null || true)
    [[ -z "$cmd" ]] && continue
    for pat in "${PATTERNS[@]}"; do
      if [[ "$cmd" == *"$pat"* ]]; then
        pids+=("$pid")
        break
      fi
    done
  done < <(pgrep -x java || true)

  if (( ${#pids[@]} )); then printf '%s\n' "${pids[@]}"; fi
}

kill_pids() {
  local pids=("$@")
  [[ ${#pids[@]} -eq 0 ]] && return 0

  if [[ "$DRY_RUN" == true ]]; then
    printf 'Would signal Minecraft-related PIDs: %s\n' "${pids[*]}"
    return 0
  fi

  logger -t kill-minecraft "RAM threshold hit. Killing Minecraft-related PIDs: ${pids[*]}"
  # Try graceful first
  kill -TERM "${pids[@]}" 2>/dev/null || true
  sleep 3
  # If still alive, force
  for pid in "${pids[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
  done
}

main() {
  parse_args "$@"
  while true; do
    used_pct="$(get_mem_used_pct)"
    printf '%s\n' "$used_pct"
    if (( used_pct >= THRESHOLD )); then
      mapfile -t mc_pids < <(find_mc_pids)
      if (( ${#mc_pids[@]} > 0 )); then
        kill_pids "${mc_pids[@]}"
        # After signaling, wait before another check to avoid thrashing.
        if [[ "$ONCE" == false && "$DRY_RUN" == false ]]; then sleep 30; fi
      fi
    fi
    if [[ "$ONCE" == true ]]; then break; fi
    sleep "$INTERVAL"
  done
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
