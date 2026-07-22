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
just test      # bats unit tests for install.sh / bin/onboard helpers
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

## VM notes

1. **Guided steps are skipped by default.** The command `test-vm` prints exports
   `BOOTSTRAP_NONINTERACTIVE=1`, so the Bitwarden sign-in, SSH agent, GitHub
   key, FileVault, and package-picker steps are recorded as skipped and the
   overlay gets placeholder values — the run completes hands-off. To exercise
   the real walkthrough, run `just test-vm engineer noninteractive=0` (you'll
   need a Bitwarden account to sign in with).
2. **Clones are HTTPS by default now** — `install.sh` converts `git@` URLs
   itself, so a keyless VM clones fine. The `--fork`/`--upstream` overrides in
   the printed command just point at your test repo.
3. **Bitwarden-dependent steps can't be fully exercised** in the VM: commit
   signing and the SSH agent. Verify those manually on a real enrolled machine.

## Cleaning up

```sh
just test-vm-clean           # remove the throwaway test VM
tart delete bootstrap-base   # also drop the cached base image (re-pulls next time)
```

macOS's EULA permits up to 2 VMs per Apple machine. Prefer a GUI instead of a
CLI? [VirtualBuddy](https://github.com/insidegui/VirtualBuddy) and
[UTM](https://mac.getutm.app) both run Virtualization.framework guests with
snapshot/restore.
