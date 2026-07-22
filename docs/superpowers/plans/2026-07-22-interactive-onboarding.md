# Interactive Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the README's manual FileVault/1Password steps with a guided, verified walkthrough: `install.sh` becomes a thin HTTPS-cloning fetcher that hands off to a new `bin/onboard` script.

**Architecture:** `install.sh` (self-contained, runs under `curl | bash`) installs Homebrew, clones the repo over HTTPS (converting pasted SSH URLs), and `exec`s `bin/onboard <profile>`. `bin/onboard` holds all interactive logic: 1Password install/sign-in, SSH agent, GitHub key, FileVault via `sudo fdesetup enable` (recovery key auto-saved with `op item create`), overlay generation, Nix + first build, then flips `origin` to SSH and pushes. Every step is idempotent; every verification is an "Enter to re-check / `skip` to continue" loop.

**Tech Stack:** bash (macOS system bash 3.2!), Homebrew, bats-core for unit tests, shellcheck via `just lint`, tart VM harness for end-to-end.

**Spec:** `docs/superpowers/specs/2026-07-22-interactive-onboarding-design.md`

## Global Constraints

- **bash 3.2 compatible** — scripts run under macOS system bash before anything newer is installed. No `mapfile`, no associative arrays, no `${var,,}`. Accumulate lists in strings, not arrays (empty-array expansion breaks under `set -u` in bash 3.2).
- **All prompts read from `/dev/tty`** (existing `ask()` pattern) so `curl | bash` keeps working.
- **Idempotent** — every step checks current state before acting; re-running resumes.
- **`BOOTSTRAP_NONINTERACTIVE=1`** skips all guided steps (recording them as skipped) and uses placeholder overlay values. VM tests set it.
- **Testable-sourcing guard** — `install.sh` and `bin/onboard` end with `if [[ "${BOOTSTRAP_TEST_SOURCING:-0}" != "1" ]]; then main "$@"; fi` so bats can `source` them without executing.
- **shellcheck clean** — `just lint` must pass after every task.
- The 1Password SSH agent socket is `$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`.
- Upstream repo is assumed **public** (HTTPS clones need no auth).

---

### Task 1: bats harness + `bin/onboard` skeleton with pure helpers

**Files:**
- Create: `bin/onboard`
- Create: `tests/onboard.bats`
- Modify: `justfile` (lint recipe, new `test` recipe)

**Interfaces:**
- Produces: `to_ssh_url(url) -> stdout` (https GitHub URL → `git@github.com:...`, anything else passthrough); `extract_recovery_key(text) -> stdout` (recovery key or empty, always exit 0); `say`/`note`/`ask` print helpers; globals `BOOTSTRAP_DIR`, `NONINTERACTIVE`, `OP_SSH_SOCK`, `SKIPPED`; the `BOOTSTRAP_TEST_SOURCING` guard. All later tasks add functions to this file above `main()`.

- [ ] **Step 1: Install bats-core if missing**

Run: `command -v bats >/dev/null || brew install bats-core`

- [ ] **Step 2: Write the failing tests**

Create `tests/onboard.bats`:

```bats
setup() {
  export BOOTSTRAP_TEST_SOURCING=1
  source "$BATS_TEST_DIRNAME/../bin/onboard"
}

@test "to_ssh_url converts an https GitHub url to ssh" {
  run to_ssh_url "https://github.com/you/bootstrap.git"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com:you/bootstrap.git" ]
}

@test "to_ssh_url leaves ssh urls unchanged" {
  run to_ssh_url "git@github.com:you/bootstrap.git"
  [ "$output" = "git@github.com:you/bootstrap.git" ]
}

@test "extract_recovery_key pulls the key out of fdesetup output" {
  run extract_recovery_key "Enter the password for user 'admin':
Recovery key = 'ABCD-2345-EFGH-6789-JKLM-2345'"
  [ "$output" = "ABCD-2345-EFGH-6789-JKLM-2345" ]
}

@test "extract_recovery_key returns empty (exit 0) when no key present" {
  run extract_recovery_key "FileVault is already On."
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bats tests`
Expected: all 4 tests error — `bin/onboard: No such file or directory` from `setup()`.

