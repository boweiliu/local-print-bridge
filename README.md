# Local Print Bridge

> [!WARNING]
> **This lets an AI agent run ARBITRARY CODE on your Mac.** Installing it gives the Minds agent a persistent way to run any code it wants on your computer, as you, for as long as it stays installed — not just printing. Only enable it if you fully trust the agent (and whatever controls it) with that. See the security note below.


<p align="center">
  <img src=".agents/skills/local-print-bridge/assets/hero.svg" alt="A Minds chat sends a file that prints a test page on a local printer" width="600">
</p>

<p align="center">
  <a href="https://boweiliu.github.io/open-in-minds/?git_url=https://github.com/boweiliu/local-print-bridge"><img alt="Open in Minds" src="https://img.shields.io/badge/Open%20in%20Minds-5B4BDB?style=for-the-badge"></a>
</p>

Prefer the raw deep link? Paste `minds://create?git_url=https://github.com/boweiliu/local-print-bridge` into your browser.

Print from a Minds mind to the user's own Mac printer over the file-only bridge (proof of concept).

A Minds mind normally can't run anything on your Mac -- the only thing it
shares with your machine is a file-drop folder. This inspiration turns that
file-only channel into real printing: you double-click one setup file once, and
after that you just ask the mind to print something and a page comes out of your
own default printer. The mind drops the file into a shared folder, a tiny
background helper on your Mac sends it to the printer and leaves a receipt, and
the mind reads that receipt back to confirm -- and can repair or upgrade the
helper remotely, so you never set it up again. **It is a proof of concept, and
a blunt one:** once installed, the helper is by design a persistent way for the
mind to run arbitrary code as you on your Mac, so only turn it on if you'd trust
the mind with that.

This repository is a published **minds inspiration**: a clean, bootable
snapshot of the apps and features a mind built, ready to adapt into your own.
It is NOT the generic workspace template -- it is this specific project.

## Use it

- **Create a new mind from it:** point a new minds workspace at this repo's
  URL. On first boot the mind reads the inspiration and helps you connect your
  own accounts and adapt it.
- **Bring it into an existing mind:** run `/use-inspiration <this repo's URL>`.

## What's inside

- **Local Print Bridge** -- [`inspiration-local-print-bridge.md`](inspiration-local-print-bridge.md) (published now)

Each `inspiration-<slug>.md` is the full manifest for that inspiration: what
it is, how it works, the prerequisites it needs, and how to adapt it.
