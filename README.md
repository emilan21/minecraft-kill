# Minecraft RAM watchdog

`kill-minecraft-on-ram.sh` checks `/proc/meminfo` every five seconds. When
used RAM reaches 92%, it finds processes whose executable name is `java` and
whose command line contains `minecraft`, `net.minecraft`, a PrismLauncher
class, or a MultiMC class. It sends TERM, waits three seconds, then sends
KILL to any matched PID still alive. This is a command-line heuristic; review
the process list before installing the service.

Run `bash kill-minecraft-on-ram.sh --once --dry-run` to see a single live
memory check and any PIDs it would signal. `--dry-run` never calls `kill` or
`logger`; without `--once` it continues watching. `--help` prints usage.

The optional `MC_MEMINFO_PATH` and `MC_PROC_ROOT` environment variables let
the fixture test use fake `/proc` data. Run `bash tests/watchdog.sh`,
`bash -n kill-minecraft-on-ram.sh`, and `shellcheck kill-minecraft-on-ram.sh`
before installing. Tests stub `pgrep`, `kill`, `logger`, and `sleep`, so no
real process is signaled.

The tracked service file describes a possible systemd install. Installing or
enabling it changes system behavior and is a separate operator action; no
repository check does that. `THRESHOLD` and `INTERVAL` are constants near the
top of the script.
