---
name: local-print-bridge
description: Set up printing from this mind to the user's local/network printer on a Mac, over the file-only Minds bridge. Use when the user wants the mind to print to their own printer, or to run remote print maintenance (clear stuck jobs, change default printer). macOS only.
---

# Local print bridge (macOS)

Lets this mind print to the user's own printer and run print maintenance, using
nothing but WebDAV **file** access to the user's Mac (the `file-sharing` skill).
After a single one-time double-click by the user, the mind drops a file into a
watched folder and it prints; the mind reads a receipt back to confirm. The
service self-heals and is remotely fixable, so the user never installs again.

## Security / status (proof of concept)

This is a **POC**. Once installed it is, by design, a persistent way for the
mind to run **arbitrary code as the user** on their Mac: `agent.sh` runs every
15s as the user and the mind can overwrite it via the bridge (the `cmd/` inbox
makes this explicit). Granting the file bridge is thus escalated to "run
anything as me" for as long as it is installed; revoking file-sharing only
stops *new* code being staged, not the running agent. Tell the user this before
setting it up. Full uninstall + how to reduce the surface are in `README.md`.

## Why it is built this way (the hard constraint)

The Minds -> Mac bridge is **file-only**: no command execution, no network
proxy, and it will **not** set a Unix executable bit. So the mind cannot run
`lp` itself, and cannot ship a double-click app/`.command` (those need `+x`).
The one mechanism that triggers execution from a pure data file is a macOS
**`.terminal`** file whose `CommandString` runs on double-click. Files written
by the Minds file server are not quarantined, so Gatekeeper does not block it.
That double-click is the single user action.

## Architecture (assets/)

- `Set Up Minds Printing.terminal` -- the double-click. Its `CommandString`
  runs `/bin/sh "$HOME/tmp/minds_data/printbridge/bootstrap.sh"`.
- `bootstrap.sh` -- runs once as the user; installs the durable core, launcher,
  and logic, then `launchctl bootstrap`s the agent (no restart). Idempotent.
- `core.src.sh` -- a minimal, fixed-in-place launcher installed to
  `~/Library/Application Support/MindsPrintBridge/core.sh`. Restores the logic
  if the bridge folder was wiped, then runs it. This is the ONLY piece that
  must be correct at install for remote-repair to be possible.
- `agent.sh` -- the editable source of truth, living in the bridge folder so
  the mind can rewrite it anytime. Each 15s tick it rewrites the core, the
  launchd plist, and its own durable backup from itself (so any bug elsewhere
  is fixable by editing THIS file), publishes `printers.txt`, runs one-shot
  commands from `cmd/`, and prints files from `queue/`.
- `make_test_page.py` -- generates the test-page PDF (needs reportlab; in the
  root venv). `verify_local.sh` -- offline proof of the whole thing with the
  macOS commands stubbed (run `sh verify_local.sh`).

Layout on the Mac: launcher `~/Library/LaunchAgents/com.minds.printbridge.plist`
(StartInterval 15 + WatchPaths); durable core + backup under
`~/Library/Application Support/MindsPrintBridge/`; working dir under the granted
bridge path `~/tmp/minds_data/printbridge/` with `queue/ done/ receipts/ cmd/
cmd_done/` and `printers.txt`.

## Setup procedure

1. **Get file access.** Via the `file-sharing` skill, request WRITE to the
   bridge folder (default `~/tmp/minds_data`). These assets assume the granted
   path is under `$HOME`; if the user grants a different absolute path, rewrite
   `$HOME/tmp/minds_data` in all four scripts + the `.terminal` accordingly.
2. **Stage files** into `<bridge>/printbridge/`: `core.src.sh`, `agent.sh`,
   `bootstrap.sh`; and `Set Up Minds Printing.terminal` at the bridge root.
   Upload with `latchkey curl -T`; verify each readback is byte-identical.
3. **Make the test page** (`uv run python make_test_page.py /tmp/test.pdf`) and
   keep it for step 6.
4. **Hand the user ONE action:** in Finder, `Cmd+Shift+G` -> the bridge folder
   -> double-click `Set Up Minds Printing`. It installs and prints an
   "installed and running" banner; the Terminal window can be closed.
5. **Confirm install:** poll for `printbridge/install-receipt.txt`
   (`agent_status: loaded`) and read `printbridge/printers.txt` for the printer
   list + system default.
6. **Print:** PUT a file into `printbridge/queue/`; the agent prints it within
   15s and writes `printbridge/receipts/<name>.txt` (job id + `lpstat -o`).
   Optional per-job printer: PUT `<name>.printer` next to it, or set a global
   `printbridge/default.printer`.

## Remote maintenance / fixes (no reinstall)

- **Change behavior / fix a bug:** overwrite `printbridge/agent.sh` via the
  bridge; the next tick adopts it and rewrites the durable copies.
- **One-shot admin** (cancel stuck jobs, `lpadmin`, `cupsenable`/`cupsdisable`,
  `cupsenable`): PUT a `printbridge/cmd/<name>.cmd` shell snippet; the agent
  runs it once and writes output to `printbridge/cmd_done/<name>.cmd.out`.

## Limits (be honest with the user)

- macOS only (CUPS). The printer must be reachable from the Mac; the mind can
  clear stuck jobs but cannot bring an offline printer online.
- The one irreducible reinstall case: the initial launcher->core->agent handoff
  being broken at install, or someone deleting the `~/Library` copy. Verify the
  launcher parses and the handoff runs (`verify_local.sh`) before shipping.
