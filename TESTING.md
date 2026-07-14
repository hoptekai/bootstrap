# Testing the bootstrap

The installer makes system-level changes that are annoying to undo on your daily
driver — it installs Homebrew, installs Nix (a `/nix` volume + daemon), runs
`darwin-rebuild switch`, and applies a security baseline. So test it in a
throwaway **macOS VM**, not on your own machine. Everything here is
macOS-specific (nix-darwin, `defaults`, Homebrew), so there's no Docker/Linux
shortcut — you need a real macOS guest, which on Apple Silicon means a VM you can
snapshot and discard.

## Fast checks first (no VM)

Catch most breakage in seconds, safely, on your own machine:

```sh
just lint      # shellcheck install.sh + the baseline/helper scripts
just check     # nix flake check + build the closure WITHOUT switching
```

`just check` evaluates and builds the whole Nix config into the store but never
activates it, so it touches no live system state.

## Full end-to-end run (VM)

Uses [`tart`](https://github.com/cirruslabs/tart) to run disposable macOS VMs on
Apple Silicon. `tart` is free for personal use; orgs above a size threshold need
a paid license.

```sh
brew install cirruslabs/cli/tart
just test-vm                 # engineer profile, upstream main
```

What it does:

1. Pulls a base macOS image once (cached as a `bootstrap-base` template — the
   first pull is several GB).
2. Makes a fresh copy-on-write clone (`bootstrap-test`), discarding any prior
   run's state.
3. Boots it and prints a **paste-ready installer command**.

In the VM window: log in (**admin / admin**), open Terminal, and paste the
printed command. When you're done:

```sh
just test-vm-clean           # delete the test VM (keeps the cached base)
```

### Testing your own fork / branch

The in-VM installer downloads `install.sh` from GitHub, so push your branch
first, then point `test-vm` at it:

```sh
just test-vm engineer repo=YOU/bootstrap branch=my-feature
just test-vm staff   repo=YOU/bootstrap branch=my-feature   # lighter: no Nix
```

Start with the **staff** profile for a first smoke test — it skips Nix and the
SSH-fork prompt, so it's the quickest signal that the download + Homebrew path
works.

## Two gotchas a fresh VM exposes

1. **The default clone URLs are SSH** (`git@github.com:…`). A clean VM has no SSH
   keys and no 1Password agent, so `git clone` would fail. `just test-vm` works
   around this by passing HTTPS `--fork` / `--upstream` overrides in the printed
   command — keep those if you run the installer by hand.
2. **1Password-dependent steps can't be exercised** in the VM: commit signing and
   the SSH agent. Verify those manually on a real enrolled machine.

## Cleaning up

```sh
just test-vm-clean           # remove the throwaway test VM
tart delete bootstrap-base   # also drop the cached base image (re-pulls next time)
```

macOS's EULA permits up to 2 VMs per Apple machine. Prefer a GUI instead of a
CLI? [VirtualBuddy](https://github.com/insidegui/VirtualBuddy) and
[UTM](https://mac.getutm.app) both run Virtualization.framework guests with
snapshot/restore.
