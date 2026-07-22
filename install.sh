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

# Apple Silicon: some casks and brew's Intel prefix need Rosetta 2.
ensure_rosetta() {
  [[ "$(uname -m)" == "arm64" ]] || return 0
  arch -x86_64 /usr/bin/true 2>/dev/null && return 0
  echo "==> Installing Rosetta 2"
  sudo softwareupdate --install-rosetta --agree-to-license
}

install_homebrew() {
  echo "==> Installing Homebrew (you may be asked for your macOS password)"
  # The NONINTERACTIVE installer probes with `sudo -n`, which fails without a
  # cached credential even for admins — prime the timestamp first.
  sudo -v
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

# True if the repo can be cloned without credentials (exists and is public).
check_remote_readable() {
  GIT_TERMINAL_PROMPT=0 git ls-remote "$1" HEAD >/dev/null 2>&1
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

  # 1. Rosetta, then Homebrew (also pulls in Xcode Command Line Tools / git).
  ensure_rosetta
  if ! command -v brew >/dev/null 2>&1; then
    install_homebrew
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
    if ! check_remote_readable "$ORIGIN"; then
      echo "error: cannot read $ORIGIN without credentials." >&2
      echo "Either the repo does not exist or it is PRIVATE. This bootstrap clones" >&2
      echo "over HTTPS before any GitHub auth is set up, so the repo must be public." >&2
      echo "Fork via https://github.com/hoptekai/bootstrap/fork (forks of a public" >&2
      echo "repo are always public) — a private mirror will not work here." >&2
      exit 1
    fi
    echo "==> Cloning into $BOOTSTRAP_DIR"
    mkdir -p "$(dirname "$BOOTSTRAP_DIR")"
    git clone "$ORIGIN" "$BOOTSTRAP_DIR"
  fi

  if [[ "$PROFILE" == "engineer" ]] && ! git -C "$BOOTSTRAP_DIR" remote | grep -qx upstream; then
    git -C "$BOOTSTRAP_DIR" remote add upstream "$(to_https_url "$UPSTREAM_URL")"
  fi

  echo "$PROFILE" > "$BOOTSTRAP_DIR/.profile"

  # 3. Hand off to the guided walkthrough (Bitwarden, FileVault, overlay, build).
  exec "$BOOTSTRAP_DIR/bin/onboard" "$PROFILE"
}

if [[ "${BOOTSTRAP_TEST_SOURCING:-0}" != "1" ]]; then
  main "$@"
fi
