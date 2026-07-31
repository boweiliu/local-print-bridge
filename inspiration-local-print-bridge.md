---
title: Local Print Bridge
description: Print from a Minds mind to the user's own Mac printer over the file-only bridge (proof of concept).
thumbnail: inspiration-local-print-bridge.svg
format: v1
---

# Local Print Bridge

This file is the manifest for the **Local Print Bridge** inspiration (slug:
`local-print-bridge`). It is the one document a future agent reads to understand,
present, and adapt this inspiration. If you are an agent in a mind that was
created from this inspiration, this file is your script: read all of it, then
follow "How to adapt it" below.

## What it is

This inspiration lets a Minds mind print to the user's *own* Mac printer. A
mind normally has no way to run anything on the user's machine -- the only
channel it shares with the Mac is a file-drop folder (the Minds file bridge),
which can copy files back and forth but cannot execute programs. This
inspiration turns that file-only channel into real printing: the user
double-clicks a single setup file once, and from then on they just ask the
mind to print something and a page comes out of their default printer. Behind
the scenes the mind drops the file into a shared folder, a small background
helper on the Mac sends it to the printer and leaves a "printed" receipt, and
the mind reads that receipt back to confirm. The same folder also lets the mind
repair or upgrade the helper remotely, so the user never has to set it up
again. What the user sees is simply: ask to print, and their printer prints --
plus, during setup, a one-time Terminal window that reports "installed and
running."

**This is a proof of concept, and a blunt one about security.** Once installed,
the helper is by design a *persistent way for the mind to run arbitrary code as
the user* on their Mac: it executes an editable script every 15 seconds as the
user's account, and the mind can overwrite that script at any time through the
bridge. Granting the mind "just file access" therefore effectively escalates to
"run anything as me" for as long as the helper is installed. It runs as the
user (not admin) and logs what it does, but anyone adopting this should
understand and accept that trade-off before turning it on.

## How it works

The snapshot includes these paths (each is a repo-root-relative path copied
from the original mind onto a clean default-workspace-template base):

- `.agents/skills/local-print-bridge`

The entire feature is a single skill -- there is no separate app, library,
service, port, or data directory, so nothing is registered in `supervisord.conf`
or `forward_port.py`. `.agents/skills/local-print-bridge/` contains the skill
definition (`SKILL.md`), a user-facing `README.md`, and an `assets/` folder
with the moving parts. The mind itself is the "runtime": following `SKILL.md`,
it uses the `file-sharing` skill to stage the asset files into a folder on the
user's Mac and then drives the bridge by reading and writing files.

The pieces wire together like this:

- **`Set Up Minds Printing.terminal`** is the one thing the user double-clicks.
  The Minds -> Mac bridge is file-only: it refuses to set a Unix executable
  bit, so the mind cannot ship a runnable app or `.command`. A macOS
  `.terminal` file is the one pure-data file whose `CommandString` runs on
  double-click without needing an executable bit, and files written by the
  Minds file server are not Gatekeeper-quarantined, so it is not blocked. Its
  command runs `bootstrap.sh`.
- **`bootstrap.sh`** runs once as the user and is idempotent. It installs the
  durable launcher and logic, then `launchctl bootstrap`s a launchd agent (no
  restart needed).
- **`core.src.sh`** is installed to
  `~/Library/Application Support/MindsPrintBridge/core.sh` as a minimal,
  fixed-in-place launcher. It restores the main logic if the bridge folder was
  wiped, then runs it. It is the only piece that must be correct at install time
  for remote repair to work.
- **`agent.sh`** is the editable source of truth, kept in the bridge folder so
  the mind can rewrite it at any time. A launchd agent
  (`~/Library/LaunchAgents/com.minds.printbridge.plist`, `StartInterval 15` plus
  `WatchPaths`) runs it every 15 seconds. Each tick it rewrites the core, the
  launchd plist, and its own durable backup from itself (so any bug is fixable
  by editing just this one file), publishes the printer list to `printers.txt`,
  runs one-shot commands staged in `cmd/`, and prints any files found in
  `queue/`, writing a `receipts/<name>.txt` (job id + `lpstat -o`) for each.
- **`make_test_page.py`** (uses `reportlab` from the root venv) generates the
  test-page PDF the mind prints to confirm the whole path works;
  **`verify_local.sh`** proves the launcher -> core -> agent handoff offline with
  the macOS commands stubbed.

On the Mac, working state lives under the granted bridge path
(`~/tmp/minds_data/printbridge/` by default) with `queue/ done/ receipts/ cmd/
cmd_done/` subfolders and `printers.txt`; the durable core and backup live under
`~/Library/Application Support/MindsPrintBridge/`. To print, the mind PUTs a
file into `queue/`; to change behavior or fix a bug it overwrites `agent.sh`;
for one-shot admin (cancel stuck jobs, `lpadmin`, `cupsenable`/`cupsdisable`) it
drops a `cmd/<name>.cmd` snippet and reads the output back from
`cmd_done/<name>.cmd.out`.

