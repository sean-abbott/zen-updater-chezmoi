# zen-updater-chezmoi

Installs and keeps [Zen Browser](https://zen-browser.app/) updated in your
home directory, using [chezmoi](https://www.chezmoi.io/). No root, nothing
outside `$HOME`, no custom checker script or separate update mechanism to
maintain — the version-check-and-fetch logic lives entirely in chezmoi's
own external-resolution machinery.

## How it works

- **`.chezmoiexternal.toml.tmpl`** resolves the latest
  `zen.linux-x86_64.tar.xz` release asset from the
  [zen-browser/desktop](https://github.com/zen-browser/desktop) GitHub
  releases API and syncs it into `~/.local/opt/zen-browser/current`.
  `exact = true` makes chezmoi reconcile that directory's *contents* the way
  `rsync -a --delete` does — it never removes or recreates the directory
  itself, which matters because Zen derives its default profile from a hash
  of the resolved install path.
- **`run_onchange_before_zen-backup.sh.tmpl`** runs before the external is
  applied and copies `current/` to `previous/` for manual rollback — but
  only when a new release is actually about to land, since its own content
  hash (which gates whether `run_onchange_` scripts re-run) embeds the
  target version string.
- **`run_onchange_after_update-desktop-database.sh.tmpl`** refreshes the
  desktop database after a new version lands.
- **`dot_local/share/applications/zen.desktop.tmpl`** and
  **`dot_local/bin/symlink_zen.tmpl`** install the desktop entry and the
  `zen` binary symlink.
- **`dot_config/systemd/user/zen-updater-check.{service,timer}`**
  install a `systemd --user` timer that runs `chezmoi apply` once a day
  (plus ~15 minutes after login if that day's run hasn't happened yet).

## Requirements

- `chezmoi` on `PATH`.
- `rsync` on `PATH` (used by the backup script).
- `systemd --user`.

## Install

This is meant to run as its own chezmoi source directory, independent of
any other chezmoi setup you have (see the note on multiple profiles below)
— clone it somewhere stable rather than deleting it after use, since the
systemd timer re-invokes `chezmoi apply` against this exact path:

```
git clone <this-repo-url> ~/.local/share/chezmoi-zen
chezmoi init --source ~/.local/share/chezmoi-zen
```

**Always pass `--persistent-state` pointing at a file unique to this
profile.** All chezmoi profiles share one global state database by
default even with separate `--source` dirs — and since this repo,
`wezterm-resurrect-chezmoi`, and `fish-chezmoi` all separately manage
`~/.local/bin`, without this flag whichever one applies second sees that
shared directory as "changed since chezmoi last wrote it" and refuses to
touch it. Confirmed by hitting this for real and fixing it — the systemd
timer's own `ExecStart` already includes it, but any manual invocation
needs it added too.

A second, nastier version of the same problem hit `~/.config` itself: this
repo originally used `private_dot_config` (mode 0700), while the other two
use plain `dot_config` for the same shared ancestor directory. Unlike
`--persistent-state`, which only isolates each profile's own *memory*,
this one had each profile's apply actually *changing* `.config`'s real
permissions to a different value than the last one wrote — so they fought
over it indefinitely, no flag fixes that. Renamed to plain `dot_config` to
match the other two and stop asserting a conflicting opinion about it.

**If you already have Zen installed another way**, check what chezmoi would
change before applying anything:

```
chezmoi diff --source ~/.local/share/chezmoi-zen --persistent-state ~/.local/state/chezmoi-profiles/zen.boltdb
```

Once you're satisfied:

```
chezmoi apply --source ~/.local/share/chezmoi-zen --persistent-state ~/.local/state/chezmoi-profiles/zen.boltdb
```

Enable the daily update-check timer:

```
systemctl --user daemon-reload
systemctl --user enable --now zen-updater-check.timer
```

`systemd --user` units only run while you have an active login session. For
checks to happen even when logged out:

```
loginctl enable-linger $USER
```

## Running alongside other chezmoi setups

chezmoi doesn't require one source directory per machine — you can run
several independently, each with its own `--source`, as long as they don't
manage overlapping target paths. This repo only touches
`~/.local/opt/zen-browser`, `~/.local/bin/zen`,
`~/.local/share/applications/zen.desktop`, and
`~/.config/systemd/user/zen-updater-check.{service,timer}`. A small wrapper
(shell function, fish function, alias — whatever you use) that calls
`chezmoi apply --source <dir>` for each of your chezmoi profiles in turn is
the standard way to apply more than one.

## Manually trigger a check

```
systemctl --user start zen-updater-check.service
journalctl --user -u zen-updater-check.service -n 30
```

## Uninstall

```
./uninstall.sh
```

run from wherever you cloned this repo. It stops and removes the systemd
timer and deletes everything it installed under `~/.config` and
`~/.local`. It doesn't delete the chezmoi source directory itself or the
clone — `rm -rf` those yourself if you're done with this entirely.

## Notes

- `gitHubLatestReleaseAssetURL`/`gitHubLatestRelease` hit the unauthenticated
  GitHub API (60 requests/hour per IP by default). Fine for a once-a-day
  timer; if you hit rate limits, chezmoi supports configuring a GitHub token
  — see chezmoi's own docs on GitHub API rate limiting.
- This has not been run against a real install yet. Dry-run with
  `chezmoi diff` before trusting it with a working browser setup.
