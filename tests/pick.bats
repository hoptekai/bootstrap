setup() {
  export BOOTSTRAP_DIR="$BATS_TEST_TMPDIR/bs"
  mkdir -p "$BOOTSTRAP_DIR/packages" "$BOOTSTRAP_DIR/staff"
  cat > "$BOOTSTRAP_DIR/packages/optional.list" <<'EOF'
Spotify | cask | spotify | engineer,staff | on
EOF
  cat > "$BOOTSTRAP_DIR/staff/Brewfile" <<'EOF'
cask "bitwarden"
# BOOT:OPTIONAL (managed by `boot pick` — safe to also edit by hand)
# BOOT:END
EOF
  stubs="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$stubs"
  printf '#!/bin/bash\necho Spotify\n' > "$stubs/gum"
  chmod +x "$stubs/gum"

  mkdir -p "$BOOTSTRAP_DIR/users"
  cat > "$BOOTSTRAP_DIR/users/$(id -un).nix" <<'EOF'
  # BOOT:OPTIONAL_CASKS (managed by `boot pick` — safe to also edit by hand)
  homebrew.casks = [ ];
  # BOOT:END
    # BOOT:OPTIONAL_NIX (managed by `boot pick` — safe to also edit by hand)
    home.packages = with pkgs; [ ];
    # BOOT:END
EOF
}

# macOS ships bash 3.2 — the picker must run under it (no mapfile etc.).
@test "pick works under /bin/bash 3.2 and writes the staff Brewfile" {
  run env PATH="$stubs:/usr/bin:/bin" /bin/bash "$BATS_TEST_DIRNAME/../bin/pick" staff
  [ "$status" -eq 0 ]
  grep -q 'cask "spotify"' "$BOOTSTRAP_DIR/staff/Brewfile"
}

@test "pick writes nix packages as bare attrs and casks as strings" {
  echo 'Htop | nix | htop | engineer,staff | off' >> "$BOOTSTRAP_DIR/packages/optional.list"
  printf '#!/bin/bash\necho Spotify\necho Htop\n' > "$stubs/gum"

  run env PATH="$stubs:/usr/bin:/bin" /bin/bash "$BATS_TEST_DIRNAME/../bin/pick" engineer
  [ "$status" -eq 0 ]
  userfile="$BOOTSTRAP_DIR/users/$(id -un).nix"
  grep -q 'homebrew.casks = \[ "spotify" \];' "$userfile"
  grep -q 'home.packages = with pkgs; \[ htop \];' "$userfile"
}

@test "pick writes no empty entries when nothing is selected" {
  printf '#!/bin/bash\nexit 0\n' > "$stubs/gum"

  run env PATH="$stubs:/usr/bin:/bin" /bin/bash "$BATS_TEST_DIRNAME/../bin/pick" engineer
  [ "$status" -eq 0 ]
  ! grep -q '""' "$BOOTSTRAP_DIR/users/$(id -un).nix"
}

@test "pick keeps the markers so reruns stay idempotent" {
  env PATH="$stubs:/usr/bin:/bin" /bin/bash "$BATS_TEST_DIRNAME/../bin/pick" staff
  env PATH="$stubs:/usr/bin:/bin" /bin/bash "$BATS_TEST_DIRNAME/../bin/pick" staff
  [ "$(grep -c 'cask "spotify"' "$BOOTSTRAP_DIR/staff/Brewfile")" -eq 1 ]
  grep -q "BOOT:OPTIONAL" "$BOOTSTRAP_DIR/staff/Brewfile"
  grep -q "BOOT:END" "$BOOTSTRAP_DIR/staff/Brewfile"
}
