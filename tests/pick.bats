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
}

# macOS ships bash 3.2 — the picker must run under it (no mapfile etc.).
@test "pick works under /bin/bash 3.2 and writes the staff Brewfile" {
  run env PATH="$stubs:/usr/bin:/bin" /bin/bash "$BATS_TEST_DIRNAME/../bin/pick" staff
  [ "$status" -eq 0 ]
  grep -q 'cask "spotify"' "$BOOTSTRAP_DIR/staff/Brewfile"
}

@test "pick keeps the markers so reruns stay idempotent" {
  env PATH="$stubs:/usr/bin:/bin" /bin/bash "$BATS_TEST_DIRNAME/../bin/pick" staff
  env PATH="$stubs:/usr/bin:/bin" /bin/bash "$BATS_TEST_DIRNAME/../bin/pick" staff
  [ "$(grep -c 'cask "spotify"' "$BOOTSTRAP_DIR/staff/Brewfile")" -eq 1 ]
  grep -q "BOOT:OPTIONAL" "$BOOTSTRAP_DIR/staff/Brewfile"
  grep -q "BOOT:END" "$BOOTSTRAP_DIR/staff/Brewfile"
}
