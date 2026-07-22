setup() {
  export BOOTSTRAP_DIR="$BATS_TEST_TMPDIR/bs"
  mkdir -p "$BOOTSTRAP_DIR"
  echo engineer > "$BOOTSTRAP_DIR/.profile"

  stubs="$BATS_TEST_TMPDIR/stubs"
  log="$BATS_TEST_TMPDIR/calls.log"
  mkdir -p "$stubs"
  cat > "$stubs/git" <<EOF
#!/bin/bash
echo "git \$*" >> "$log"
[[ "\$*" == *" remote" ]] && echo upstream
exit 0
EOF
  printf '#!/bin/bash\necho "sudo $*" >> "%s"\n' "$log" > "$stubs/sudo"
  printf '#!/bin/bash\necho "nix $*" >> "%s"\n' "$log" > "$stubs/nix"
  chmod +x "$stubs/git" "$stubs/sudo" "$stubs/nix"
}

# `boot pick`/`boot add`/`nix flake update` legitimately dirty the clone, so
# the upstream pull must autostash instead of refusing to rebase.
@test "boot pull rebases with autostash" {
  run env PATH="$stubs:/usr/bin:/bin" BOOTSTRAP_DIR="$BOOTSTRAP_DIR" /bin/bash "$BATS_TEST_DIRNAME/../bin/boot" pull
  [ "$status" -eq 0 ]
  grep -q "^git -C $BOOTSTRAP_DIR pull --rebase --autostash upstream main$" "$log"
}
