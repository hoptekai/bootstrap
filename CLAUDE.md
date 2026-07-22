# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

One-command MacBook bootstrap for the Hoptek fleet. Two profiles: **engineer**
(nix-darwin + Home Manager + Homebrew, fully declarative) and **staff**
(Homebrew apps + a shell security baseline, no Nix). Execution flow:

```
install.sh   thin fetcher, run via `curl | bash` — Rosetta, Homebrew, clone, hand off
bin/onboard  guided interactive setup (Bitwarden, FileVault, overlay, first switch)
bin/boot     everyday ops after onboarding (update / switch / pick / doctor)
bin/pick     gum checklist that rewrites marker regions (see below)
```

## Commands

```sh
just lint      # shellcheck install.sh staff/defaults.sh bin/boot bin/pick bin/onboard
just test      # bats tests/  (unit tests for shell helpers)
bats tests/install.bats   # a single test file
just check     # nix flake check + build the closure WITHOUT switching
just test-vm   # full end-to-end run in a disposable tart VM (Apple Silicon)
```

**Never run `install.sh`, `bin/onboard`, or `darwin-rebuild switch` on your own
machine** — they mutate live system state (Homebrew, /nix volume, FileVault,
security baseline). End-to-end testing happens only in a VM (see TESTING.md).

Upstream has no `users/*.nix` (each engineer's overlay lives in their fork), so
a full eval needs a rendered overlay. The pattern (flakes only see git-tracked
files, hence the `--intent-to-add`):

```sh
sed -e 's/__USERNAME__/testuser/g; s/__FULL_NAME__/Test User/g; \
        s/__GIT_EMAIL__/test@example.com/g; \
        s/__BITWARDEN_SSH_PUBLIC_KEY__/ssh-ed25519 AAAA_placeholder/g' \
  users/_template.nix > users/testuser.nix
git add --intent-to-add users/testuser.nix
nix eval .#darwinConfigurations.testuser.system.drvPath
git rm --cached users/testuser.nix && rm users/testuser.nix
```

## Fork-based ownership model

The canonical upstream (`hoptekai/bootstrap`) owns all shared files (`hosts/`,
`home/`, `modules/`, `packages/`, `staff/`, `bin/`, `claude/`). Engineers fork
it, and **the only file an engineer edits in their fork is their own
`users/<username>.nix`** — that keeps `boot update` (pull from upstream)
conflict-free. Consequences:

- Never create or edit `users/<someone>.nix` in upstream; overlays exist only
  in forks. `flake.nix` auto-discovers `users/*.nix` (minus `_template.nix`),
  so adding an engineer requires no flake edit.
- Per-user settings (name, email, signing key, optional picks) go in the
  overlay; everything fleet-wide goes in the shared files.
- Apps are listed twice on purpose: `packages/casks-shared.nix` (engineers) and
  `staff/Brewfile` (staff). Keep them in sync when adding a fleet-wide app.
- `claude/common.md` is fleet-wide Claude guidance, symlinked to
  `~/.claude/common.md` on every switch — commit conventions live there
  (Conventional Commits, signed commits).

## Hard constraints on the shell scripts

These scripts run on a **factory-fresh Mac**, which is an unusually hostile
environment. Each rule below has broken a real onboarding run:

- **Target macOS `/bin/bash` 3.2.** No `mapfile`/`readarray`, no `declare -A`,
  no `${var,,}`. Your dev machine's `env bash` is newer and will mask
  violations — `tests/pick.bats` deliberately runs `bin/pick` under
  `/bin/bash` to catch them.
- **stdin is a pipe under `curl | bash`.** Anything interactive (prompts, gum's
  TUI) must read `/dev/tty` (see `ask()` in install.sh and the stdin reattach
  in bin/pick).
- **sudo has no cached credential.** Homebrew's `NONINTERACTIVE=1` installer
  probes with `sudo -n` and aborts with a misleading "needs to be an
  Administrator" message — `install_homebrew` primes with `sudo -v` first.
  nix-darwin ≥ 25.05 requires `switch` to run as root (`first_darwin_switch`).
- **No GitHub auth exists at clone time.** The initial clone is anonymous
  HTTPS, so forks must be public; `check_remote_readable` guards this.
  `bin/onboard` flips origin to SSH only after the Bitwarden agent + GitHub
  key are verified.
- **The Bitwarden SSH agent socket is not ambient during onboarding.**
  `SSH_AUTH_SOCK=$BW_SSH_SOCK` must be set explicitly on every ssh/git-over-ssh
  call in `bin/onboard`; the Home Manager env var and ssh `IdentityAgent`
  config only exist after the first switch.
- **Tools from the nix config don't exist before the first switch.** gum is
  brew-installed by `ensure_gum` for the pre-switch picker run; the homebrew
  module's `cleanup = "zap"` then removes any brew package not declared in the
  config at switch time (which is also a warning: undeclared brew installs
  don't survive a switch).
- **Everything must be re-runnable.** Onboarding steps verify-or-skip
  (`verify_loop`), and a rerun resumes where the last attempt failed.

## bin/pick marker regions

`bin/pick` rewrites regions bounded by `# BOOT:...` markers and `# BOOT:END`
(in `users/<username>.nix` for engineers, `staff/Brewfile` for staff). When
emitting Nix: Homebrew casks are quoted strings (`homebrew.casks = [ "spotify" ]`)
but nixpkgs entries are bare attribute names (`home.packages = with pkgs; [ htop ]`).
Empty selections must produce empty lists — a stray `""` fails the module
type check at eval.

## Tests

bats tests live in `tests/` and test sourced helper functions:
`install.sh` and `bin/onboard` are guarded by `BOOTSTRAP_TEST_SOURCING=1` so
tests can source them without executing `main`. External commands (`sudo`,
`brew`, `gum`, `git`, `curl`) are stubbed as logging scripts on a prepended
`PATH`; tests assert on the recorded invocations. Keep new script logic in
small sourceable functions so it stays testable this way.
