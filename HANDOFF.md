# Handoff: Screens + BetterDisplay Remote Display

> **Status (1.0):** the workflow described in [README.md](README.md) is
> working end-to-end. This file is preserved as design history — the
> failure modes documented below are what motivated the current
> defensive-discard-then-create approach in `scripts/display-remote.sh`,
> and the off-screen-park (rather than `enabled:false`) approach in
> `layouts/local.displayplacer`. If you're integrating these scripts, read
> the README first; this file explains *why* certain choices look the way
> they do.

## Working architecture (current)

`D Remote` (run before connecting Screens):

1. Discard any existing BetterDisplay virtual screen matching the layout's
   `--virtualScreenName` (defensive — prevents stale duplicates from
   accumulating across sessions). Loops until `discard` reports nothing
   left to discard.
2. `betterdisplaycli create` a fresh virtual screen using the
   `# betterdisplay-create:` directive's flags. Pin the resolution list with
   `--resolutionList=<WxH> --useResolutionList=on` so the new virtual
   defaults to the intended remote resolution rather than BetterDisplay's
   multiplier-generated ladder.
3. `betterdisplaycli perform --connectAllDisplays`, plus URL-scheme
   `BetterDisplay://set?tagID=<id>&connected=on` per missing serial
   (the CLI form `set --connected=on` is unreliable; URL scheme is
   currently the working path).
4. `displayplacer apply` the mirror layout, with the virtual display first
   in the mirror group so it becomes the master.

`D Restore` (run after disconnecting Screens):

1. `displayplacer apply` the local layout, which **keeps the virtual
   display enabled** but moves it to `origin:(-10000,0)` — far off-screen
   but still tracked by macOS and BetterDisplay.

The next `D Remote` run starts with discard-and-create, so leftover state
from the prior run is cleaned up before any layout work.

## Why this shape, and not other things we tried

Astropad Workbench behaves well because it owns the entire remote-display
lifecycle. When Workbench is connected, macOS sees an `Astropad Display`
virtual display. Workbench makes that virtual display the main /
mirror-master and mirrors the physical display to it.

Observed Workbench shape:

```txt
Astropad Display
  Main Display: Yes
  Mirror: On
  Mirror Status: Master Mirror

Studio Display
  Mirror: On
  Mirror Status: Hardware Mirror
```

Screens.app uses plain VNC; it has no equivalent connect handshake. So the
host has to have the right display configuration *already in place* before
Screens connects, every time. We replicate Workbench's shape using a
BetterDisplay virtual display, but the lifecycle is bound to the
`D Remote` / `D Restore` script invocations rather than to the Screens
session.

## What didn't work (and why those approaches were abandoned)

### Disabling ScreensRemote on `D Restore`

The earliest design used `id:s313775617 enabled:false` in the local
layout. Restore would disable the virtual; the next Remote would have to
reconnect or recreate it. This failed in practice:

- `betterdisplaycli set --connected=on` returned `Failed.` — the CLI's
  `--connected=on` path is unreliable.
- BetterDisplay URL commands sometimes connected the virtual display,
  sometimes only changed BetterDisplay internal state without making it
  visible to macOS.
- BetterDisplay accumulated disconnected duplicate `ScreensRemote`
  records across cycles.
- Virtual display UUIDs changed across reconnects, so any saved UUID
  became stale.
- `displayplacer apply` could only succeed after macOS exposed the
  virtual display, which the unreliable reconnect step couldn't
  guarantee.

The root insight: the disconnect path is reliable, the reconnect path is
not. Stop disconnecting and there's nothing to reconnect.

### Hot-plugging from inside an active Screens session

`D Remote` runs *before* the Screens connection, not during. macOS curtain
mode (a Screens privacy feature that blanks the host's local display)
suppresses display reconfiguration commands while engaged — they queue and
apply when curtain mode disengages. Engage curtain mode after running
`D Remote`, not before.

### Always-connected ScreensRemote with no discard/create

We considered creating ScreensRemote once at setup and leaving it
connected forever, with the scripts only toggling main/mirror/placement.
The reliability story for "stays connected forever despite VNC sessions
and BetterDisplay state changes" is uncertain. The current
discard-and-create-on-Remote model gives a known-clean state for every
Screens session, at the cost of one extra discard+create per Remote run
(takes a couple of seconds).

## Inventory commands

Before and after experiments, these are useful:

```sh
betterdisplaycli get -identifiers
displayplacer list
system_profiler SPDisplaysDataType
```

When cleaning up by hand, only remove BetterDisplay virtual displays
matching the layout's `--virtualScreenName`. Do not touch unrelated
virtual displays installed by other apps (Astropad, Workbench, Luna,
etc.) or any physical displays.