- [ ] **Step 4: Create `bin/onboard`**

```bash
#!/usr/bin/env bash
# `bin/onboard` — guided post-clone setup, invoked by install.sh (or directly to resume).
#   onboard engineer | onboard staff
# Every step checks current state first, so re-running resumes where it left off.
# BOOTSTRAP_NONINTERACTIVE=1 skips guided steps and uses placeholders (VM testing).
set -euo pipefail

BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$HOME/.config/bootstrap}"
NONINTERACTIVE="${BOOTSTRAP_NONINTERACTIVE:-0}"
OP_SSH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
SKIPPED=""

say()  { printf '\n==> %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
ask()  { local var; read -r -p "$1" var < /dev/tty; printf '%s' "$var"; }

# ---- pure helpers (unit-tested in tests/onboard.bats) ----------------------

# https://github.com/you/repo.git -> git@github.com:you/repo.git; anything else unchanged.
to_ssh_url() {
  case "$1" in
    https://github.com/*) printf 'git@github.com:%s' "${1#https://github.com/}" ;;
    *) printf '%s' "$1" ;;
  esac
}

# Personal recovery key from `fdesetup enable` output (XXXX-XXXX-XXXX-XXXX-XXXX-XXXX).
extract_recovery_key() {
  printf '%s' "$1" | grep -Eo '[A-Z0-9]{4}(-[A-Z0-9]{4}){5}' | head -n1 || true
}

main() {
  echo "onboard: not implemented yet" >&2
  exit 1
}

if [[ "${BOOTSTRAP_TEST_SOURCING:-0}" != "1" ]]; then
  main "$@"
fi
```

Then: `chmod +x bin/onboard`

- [ ] **Step 5: Run tests to verify they pass**

Run: `bats tests`
Expected: `4 tests, 0 failures`

- [ ] **Step 6: Wire into justfile**

In `justfile`, replace the `lint` recipe and add `test` below it:

```make
# Lint the shell scripts (fast, safe, no VM needed).
lint:
    shellcheck install.sh staff/defaults.sh bin/boot bin/pick bin/onboard

# Unit-test the shell helpers (brew install bats-core).
test:
    bats tests
```

- [ ] **Step 7: Verify lint passes**

Run: `just lint`
Expected: exit 0, no output.

- [ ] **Step 8: Commit**

```bash
git add bin/onboard tests/onboard.bats justfile
git commit -m "feat: onboard skeleton with tested URL/recovery-key helpers"
```

---

### Task 2: interactive framework + guided 1Password/SSH/GitHub/FileVault steps

**Files:**
- Modify: `bin/onboard` (insert all functions below, above `main()`)
- Modify: `tests/onboard.bats` (append tests)

**Interfaces:**
- Consumes: `say`/`note`/`ask`, `NONINTERACTIVE`, `OP_SSH_SOCK`, `SKIPPED`, `extract_recovery_key` from Task 1.
- Produces: `add_skipped(label)`, `verify_loop(label, check_fn)`, `summary()`, `check_op_signin()`, `check_ssh_agent()`, `check_github_ssh()`, `check_filevault()`, `ensure_1password_installed()`, `guide_op_signin()`, `guide_ssh_agent()`, `guide_github_key()`, `ensure_filevault()`, `save_recovery_key(key)`. Tasks 3–4 call these.

- [ ] **Step 1: Write the failing tests**

Append to `tests/onboard.bats`:

```bats
@test "verify_loop records the label as skipped in noninteractive mode" {
  NONINTERACTIVE=1
  always_fail() { return 1; }
  verify_loop "Some step" always_fail
  [[ "$SKIPPED" == *"Some step"* ]]
}

@test "verify_loop returns immediately when the check passes" {
  NONINTERACTIVE=0
  always_pass() { return 0; }
  run verify_loop "Some step" always_pass
  [ "$status" -eq 0 ]
}

@test "summary lists skipped steps" {
  add_skipped "FileVault"
  run summary
  [[ "$output" == *"FileVault"* ]]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests`
