# Handoff: Screens + BetterDisplay Remote Display

This repo started as a small manual `displayplacer` layout switcher for
Screens/VNC workflows. The basic `displayplacer` approach works for normal
layout switching, but the attempted BetterDisplay virtual-display workflow is
not yet reliable enough to ship as the default behavior.

## Current Conclusion

Do not hot-plug the BetterDisplay virtual display from the Raycast command.

The most promising next direction is:

1. Keep one BetterDisplay virtual display named `ScreensRemote` connected.
2. Use `displayplacer` to switch between local and remote layouts.
3. Do not have `Display Restore` disable or discard `ScreensRemote`.

In short:

```txt
BetterDisplay: owns the persistent virtual screen.
displayplacer: owns mirroring, main display, resolution, and arrangement.
Raycast/Keyboard Maestro: only launch the scripts.
```

## Why

Astropad Workbench behaves well because it owns the entire remote-display
lifecycle. When Workbench is connected, macOS sees an `Astropad Display` virtual
display. Workbench makes that virtual display the main/mirror-master display and
mirrors the Studio Display to it.

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

The Screens + BetterDisplay approach was trying to imitate that from outside
Screens. The unreliable part was asking BetterDisplay to connect/create the
virtual display after Screens was already connected.

## What Failed

The following path was unreliable:

```txt
Display Remote:
  connect/create BetterDisplay virtual display
  wait for macOS/displayplacer to see it
  mirror ScreensRemote + Studio Display

Display Restore:
  restore Studio Display
  disable ScreensRemote
```

Failure modes observed:

- `betterdisplaycli set --connected=on` returned `Failed`.
- BetterDisplay URL commands sometimes connected the virtual display, sometimes
  only changed BetterDisplay internal state.
- BetterDisplay accumulated disconnected duplicate `ScreensRemote` records.
- BetterDisplay virtual display UUIDs changed across reconnects.
- `displayplacer` could only apply the mirror layout after macOS actually
  exposed the virtual display.
- Raycast failed on reconnect because `ScreensRemote` was not visible to
  `displayplacer`.

This means the hot-plug lifecycle is the brittle part. `displayplacer` itself
was reliable once the displays were present.

## Recommended Layout Model

Create and keep exactly one BetterDisplay virtual screen:

```txt
Name: ScreensRemote
Serial: 313775617
Vendor: 2198
Model: 10498
Useful resolution: 1920x1080
```

Use serial IDs in layout files rather than BetterDisplay UUIDs:

```txt
ScreensRemote: s313775617
Studio Display: s1879776955
```

Recommended remote layout:

```sh
displayplacer "id:s313775617+s1879776955 res:1920x1080 hz:60 color_depth:4 enabled:true scaling:on origin:(0,0) degree:0"
```

This makes `ScreensRemote` the first display in the mirror group, which makes it
the mirror master / optimized display.

Recommended local layout should restore Studio Display without disabling
`ScreensRemote`. A likely starting point is:

```sh
displayplacer "id:s1879776955 res:3200x1800 hz:60 color_depth:8 enabled:true scaling:on origin:(0,0) degree:0" "id:s313775617 res:1920x1080 hz:60 color_depth:4 enabled:true scaling:on origin:(-1920,0) degree:0"
```

That keeps the virtual display available for the next remote switch. It may mean
Screens shows more than one display choice, but it avoids the unreliable
BetterDisplay connect/create step.

## Current Branch Caveat

At this handoff, the branch contains experimental script changes from the failed
BetterDisplay hot-plug approach:

```txt
scripts/display-remote.sh
scripts/display-restore.sh
```

Those changes should not be treated as the final design. The next pass should
either revert them or replace them with the always-connected model above.

Ignored local layout files were also edited during testing:

```txt
layouts/remote.displayplacer
layouts/local.displayplacer
```

They are intentionally ignored by Git because each machine needs its own
display IDs and preferred resolutions.

## Useful Inventory Commands

Use these before and after each experiment:

```sh
betterdisplaycli get -identifiers
displayplacer list
system_profiler SPDisplaysDataType
```

When cleaning up, only remove BetterDisplay virtual displays named
`ScreensRemote`. Do not touch `Astropad`, `Workbench`, `Luna`, or the physical
Studio Display.

## Suggested Next Steps

1. Clean BetterDisplay so there is exactly one `ScreensRemote` virtual display.
2. Leave `ScreensRemote` connected.
3. Recapture or hand-edit `layouts/remote.displayplacer` using the remote mirror
   layout above.
4. Recapture or hand-edit `layouts/local.displayplacer` so it restores Studio
   Display without disabling `ScreensRemote`.
5. Remove the experimental BetterDisplay connect/create logic from
   `scripts/display-remote.sh`.
6. Remove the experimental "missing disabled display means success" behavior
   from `scripts/display-restore.sh` if restore no longer disables the virtual
   display.
7. Test the full workflow:

```txt
Display Restore
disconnect Screens
connect Screens
Display Remote
disconnect Screens
Display Restore
connect Screens again
Display Remote
```

The expected outcome is that `Display Remote` never needs to ask BetterDisplay
to create or connect a virtual display during an active Screens session.
