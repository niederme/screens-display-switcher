# screens-display-switcher

Manual macOS display layout switching for a Screens.app/VNC workflow.

The default setup is:

- `display remote`: remote-friendly layout for Screens.app.
- `display restore`: normal local display layout.

This utility deliberately does not try to detect VNC or Screens.app connection
state. The reliable workflow is explicit:

1. Run `display remote` from Raycast.
2. Connect with Screens.app.
3. Run `display restore` from Raycast when done.

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
display remote
```

After disconnecting and returning to the Mac locally, use Raycast:

```txt
display restore
```

The equivalent shell commands are:

```sh
./scripts/display-remote.sh
./scripts/display-restore.sh
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
display remote
display restore
```

You can assign hotkeys to either command from Raycast Preferences.

The Raycast commands are thin wrappers around `scripts/display-remote.sh` and
`scripts/display-restore.sh`, so capture and edit layouts in the same place.

### Custom Raycast Names

If you want machine-specific names like `Display: 1600` and `Display: 3200`,
copy the Raycast commands into a local ignored folder:

```sh
mkdir -p raycast-local
cp raycast/*.sh raycast-local/
```

Then edit the `@raycast.title` and `@raycast.description` lines in
`raycast-local/*.sh`, and add `raycast-local` as the Script Commands directory
in Raycast instead of `raycast`.

You can also pass an explicit layout path:

```sh
./scripts/display-remote.sh layouts/some-other-remote.displayplacer
./scripts/display-restore.sh layouts/some-other-local.displayplacer
```

## Files

- `scripts/capture-layout.sh`: saves the current `displayplacer` command.
- `scripts/display-remote.sh`: applies `layouts/remote.displayplacer`.
- `scripts/display-restore.sh`: applies `layouts/local.displayplacer`.
- `scripts/go-remote.sh`: compatibility wrapper for `display-remote.sh`.
- `scripts/restore-local.sh`: compatibility wrapper for `display-restore.sh`.
- `scripts/install.sh`: checks dependencies and marks scripts executable.
- `raycast/display-go-remote.sh`: Raycast command for the remote layout.
- `raycast/display-restore-local.sh`: Raycast command for restoring the local layout.
- `layouts/*.example`: placeholders showing the expected file format.
- `layouts/*.displayplacer`: local captured display layouts, ignored by Git.
- `raycast-local/`: optional local Raycast command names, ignored by Git.

## Notes

`displayplacer list` prints a restorable command for the current display
arrangement. `capture-layout.sh` extracts that command and stores it in a layout
file. Layout files are plain text so you can inspect or edit them.

The switch scripts refuse to run `.example` files or placeholder commands. This
is intentional: capture real layouts first.

## License

MIT