Expected: 3 new tests fail with `verify_loop: command not found` / `add_skipped: command not found`.

- [ ] **Step 3: Implement the framework and guided steps**

Insert into `bin/onboard` after `extract_recovery_key` and before `main()`:

```bash
# ---- interactive framework -------------------------------------------------

add_skipped() { SKIPPED="${SKIPPED}  - $1\n"; }

# verify_loop <label> <check-fn>: re-check until it passes; 'skip' records and continues.
verify_loop() {
  local label="$1" fn="$2" a
  if [[ "$NONINTERACTIVE" == "1" ]]; then add_skipped "$label"; return 0; fi
  until "$fn"; do
    a="$(ask "    [$label] not verified — press Enter to re-check, or type 'skip': ")"
    if [[ "$a" == "skip" ]]; then add_skipped "$label"; return 0; fi
  done
  note "$label: ok"
}

summary() {
  say "Done."
  if [[ -n "$SKIPPED" ]]; then
    note "Skipped steps — finish these when you can:"
    printf '%b' "$SKIPPED"
  fi
  note "Everyday use: 'boot update' (pull fleet changes), 'boot pick', 'boot doctor'."
}

# ---- state checks ----------------------------------------------------------

check_op_signin() { command -v op >/dev/null 2>&1 && op account list >/dev/null 2>&1; }
check_ssh_agent() { SSH_AUTH_SOCK="$OP_SSH_SOCK" ssh-add -l >/dev/null 2>&1; }
# NB: `ssh -T git@github.com` exits 1 even on success, so capture with `|| true`
# instead of piping straight into grep (pipefail would eat the match).
check_github_ssh() {
  local out
  out="$(SSH_AUTH_SOCK="$OP_SSH_SOCK" ssh -T -o StrictHostKeyChecking=accept-new git@github.com 2>&1 || true)"
  grep -q 'successfully authenticated' <<<"$out"
}
check_filevault() { fdesetup status | grep -q 'FileVault is On'; }

# ---- guided steps ----------------------------------------------------------

ensure_1password_installed() {
  say "1Password"
  brew list --cask 1password >/dev/null 2>&1     || brew install --cask 1password
  brew list --cask 1password-cli >/dev/null 2>&1 || brew install --cask 1password-cli
}

guide_op_signin() {
  if check_op_signin; then note "1Password: already signed in"; return 0; fi
  say "1Password sign-in"
  if [[ "$NONINTERACTIVE" != "1" ]]; then open -a 1Password || true; fi
  note "In the 1Password window that just opened:"
  note "  1. Sign in to the company account (use your invite email)."
  note "  2. Accept any shared vaults you've been invited to (engineers: 'Eng')."
  note "  3. Settings -> Developer -> turn ON 'Integrate with 1Password CLI'."
  verify_loop "1Password sign-in + CLI integration" check_op_signin
}

guide_ssh_agent() {
  if check_ssh_agent; then note "1Password SSH agent: key available"; return 0; fi
  say "1Password SSH agent"
  note "In 1Password: Settings -> Developer -> turn ON 'Use the SSH agent'."
  note "No SSH key yet? New Item -> SSH Key -> Generate New Key (Ed25519)."
  verify_loop "1Password SSH agent" check_ssh_agent
}

guide_github_key() {
  if check_github_ssh; then note "GitHub SSH: authenticated"; return 0; fi
  say "GitHub SSH key"
  local pubkey=""
  if [[ "$NONINTERACTIVE" != "1" ]]; then
    pubkey="$(SSH_AUTH_SOCK="$OP_SSH_SOCK" ssh-add -L 2>/dev/null | head -n1 || true)"
  fi
  if [[ -n "$pubkey" ]]; then
    note "Your public key (add it on GitHub):"
    printf '\n%s\n\n' "$pubkey"
  fi
  note "On https://github.com/settings/keys add the key TWICE:"
  note "  - 'New SSH key' with type 'Authentication Key'"
  note "  - 'New SSH key' with type 'Signing Key'"
  if [[ "$NONINTERACTIVE" != "1" ]]; then open "https://github.com/settings/keys" || true; fi
  verify_loop "GitHub SSH auth" check_github_ssh
}

save_recovery_key() {
  local key="$1" title a=""
  title="FileVault recovery key ($(hostname))"
  if check_op_signin \
     && op item create --category "Secure Note" --title "$title" "notesPlain=$key" >/dev/null 2>&1; then
    note "Recovery key saved to 1Password as '$title'."
    return 0
  fi
  printf '\n    FILEVAULT RECOVERY KEY:  %s\n\n' "$key"
  note "Couldn't save it to 1Password automatically. Store it there NOW — it is shown only once."
  until [[ "$a" == "saved" ]]; do
    a="$(ask "    Type 'saved' once it is stored somewhere safe: ")"
  done
  clear >/dev/null 2>&1 || true
  note "FileVault recovery key stored."
}

ensure_filevault() {
  if check_filevault; then note "FileVault: already on"; return 0; fi
  if [[ "$NONINTERACTIVE" == "1" ]]; then add_skipped "FileVault"; return 0; fi
  say "Enabling FileVault — you'll be asked for your macOS account password"
  local out key
  if out="$(sudo fdesetup enable -user "$(id -un)" < /dev/tty)"; then
    key="$(extract_recovery_key "$out")"
    if [[ -n "$key" ]]; then
      save_recovery_key "$key"
    else
      note "FileVault enabled, but couldn't find a recovery key in the output:"
      printf '%s\n' "$out"
    fi
  else
    note "fdesetup couldn't enable FileVault (deferred enablement or no secure token?)."
    note "Enable it manually: System Settings -> Privacy & Security -> FileVault."
    verify_loop "FileVault" check_filevault
  fi
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests`
Expected: `7 tests, 0 failures`

