# Local Print Bridge

> [!WARNING]
> **This lets an AI agent run ARBITRARY CODE on your Mac.** Installing it gives
> the Minds agent a persistent way to run any code it wants on your computer, as
> you, for as long as it stays installed — not just printing. Only enable it if
> you fully trust the agent (and whatever controls it) with that. Proof of
> concept — see [Security](#security).

## Minds can print for you — end to end

![A Minds chat sends a file that prints a test page on a local printer](assets/hero.svg)

Turn on printing for your Minds workspace: ask it to print something and a real
page comes out of your own printer. Setup is a one-time thing — after that you
just ask. (Proof of concept — see **Security**.)

<p align="center">
  <a href="https://boweiliu.github.io/open-in-minds/?git_url=https://github.com/boweiliu/local-print-bridge"><img alt="Open in Minds" src="https://img.shields.io/badge/Open%20in%20Minds-5B4BDB?style=for-the-badge"></a>
</p>

Prefer the raw deep link? Paste `minds://create?git_url=https://github.com/boweiliu/local-print-bridge` into your browser.

## How to use it

1. **Give Minds file access.** Approve the `file-sharing` permission so the mind
   can write to a folder on your Mac (e.g. `~/tmp/minds_data`).
2. **Run the one-time setup.** In Finder, double-click **Set Up Minds Printing**
   — a `.terminal` file the mind places in that folder. It installs a small
   background helper and prints a confirmation. No restart, nothing else to do.
3. **Ask Minds to print.** Send it a file or ask it to print something; it goes
   to your default printer and Minds confirms it printed. You never set this up
   again.

## How it works

Minds can hand files back and forth with your Mac, but it can't press buttons or
run programs there on its own. So the one-time setup drops a small helper onto
your Mac. From then on it works like a shared outbox:

- When you ask Minds to print, it puts the file in a shared folder.
- The helper, which checks that folder every few seconds, sends the file to your
  printer and leaves a "printed" note behind.
- Minds reads that note back to confirm it worked.

The helper also looks after itself — if something breaks, Minds can repair it
through that same shared folder, so you never have to set it up again.

## Security

> [!CAUTION]
> **This is arbitrary code execution, not just printing.** The installed helper
> is a general-purpose way for the agent to run any code on your Mac as you. Treat
> enabling it as "let this agent run anything as me on this computer."

**Proof of concept — read this.** The trade-off is blunt: it lets the mind run
**any code it wants on your Mac, as you, for as long as it's installed.** That
background script runs every 15 seconds as your user, and the mind can overwrite
it at any time. So approving the "just files" access effectively becomes "run
anything as me." Revoking file access later only stops *new* code — the installed
helper keeps running (and self-heals) until you remove it. It runs as you (not
admin) and logs what it does, and you install it knowingly — but only turn it on
if you'd trust the mind with that.

Uninstall:

```sh
launchctl bootout gui/$(id -u)/com.minds.printbridge
rm -f  ~/Library/LaunchAgents/com.minds.printbridge.plist
rm -rf ~/Library/Application\ Support/MindsPrintBridge ~/tmp/minds_data/printbridge
```

then revoke file-sharing in Minds.

---

Setup details for the mind and adaptation notes: see `SKILL.md`. Requires macOS
+ CUPS.
