# Interactive onboarding: guided FileVault + 1Password setup

**Date:** 2026-07-22
**Status:** Approved

## Problem

Today the README requires manual steps before and after `install.sh`:

- Enable FileVault by hand in System Settings.
- Join 1Password, enable its SSH agent, create a key, and add it to GitHub — all
  *before* running the installer, because the engineer flow clones the fork over
  SSH and asks the user to paste their 1Password SSH public key mid-install.
- Push the overlay commit afterwards.

This is error-prone (skipped steps surface later as confusing git/SSH failures)
and the SSH-before-clone ordering forces the manual pre-work in the first place.

## Design

### Overall flow

`install.sh` becomes a thin fetcher:

1. Parse args / ask profile (unchanged).
2. Install Homebrew (unchanged).
3. Clone the repo over **HTTPS**. A pasted SSH fork URL
   (`git@github.com:you/bootstrap.git`) is converted to
   `https://github.com/you/bootstrap.git` automatically. Staff clone the
   upstream repo over HTTPS (assumes the repo is public).
4. `exec bin/onboard <profile>`.

All interactive logic lives in a new `bin/onboard` script: versioned in the
repo, testable in the VM harness, and reusable (`boot doctor` may call its
verify functions).

### Engineer walkthrough (`bin/onboard engineer`)

Steps in order. Each is idempotent (checks current state before acting), and
each verification is a loop: **Enter** to re-check, type **`skip`** to continue
anyway with a printed warning.

1. **1Password install** — `brew install --cask 1password 1password-cli` up
   front, before Nix. The casks remain in `packages/casks-shared.nix`;
   nix-darwin's `brew bundle` adopts the already-installed apps later.
2. **Sign in** — `open -a 1Password`; instruct: sign in to the business
   account, accept the shared **Eng** vault, and enable
   Settings → Developer → *Integrate with 1Password CLI* (needed for `op` and
   recovery-key auto-save). Verify: `op account list` succeeds.
3. **SSH agent** — guide the *Use the SSH agent* toggle and key creation.
   Verify: with `SSH_AUTH_SOCK` pointed at the 1Password agent socket
   (`~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`),
   `ssh-add -l` shows at least one key.
4. **GitHub** — read the public key from `ssh-add -L`, display it, open
   <https://github.com/settings/keys> in the browser, instruct adding it as
   both an *Authentication* and a *Signing* key. Verify:
   `ssh -T git@github.com` authenticates.
5. **FileVault** — if `fdesetup status` reports Off, run `sudo fdesetup enable`
   (stdin from `/dev/tty`, stdout captured), extract the personal recovery key,
   and save it into the user's 1Password vault via `op item create`. If `op`
   fails for any reason, fall back to displaying the key and requiring a typed
   confirmation that it has been saved before clearing it from the screen.
6. **Overlay** — generate `users/<name>.nix` from the template as today, but
   auto-fill the SSH public key from `ssh-add -L` instead of pasting. Full name
   and git email are still prompted.
7. **Nix + first build** — unchanged: Determinate installer (upstream Nix),
   optional-package picker, `nix run nix-darwin -- switch`.
8. **Finish** — flip `origin` to the SSH fork URL (SSH is now verified working)
   and push the overlay commit. The final summary re-lists any steps the user
   skipped.

### Staff walkthrough (`bin/onboard staff`)

1. `brew install --cask 1password`.
2. Guided sign-in to the business account (same CLI-integration toggle).
   Verify: `op account list`.
3. FileVault via `sudo fdesetup enable`, recovery key auto-saved via `op`
   (same fallback as engineers).
4. `brew bundle`, optional-package picker, `staff/defaults.sh` — as today.

No SSH agent, no GitHub, no overlay.

### Error handling & re-runnability

- Every step checks state first; re-running `install.sh` or `bin/onboard`
  resumes where it left off (FileVault already on → skip; key already on
  GitHub → `ssh -T` passes immediately).
- Verification loops never hard-fail; skipped steps are echoed in the final
  summary so nothing silently disappears.
- `fdesetup enable` edge cases (deferred enablement, user lacks a secure
  token): print the manual System Settings instruction and fall back to the
  confirm-and-continue path rather than aborting.
- All prompts read from `/dev/tty` (existing pattern) so `curl | bash` works.

### Testing & docs

- `BOOTSTRAP_NONINTERACTIVE=1` makes `onboard` skip all guided steps
  (1Password, FileVault, GitHub) and use template placeholder values for the
  overlay. This is what the VM harness runs.
- VM harness gains a smoke test that `bin/onboard` completes non-interactively
  for both profiles.
- README quick start collapses to: engineers — fork, run one command;
  staff — run one command. Manual-steps sections and the "FileVault can't be
  done declaratively" note are rewritten to describe the walkthrough.

## Decisions made

- **FileVault:** enabled directly via `sudo fdesetup enable` (not a
  System-Settings deep link, not check-and-warn).
- **Recovery key:** auto-saved to 1Password via `op item create`, with a
  display-and-confirm fallback.
- **1Password (engineer):** fully guided *and verified* — each step checked
  with real commands before proceeding.
- **Staff:** get the FileVault flow plus a sign-in walkthrough; no SSH steps.
- **Structure:** HTTPS-first clone + walkthrough in `bin/onboard`, keeping
  `install.sh` thin.

## Open assumption

The upstream repo is public, so HTTPS clones need no auth. If it is private,
staff cloning needs a separate decision (today's SSH clone was equally broken
for staff, who have no keys).

## Amendment (2026-07-22): Bitwarden instead of 1Password

After implementation, the fleet password manager changed to Bitwarden. The
design is unchanged structurally; the substitutions are: cask `bitwarden` +
formula `bitwarden-cli` (`bw`, logs in separately via `bw login`); SSH agent
socket `~/.bitwarden-ssh-agent.sock`; git signing via plain SSH-agent signing
(no `op-ssh-sign` equivalent — `gpg.ssh.program` dropped); recovery key saved
with `bw unlock --raw` + `bw encode | bw create item`, same display-and-confirm
fallback.