- [ ] **Step 5: Lint**

Run: `just lint`
Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add bin/onboard tests/onboard.bats
git commit -m "feat: guided 1Password, SSH, GitHub, and FileVault steps in onboard"
```

---

### Task 3: engineer flow (overlay autofill, Nix, first build, origin flip)

**Files:**
- Modify: `bin/onboard` (insert below the Task 2 functions; replace `main()`)
- Modify: `tests/onboard.bats` (append test)

**Interfaces:**
- Consumes: everything from Tasks 1–2.
- Produces: `write_overlay()`, `ensure_nix()`, `source_nix()`, `finish_engineer_remote()`, `engineer()`, and a `main()` that dispatches `engineer|staff` (staff branch errors until Task 4).

- [ ] **Step 1: Write the failing test**

Append to `tests/onboard.bats`:

```bats
@test "write_overlay renders the template with placeholders in noninteractive mode" {
  tmp="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$tmp/users"
  cp "$BATS_TEST_DIRNAME/../users/_template.nix" "$tmp/users/_template.nix"
  git -C "$tmp" init -q
  git -C "$tmp" config user.email test@example.com
  git -C "$tmp" config user.name Test
  BOOTSTRAP_DIR="$tmp" NONINTERACTIVE=1 write_overlay
  f="$tmp/users/$(id -un).nix"
  [ -f "$f" ]
  grep -q 'Test User' "$f"
  grep -q 'test@example.com' "$f"
  ! grep -q '__FULL_NAME__' "$f"
  ! grep -q '__ONEPASSWORD_SSH_PUBLIC_KEY__' "$f"
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats tests`
Expected: new test fails with `write_overlay: command not found`.

- [ ] **Step 3: Implement the engineer flow**

Insert into `bin/onboard` after `ensure_filevault`, and **replace** the stub `main()`:

```bash
# ---- engineer flow ---------------------------------------------------------

write_overlay() {
  local username userfile full_name git_email pubkey
  username="$(id -un)"
  userfile="$BOOTSTRAP_DIR/users/$username.nix"
  if [[ -f "$userfile" ]]; then note "overlay users/$username.nix already exists"; return 0; fi
  say "Creating users/$username.nix"
  if [[ "$NONINTERACTIVE" == "1" ]]; then
    full_name="Test User"; git_email="test@example.com"; pubkey="ssh-ed25519 AAAA_placeholder"
  else
    full_name="$(ask 'Full name (for git): ')"
    git_email="$(ask 'Git email: ')"
    pubkey="$(SSH_AUTH_SOCK="$OP_SSH_SOCK" ssh-add -L 2>/dev/null | head -n1 || true)"
    if [[ -z "$pubkey" ]]; then
      echo "Paste your 1Password SSH PUBLIC key (ssh-ed25519 ...), used to sign commits:"
      pubkey="$(ask '> ')"
    else
      note "Using your 1Password SSH key for commit signing."
    fi
  fi
  sed -e "s|__FULL_NAME__|$full_name|" \
      -e "s|__GIT_EMAIL__|$git_email|" \
      -e "s|__ONEPASSWORD_SSH_PUBLIC_KEY__|$pubkey|" \
      "$BOOTSTRAP_DIR/users/_template.nix" > "$userfile"
  git -C "$BOOTSTRAP_DIR" add "users/$username.nix"
  git -C "$BOOTSTRAP_DIR" commit -m "Add overlay for $username" || true
}

ensure_nix() {
  if command -v nix >/dev/null 2>&1; then return 0; fi
  say "Installing Nix (Determinate installer, upstream Nix)"
  curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm
}

source_nix() {
  # shellcheck disable=SC1091
  [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]] \
    && . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
}

