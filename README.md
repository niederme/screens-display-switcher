# screens-display-switcher

Manual macOS display layout and resolution switching for
[Screens](https://www.edovia.com/en/screens/)/VNC workflows, with optional
launchers for Raycast, Keyboard Maestro, and any other tool that can run a
shell script.

![Display Remote command in Raycast](assets/raycast-display-remote.png)

*Example: launching the remote display layout from Raycast.*

The default setup is:

- `Display Remote`: remote-friendly layout for Screens.app.
- `Display Restore`: normal local display layout.

This utility deliberately does not try to detect VNC or Screens.app connection
state. The reliable workflow is explicit:

1. Run `Display Remote`, or run `scripts/display-remote.sh`.
2. Connect with Screens.app.
3. Run `Display Restore`, or run `scripts/display-restore.sh`, when done.

The scripts use [`displayplacer`](https://github.com/jakehilborn/displayplacer)
under the hood. Install it with Homebrew:

```sh
brew install displayplacer
```

## Setup

From this directory:

```sh
./scripts/install.sh
```

Set your display to its normal local layout, then capture it:

```sh
./scripts/capture-layout.sh local
```

Set your display to the layout you want for Screens remote access, then capture
it:

```sh
./scripts/capture-layout.sh remote
```

This creates:

```txt
layouts/local.displayplacer
layouts/remote.displayplacer
```

## Use

Before connecting remotely, run the remote layout:

```txt
Display Remote
```

Or from the shell:

```sh
./scripts/display-remote.sh
```

After disconnecting and returning to the Mac locally, restore the local layout:

```txt
Display Restore
```

```sh
./scripts/display-restore.sh
```

## Raycast

This repo includes Raycast Script Commands in `raycast/`:

```txt
raycast/
  raycast-display-remote.sh
  raycast-display-restore.sh
```

To use them:

1. Open Raycast Preferences.
2. Go to Extensions -> Script Commands.
3. Add this folder as a script directory:

```txt
/path/to/screens-display-switcher/raycast
```

4. Search Raycast for:

```txt
Display Remote
Display Restore
```

You can assign hotkeys to either command from Raycast Preferences.

The Raycast commands are thin wrappers around `scripts/display-remote.sh` and
`scripts/display-restore.sh`, so capture and edit layouts in the same place.

## Keyboard Maestro

Keyboard Maestro can run the same shell scripts directly.

Create a macro for the remote layout:

```txt
Macro: Display Remote
Trigger: your preferred hotkey, menu item, Stream Deck button, or typed string
Action: Execute Shell Script
Script: /path/to/screens-display-switcher/scripts/display-remote.sh
```

Create a second macro for restoring the local layout:

```txt
Macro: Display Restore
Trigger: your preferred hotkey, menu item, Stream Deck button, or typed string
Action: Execute Shell Script
Script: /path/to/screens-display-switcher/scripts/display-restore.sh
```

Replace `/path/to/screens-display-switcher` with the path where you cloned this
repo.

Raycast and Keyboard Maestro both call the same scripts, so the captured layout
files stay in one place.

You can also pass an explicit layout path:

```sh
./scripts/display-remote.sh layouts/some-other-remote.displayplacer
./scripts/display-restore.sh layouts/some-other-local.displayplacer
```

## Files

- `scripts/capture-layout.sh`: saves the current `displayplacer` command.
- `scripts/display-remote.sh`: applies `layouts/remote.displayplacer`.
- `scripts/display-restore.sh`: applies `layouts/local.displayplacer`.
- `scripts/install.sh`: checks dependencies and marks scripts executable.
- `raycast/raycast-display-remote.sh`: Raycast command for the remote layout.
- `raycast/raycast-display-restore.sh`: Raycast command for restoring the local layout.
- `layouts/*.example`: placeholders showing the expected file format.
- `layouts/*.displayplacer`: local captured display layouts, ignored by Git.

## Notes

`displayplacer list` prints a restorable command for the current display
arrangement. `capture-layout.sh` extracts that command and stores it in a layout
file. Layout files are plain text so you can inspect or edit them.

The switch scripts refuse to run `.example` files or placeholder commands. This
is intentional: capture real layouts first.

## Troubleshooting

### Remote and local layouts are identical

If the switch scripts report that remote and local layouts are identical, both
captured layout files contain the same `displayplacer` command. Running the
switch would not change the display, so the scripts stop instead of silently
doing nothing.

Set the display to the layout you want, then recapture the matching side:

```sh
./scripts/capture-layout.sh remote
```

or:

```sh
./scripts/capture-layout.sh local
```

### `could not find res`

If `displayplacer` reports that it `could not find res:<width>x<height>`, the
requested mode is not available in the current macOS display context.

This can happen if Screens/VNC changes the active display context. macOS may
expose the display as a virtual device with a different or reduced mode list, so
a layout captured in one context may not be available in another.

Capture and apply each layout from the same kind of session whenever possible.
If `displayplacer list` only shows one available mode, there may not be another
mode for these scripts to switch to in that session.

### Raycast cannot find `displayplacer`

Raycast may launch scripts with a smaller `PATH` than your shell. The scripts
prepend common Homebrew locations (`/opt/homebrew/bin` and `/usr/local/bin`) so
Raycast can find `displayplacer` when it is installed by Homebrew.

## License

MIT
