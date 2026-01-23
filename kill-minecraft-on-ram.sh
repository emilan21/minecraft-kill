#!/usr/bin/env bash
set -euo pipefail

THRESHOLD=92           # percent
INTERVAL=5             # seconds between checks
# Match common MC launchers / java invocations. Adjust if needed.
PATTERNS=(
  "minecraft"
  "net.minecraft"
  "org.prismlauncher.PrismLauncher"
  "org.multimc.MultiMC"
  "org.lwjgl"
)

get_mem_used_pct() {
  # Uses /proc/meminfo (more reliable than parsing free output).
  local total available used_pct
  total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
  available=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
  # used% = (total-available)/total * 100
  used_pct=$(( ( (total - available) * 100 ) / total ))
  echo "$used_pct"
}

find_mc_pids() {
  # Find java processes whose cmdline contains any pattern above
  local pids=()
  while IFS= read -r pid; do
    local cmd
    cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)
    [[ -z "$cmd" ]] && continue
    for pat in "${PATTERNS[@]}"; do
      if [[ "$cmd" == *"$pat"* ]]; then
        pids+=("$pid")
        break
      fi
    done
  done < <(pgrep -x java || true)

  printf "%s\n" "${pids[@]:-}"
}

kill_pids() {
  local pids=("$@")
  [[ ${#pids[@]} -eq 0 ]] && return 0

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

while true; do
  used_pct="$(get_mem_used_pct)"
  echo $used_pct
  if (( used_pct >= THRESHOLD )); then
    mapfile -t mc_pids < <(find_mc_pids || true)
    if (( ${#mc_pids[@]} > 0 )); then
      kill_pids "${mc_pids[@]}"
      # After killing, wait a bit to avoid thrashing if memory stays high
      sleep 30
    fi
  fi
  sleep "$INTERVAL"
done