# SSH provably works now, so move origin off HTTPS and push the overlay commit.
finish_engineer_remote() {
  local origin ssh_url
  origin="$(git -C "$BOOTSTRAP_DIR" remote get-url origin)"
  ssh_url="$(to_ssh_url "$origin")"
  if [[ "$ssh_url" != "$origin" ]]; then
    git -C "$BOOTSTRAP_DIR" remote set-url origin "$ssh_url"
    note "origin is now $ssh_url"
  fi
  if check_github_ssh; then
    say "Pushing your overlay commit"
    git -C "$BOOTSTRAP_DIR" push origin HEAD \
      || note "push failed — run: git -C $BOOTSTRAP_DIR push origin"
  else
    note "GitHub SSH not verified — push later with: git -C $BOOTSTRAP_DIR push origin"
  fi
}

engineer() {
  ensure_1password_installed
  guide_op_signin
  guide_ssh_agent
  guide_github_key
  ensure_filevault
  ensure_nix
  source_nix
  write_overlay
  if [[ "$NONINTERACTIVE" != "1" ]]; then
    say "Optional package picker"
    "$BOOTSTRAP_DIR/bin/pick" engineer || true
  fi
  say "First darwin-rebuild switch (#$(id -un)) — you'll be asked for your password"
  nix run nix-darwin -- switch --flake "$BOOTSTRAP_DIR#$(id -un)"
  if [[ "$NONINTERACTIVE" != "1" ]]; then finish_engineer_remote; fi
  summary
}

main() {
  local profile="${1:-}"
  case "$profile" in
    engineer) engineer ;;
    staff) echo "onboard: staff flow not implemented yet" >&2; exit 1 ;;
    *) echo "usage: onboard <engineer|staff>" >&2; exit 1 ;;
  esac
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests`
Expected: `8 tests, 0 failures`

- [ ] **Step 5: Lint + commit**

Run: `just lint` (expect exit 0), then:

```bash
git add bin/onboard tests/onboard.bats
git commit -m "feat: engineer onboard flow with overlay autofill and origin flip"
```

---

### Task 4: staff flow

**Files:**
- Modify: `bin/onboard` (add `staff()`, wire into `main()`)
- Modify: `staff/defaults.sh:27` (stale FileVault note)

**Interfaces:**
- Consumes: `ensure_1password_installed`, `guide_op_signin`, `ensure_filevault`, `summary`, `NONINTERACTIVE`, `BOOTSTRAP_DIR`.
- Produces: `staff()`; `main` dispatches both profiles.

- [ ] **Step 1: Implement the staff flow**

Insert after `engineer()`:

```bash
# ---- staff flow ------------------------------------------------------------