## Prerequisites

Activation requirements: what the adopting agent must SET UP -- and must
INITIATE ITSELF during setup, before asking how to adapt -- for this
inspiration to run against the new user's own accounts/data. One line per
requirement, in this machine-readable form (greppable by `requires_`):

- requires_permission: file-sharing (write access to the user's bridge folder
  on their Mac, e.g. `~/tmp/minds_data`; granted via the `file-sharing` skill /
  the `minds-file-server-write` scope. User-approved; the adopting agent
  initiates this during setup -- it must not merely mention it.)

This is the *only* activation requirement: there is no external API and no
latchkey connector to a third-party service, so there are no `requires_secret`
values and no other `requires_permission` lines. The file-sharing grant is what
turns the whole thing on.

Additional environment the user's Mac must already have (these are properties of
the target machine, not things the adopting agent provisions):

- macOS with CUPS -- the `lp`, `lpstat`, and `cancel` commands -- and a printer
  reachable from the Mac.
- `reportlab` (available in the root venv) to generate the printable test page.

## How to adapt it

Instructions for the NEXT agent -- the one adapting this inspiration into a
new mind. This is the `use-inspiration` skill's template path; in short:

1. Read this entire file first, especially "Prerequisites" and "Holes"
   below -- Prerequisites are your SETUP agenda, Holes are your ADAPTATION
   agenda.
2. Present the inspiration to the user in plain, non-technical language: what
   it is, what it does, and what it needs from them (name the Prerequisites).
3. Ask whether they want to use the same connectors (e.g. their own Slack).
   If YES: ACTIVATE FIRST -- initiate every `requires_permission` line NOW
   via a latchkey permission request (see the `latchkey` skill; the request
   opens the approval/login flow in the minds app), wire up any
   `requires_secret` values, start the services, and get the app showing
   THE USER'S OWN DATA. Done for a data-backed app means the user can open it
   and see their own data -- NOT that a service starts or an endpoint returns
   200. Then tell them it is live and to take a look.
4. Only AFTER that (or immediately, if they chose different connectors -- the
   swap is then the first adaptation) ask: "How do you want to adapt it?"
5. Work through each hole interactively, one at a time. Translate each into
   plain language, ask for a decision only when you genuinely need one, and
   resolve the obvious ones yourself.
6. When done, append a dated entry to "Adaptation history" below (never
   rewrite earlier entries) and commit.

## Holes

- **macOS only.** The whole design leans on macOS specifics -- a `.terminal`
  file for the double-click, `launchd` for the background agent, and CUPS
  (`lp`/`lpstat`/`cancel`) for printing. It will not run on a Linux or Windows
  machine as-is. A Linux/CUPS variant would be structurally similar (a
  `systemd --user` timer or cron in place of launchd, and a different
  double-click trigger), but that is a rewrite the adapter would have to do.

- **Bridge path is assumed to live under `$HOME`.** All four scripts and the
  `.terminal` hardcode `$HOME/tmp/minds_data`. If the user grants a different
  absolute bridge path, the adapter must rewrite that path in every asset
  (`bootstrap.sh`, `core.src.sh`, `agent.sh`, and `Set Up Minds Printing.terminal`)
  to match.

- **No printer-selection UI.** By default jobs go to the Mac's system default
  printer. Choosing a different printer is possible but manual: PUT a per-job
  `<name>.printer` file next to the queued file, or set a global
  `printbridge/default.printer`. A friendlier "pick a printer" surface (reading
  the published `printers.txt` and offering a choice) does not exist and would
  be a natural adaptation.

- **The `cmd/` maintenance inbox runs arbitrary shell.** Remote admin works by
  dropping a shell snippet into `cmd/` that the agent executes verbatim. That is
  general but wide open; an adapter who wants to reduce the blast radius could
  narrow it to a set of typed, allow-listed helpers (cancel job, set default,
  enable/disable printer) instead of raw shell.

- **Security, by design (not a bug, but the adapter must own it).** As described
  in "What it is," this is deliberately a persistent arbitrary-code-execution
  channel running as the user every 15 seconds, remotely rewritable by the mind.
  There is no sandboxing, capability restriction, or approval-per-command step.
  An adapter taking this beyond proof-of-concept should decide how to constrain
  it (signed/verified `agent.sh`, a fixed command whitelist, an off switch the
  user controls) rather than shipping it as-is to anyone who would not knowingly
  accept "the mind can run anything as me."

## Adaptation history

Each mind that adapts this inspiration appends one dated entry below. Earlier
entries are never rewritten.
