# screens-display-switcher

Manual macOS display layout switching for a Screens.app/VNC workflow.

The intended setup is:

- `Display: 1600`: remote-friendly layout for connecting from a 13-inch MacBook Air.
- `Display: 3200`: normal local Studio Display layout.

This utility deliberately does not try to detect VNC or Screens.app connection
state. The reliable workflow is explicit:

1. Run `Display: 1600` from Raycast.
2. Connect with Screens.app.
3. Run `Display: 3200` from Raycast when done.

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

Set the Studio Display to your normal local layout, then capture it:

```sh
./scripts/capture-layout.sh local
```

Set the Studio Display to your Screens remote layout, then capture it:

```sh
./scripts/capture-layout.sh remote
```

This creates:

```txt
layouts/local.displayplacer
layouts/remote.displayplacer
```

## Use

Before connecting remotely, use Raycast:

```txt
Display: 1600
```

After disconnecting and returning to the Mac locally, use Raycast:

```txt
Display: 3200
```

The equivalent shell commands are:

```sh
./scripts/go-remote.sh
./scripts/restore-local.sh
```

## Raycast

This repo includes Raycast Script Commands in `raycast/`:

```txt
raycast/
  display-go-remote.sh
  display-restore-local.sh
```

To use them:

1. Open Raycast Preferences.
2. Go to Extensions -> Script Commands.
3. Add this folder as a script directory:

```txt
/Users/niederme/~Repos/screens-display-switcher/raycast
```

4. Search Raycast for:

```txt
Display: 1600
Display: 3200
```

You can assign hotkeys to either command from Raycast Preferences.

The Raycast commands are thin wrappers around `scripts/go-remote.sh` and
`scripts/restore-local.sh`, so capture and edit layouts in the same place.

You can also pass an explicit layout path:

```sh
./scripts/go-remote.sh layouts/some-other-remote.displayplacer
./scripts/restore-local.sh layouts/some-other-local.displayplacer
```

## Files

- `scripts/capture-layout.sh`: saves the current `displayplacer` command.
- `scripts/go-remote.sh`: applies `layouts/remote.displayplacer`.
- `scripts/restore-local.sh`: applies `layouts/local.displayplacer`.
- `scripts/install.sh`: checks dependencies and marks scripts executable.
- `raycast/display-go-remote.sh`: Raycast command for the 1600 remote layout.
- `raycast/display-restore-local.sh`: Raycast command for the 3200 local layout.
- `layouts/*.example`: placeholders showing the expected file format.
- `layouts/*.displayplacer`: local captured display layouts, ignored by Git.

## Notes

`displayplacer list` prints a restorable command for the current display
arrangement. `capture-layout.sh` extracts that command and stores it in a layout
file. Layout files are plain text so you can inspect or edit them.

The switch scripts refuse to run `.example` files or placeholder commands. This
is intentional: capture real layouts first.

## License

MIT