staff() {
  ensure_1password_installed
  guide_op_signin
  ensure_filevault
  say "Installing apps (brew bundle)"
  brew bundle --file="$BOOTSTRAP_DIR/staff/Brewfile"
  if [[ "$NONINTERACTIVE" != "1" ]]; then
    say "Optional package picker"
    "$BOOTSTRAP_DIR/bin/pick" staff || true
    brew bundle --file="$BOOTSTRAP_DIR/staff/Brewfile"
  fi
  say "Applying security baseline"
  bash "$BOOTSTRAP_DIR/staff/defaults.sh"
  summary
}
```

In `main()`, replace the staff stub line with:

```bash
    staff) staff ;;
```

- [ ] **Step 2: Update the stale note in `staff/defaults.sh`**

Replace line 27 (`echo "==> Done. Note: enabling FileVault is a manual step (see README)."`) with:

```bash
echo "==> Done."
```

- [ ] **Step 3: Verify**

Run: `bats tests && just lint`
Expected: `8 tests, 0 failures`; lint exit 0.

- [ ] **Step 4: Commit**

```bash
git add bin/onboard staff/defaults.sh
git commit -m "feat: staff onboard flow (sign-in + FileVault + apps)"
```

---

### Task 5: thin `install.sh` with HTTPS clone

**Files:**
- Modify: `install.sh` (full rewrite below)
- Create: `tests/install.bats`

**Interfaces:**
- Consumes: `bin/onboard <profile>` (Tasks 3–4).
- Produces: `to_https_url(url) -> stdout`; `install.sh` no longer contains profile logic, Nix, overlay, or brew bundle — `bin/onboard` owns all of it.

- [ ] **Step 1: Write the failing tests**

Create `tests/install.bats`:

```bats
setup() {
  export BOOTSTRAP_TEST_SOURCING=1
  source "$BATS_TEST_DIRNAME/../install.sh"
}

@test "to_https_url converts an ssh GitHub url to https" {
  run to_https_url "git@github.com:you/bootstrap.git"
  [ "$output" = "https://github.com/you/bootstrap.git" ]
}

