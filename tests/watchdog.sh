#!/usr/bin/env bash
set -euo pipefail

root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT
export MC_PROC_ROOT="$root/proc" MC_MEMINFO_PATH="$root/meminfo"
mkdir -p "$MC_PROC_ROOT/123" "$MC_PROC_ROOT/124"
printf 'MemTotal: 1000 kB\nMemAvailable: 50 kB\n' > "$MC_MEMINFO_PATH"
printf 'java\0net.minecraft.client.main.Main\0' > "$MC_PROC_ROOT/123/cmdline"
printf 'java\0com.example.Server\0' > "$MC_PROC_ROOT/124/cmdline"

# Source definitions only; never start the live watchdog in tests.
source "$(dirname "$0")/../kill-minecraft-on-ram.sh"
pgrep() { printf '123\n124\n'; }
[[ $(get_mem_used_pct) == 95 ]]
[[ $(find_mc_pids) == 123 ]]

DRY_RUN=true
[[ $(kill_pids 123) == 'Would signal Minecraft-related PIDs: 123' ]]
[[ -z $(kill_pids) ]]

DRY_RUN=false
log="$root/signals"
logger() { :; }
sleep() { :; }
kill() { printf '%s\n' "$*" >> "$log"; }
kill_pids 123
[[ $(cat "$log") == $'-TERM 123\n-0 123\n-KILL 123' ]]

printf 'watchdog fixtures OK\n'
