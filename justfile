# Task runner for the bootstrap repo. `just <recipe>`; most are also exposed via `boot`.
# Engineer profile assumed for nix recipes.

user := `id -un`
dir  := justfile_directory()

# List recipes.
default:
    @just --list

# Apply the current config.
switch:
    sudo darwin-rebuild switch --flake "{{dir}}#{{user}}"

# Pull fleet-wide changes from upstream, then switch.
pull:
    git pull --rebase upstream main
    @just switch

# Pull upstream + bump the nixpkgs pin, then switch.
update:
    git pull --rebase upstream main
    nix flake update
    @just switch

# Choose optional packages.
pick:
    "{{dir}}/bin/pick" engineer

# Add a Homebrew cask and switch.
add cask:
    "{{dir}}/bin/boot" add "{{cask}}"

# Sanity-check the environment.
doctor:
    "{{dir}}/bin/boot" doctor

# Build the full closure without switching (safe verification).
check:
    nix flake check
    darwin-rebuild build --flake "{{dir}}#{{user}}"

# Lint the shell scripts (fast, safe, no VM needed).
lint:
    shellcheck install.sh staff/defaults.sh bin/boot bin/pick bin/onboard

# Unit-test the shell helpers (brew install bats-core).
test:
    bats tests

# --- VM testing (Apple Silicon) --------------------------------------------
# Throwaway macOS VMs via `tart`, so you can exercise the full curl|bash flow
# without touching your real machine. See TESTING.md.

vm_image := "ghcr.io/cirruslabs/macos-sequoia-base:latest"
vm_name  := "bootstrap-test"

# Boot a clean throwaway macOS VM and print the paste-ready installer command.
# Test your own fork/branch:  just test-vm engineer repo=YOU/bootstrap branch=my-branch
test-vm profile="engineer" repo="hoptekai/bootstrap" branch="main" noninteractive="1":
    #!/usr/bin/env bash
    set -euo pipefail
    command -v tart >/dev/null 2>&1 || {
      echo "tart not found. Install: brew install cirruslabs/cli/tart" >&2; exit 1; }

    # Pull the base image once (cached), keep it as a pristine template.
    if ! tart get bootstrap-base >/dev/null 2>&1; then
      echo "==> Pulling base image {{vm_image}} (one-time, several GB)…"
      tart clone "{{vm_image}}" bootstrap-base
    fi

    # Fresh copy-on-write clone for this run (fast; discards prior state).
    tart delete {{vm_name}} >/dev/null 2>&1 || true
    echo "==> Cloning a clean VM: {{vm_name}}"
    tart clone bootstrap-base {{vm_name}}

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

    cat <<EOF

    Clean VM ready. A window opens now — log in (user: admin / password: admin),
    open Terminal, and paste this to run the {{profile}} bootstrap:

      $CMD

    Reset for another run:  just test-vm-clean
    EOF
    tart run {{vm_name}}

# Delete the throwaway test VM (keeps the cached base template).
test-vm-clean:
    -tart delete {{vm_name}}