@test "to_https_url leaves https urls unchanged" {
  run to_https_url "https://github.com/you/bootstrap.git"
  [ "$output" = "https://github.com/you/bootstrap.git" ]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/install.bats`
Expected: both fail — sourcing current install.sh executes it (no guard yet) or `to_https_url: command not found`.

- [ ] **Step 3: Rewrite `install.sh`**

Replace the entire file with:

```bash
#!/usr/bin/env bash
# One-shot MacBook bootstrap (thin fetcher).
#
#   Engineer:  curl -fsSL <raw-url>/install.sh | bash -s -- --profile engineer --fork <your-fork-url>
#   Staff:     curl -fsSL <raw-url>/install.sh | bash -s -- --profile staff
#
# Clones over HTTPS (works before any SSH keys exist), then hands off to
# bin/onboard for the guided setup. Re-runnable; prompts read /dev/tty so it
# works under `curl | bash`.
set -euo pipefail

# ---- The canonical upstream repo everyone forks / staff clones ----------------------------
UPSTREAM_URL="https://github.com/hoptekai/bootstrap.git"
# ------------------------------------------------------------------------------------------

BOOTSTRAP_DIR="$HOME/.config/bootstrap"
PROFILE=""
FORK_URL=""

ask() { local var; read -r -p "$1" var < /dev/tty; printf '%s' "$var"; }

# git@github.com:you/repo.git -> https://github.com/you/repo.git; anything else unchanged.
to_https_url() {
  case "$1" in
    git@github.com:*) printf 'https://github.com/%s' "${1#git@github.com:}" ;;
    *) printf '%s' "$1" ;;
  esac
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile) PROFILE="${2:-}"; shift 2 ;;
      --fork)    FORK_URL="${2:-}"; shift 2 ;;
      --upstream) UPSTREAM_URL="${2:-}"; shift 2 ;;
      *) echo "unknown arg: $1"; exit 1 ;;
    esac
  done

  [[ -n "$PROFILE" ]] || PROFILE="$(ask 'Profile [engineer/staff]: ')"
  [[ "$PROFILE" == "engineer" || "$PROFILE" == "staff" ]] || { echo "profile must be engineer or staff"; exit 1; }

  echo "==> Bootstrapping ($PROFILE)"

  # 1. Homebrew (also pulls in Xcode Command Line Tools / git on a bare machine).
  if ! command -v brew >/dev/null 2>&1; then
    echo "==> Installing Homebrew"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"

  # 2. Clone over HTTPS (bin/onboard flips origin to SSH once the agent works).
  if [[ "$PROFILE" == "engineer" ]]; then
    [[ -n "$FORK_URL" ]] || FORK_URL="$(ask 'Your fork URL (git@github.com:you/bootstrap.git): ')"
    ORIGIN="$(to_https_url "$FORK_URL")"
  else
    ORIGIN="$(to_https_url "$UPSTREAM_URL")"
  fi

  if [[ -d "$BOOTSTRAP_DIR/.git" ]]; then
    echo "==> Repo exists, pulling"
    git -C "$BOOTSTRAP_DIR" pull --ff-only || true
  else
    echo "==> Cloning into $BOOTSTRAP_DIR"
    mkdir -p "$(dirname "$BOOTSTRAP_DIR")"
    git clone "$ORIGIN" "$BOOTSTRAP_DIR"
  fi

  if [[ "$PROFILE" == "engineer" ]] && ! git -C "$BOOTSTRAP_DIR" remote | grep -qx upstream; then
    git -C "$BOOTSTRAP_DIR" remote add upstream "$(to_https_url "$UPSTREAM_URL")"
  fi

  echo "$PROFILE" > "$BOOTSTRAP_DIR/.profile"

  # 3. Hand off to the guided walkthrough (1Password, FileVault, overlay, build).
  exec "$BOOTSTRAP_DIR/bin/onboard" "$PROFILE"
}

if [[ "${BOOTSTRAP_TEST_SOURCING:-0}" != "1" ]]; then
  main "$@"
fi
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests`
Expected: `10 tests, 0 failures`

- [ ] **Step 5: Lint + commit**

Run: `just lint` (expect exit 0), then:

```bash
git add install.sh tests/install.bats
git commit -m "feat: install.sh is a thin HTTPS-cloning fetcher that execs onboard"
```

---

### Task 6: VM harness noninteractive mode + TESTING.md

**Files:**
- Modify: `justfile` (test-vm recipe)
- Modify: `TESTING.md`

**Interfaces:**
- Consumes: `BOOTSTRAP_NONINTERACTIVE` behavior from Tasks 2–4.
- Produces: `just test-vm profile repo branch noninteractive` — printed command exports `BOOTSTRAP_NONINTERACTIVE` before the pipe (a `VAR=x curl | bash` prefix would only reach curl).

- [ ] **Step 1: Update the `test-vm` recipe**

In `justfile`, change the recipe signature and the `CMD=` lines:

```make
test-vm profile="engineer" repo="hoptekai/bootstrap" branch="main" noninteractive="1":
```

and replace the CMD block:

```bash
    # Build the exact command to paste inside the VM. HTTPS everywhere; the
    # export must precede the pipeline so bash (not just curl) sees it.
    RAW="https://raw.githubusercontent.com/{{repo}}/{{branch}}/install.sh"
    UPSTREAM="https://github.com/hoptekai/bootstrap.git"
    ENV="export BOOTSTRAP_NONINTERACTIVE={{noninteractive}};"
    if [ "{{profile}}" = "staff" ]; then
      CMD="$ENV curl -fsSL $RAW | bash -s -- --profile staff --upstream $UPSTREAM"
    else
      CMD="$ENV curl -fsSL $RAW | bash -s -- --profile engineer --fork https://github.com/{{repo}}.git --upstream $UPSTREAM"
    fi
```

- [ ] **Step 2: Update TESTING.md**

In "Fast checks first", add a line to the code block: `just test      # bats unit tests for install.sh / bin/onboard helpers`.

Replace the "Two gotchas" section with:

```markdown
## VM notes

1. **Guided steps are skipped by default.** The command `test-vm` prints exports
   `BOOTSTRAP_NONINTERACTIVE=1`, so the 1Password sign-in, SSH agent, GitHub
   key, FileVault, and package-picker steps are recorded as skipped and the
   overlay gets placeholder values — the run completes hands-off. To exercise
   the real walkthrough, run `just test-vm engineer noninteractive=0` (you'll
   need a 1Password account to sign in with).
2. **Clones are HTTPS by default now** — `install.sh` converts `git@` URLs
   itself, so a keyless VM clones fine. The `--fork`/`--upstream` overrides in
   the printed command just point at your test repo.
3. **1Password-dependent steps can't be fully exercised** in the VM: commit
   signing and the SSH agent. Verify those manually on a real enrolled machine.
```

- [ ] **Step 3: Verify + commit**

Run: `just lint && bats tests` (expect clean), then:

```bash
git add justfile TESTING.md
git commit -m "feat: noninteractive VM smoke mode for the guided installer"
```

---

### Task 7: README rewrite

**Files:**
- Modify: `README.md` (quick start, notes section)

**Interfaces:**
- Consumes: final behavior from Tasks 1–6. No code.

- [ ] **Step 1: Replace the Quick start section**

Replace everything from `### Engineers` through the end of the staff snippet (lines 17–50) with:

```markdown
### Engineers

1. **Fork this repo** to your own GitHub account.
2. **Run the installer** (paste your fork's clone URL — either form works):

   ```sh
   curl -fsSL https://raw.githubusercontent.com/hoptekai/bootstrap/main/install.sh \
     | bash -s -- --profile engineer --fork git@github.com:YOU/bootstrap.git
   ```

That's it. The installer clones your fork over HTTPS, then walks you through
everything interactively, verifying each step before moving on:

- **1Password** — install, sign in, enable the CLI integration and SSH agent,
  create your SSH key, add it to GitHub (as both an authentication and a
  signing key).
- **FileVault** — enabled via `fdesetup`; your recovery key is saved straight
  into your 1Password vault.
- **Your overlay** — `users/<you>.nix` is generated with your name, git email,
  and 1Password signing key (read from the agent, no pasting), then the first
  `darwin-rebuild switch` runs and your overlay commit is pushed to your fork.

Any step can be skipped (type `skip`) and finished later — skipped steps are
listed at the end, and re-running the installer resumes where you left off.

### Staff

```sh
curl -fsSL https://raw.githubusercontent.com/hoptekai/bootstrap/main/install.sh \
  | bash -s -- --profile staff
```

Walks through 1Password sign-in and FileVault (recovery key saved to
1Password), then installs the shared apps, your optional picks, and the
security baseline.
```

- [ ] **Step 2: Update the notes section**

Replace the line `- FileVault is a manual step; it can't be enabled declaratively.` (README.md:125) with:

```markdown
- FileVault can't be enabled declaratively; `bin/onboard` enables it with
  `sudo fdesetup enable` and saves the recovery key to 1Password.
```

- [ ] **Step 3: Check for other stale references**

Run: `grep -n "manual" README.md`
Expected: no remaining claims that FileVault/1Password/push are manual steps; fix any stragglers in the same spirit.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: README quick start for the guided installer"
```

---

## Verification (end of plan)

- `just lint && bats tests` — clean.
- `just check` — flake still evaluates (no Nix files changed, sanity only).
- VM smoke (requires tart + pushed branch): `just test-vm staff repo=YOU/bootstrap branch=<branch>` completes hands-off; then `just test-vm engineer ...` likewise. The FileVault/fdesetup password-prompt capture and `op item create` path can only be truly exercised on a real machine with a 1Password account — flag for manual verification during rollout.
