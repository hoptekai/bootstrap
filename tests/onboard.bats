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

@test "first_darwin_switch runs nix-darwin under sudo" {
  stubs="$BATS_TEST_TMPDIR/stubs"
  log="$BATS_TEST_TMPDIR/calls.log"
  mkdir -p "$stubs"
  printf '#!/bin/bash\necho "sudo $*" >> "%s"\n' "$log" > "$stubs/sudo"
  chmod +x "$stubs/sudo"

  BOOTSTRAP_DIR=/tmp/bs PATH="$stubs:$PATH" first_darwin_switch

  run cat "$log"
  [ "${lines[0]}" = "sudo nix run nix-darwin -- switch --flake /tmp/bs#$(id -un)" ]
}

@test "ensure_gum installs gum via brew when missing" {
  stubs="$BATS_TEST_TMPDIR/stubs"
  log="$BATS_TEST_TMPDIR/calls.log"
  mkdir -p "$stubs"
  printf '#!/bin/bash\necho "brew $*" >> "%s"\n' "$log" > "$stubs/brew"
  chmod +x "$stubs/brew"

  PATH="$stubs:/usr/bin:/bin" ensure_gum

  run cat "$log"
  [ "$output" = "brew install gum" ]
}

@test "ensure_gum is a no-op when gum is present" {
  stubs="$BATS_TEST_TMPDIR/stubs"
  log="$BATS_TEST_TMPDIR/calls.log"
  mkdir -p "$stubs"
  printf '#!/bin/bash\n' > "$stubs/gum"
  printf '#!/bin/bash\necho "brew $*" >> "%s"\n' "$log" > "$stubs/brew"
  chmod +x "$stubs/gum" "$stubs/brew"

  PATH="$stubs:/usr/bin:/bin" ensure_gum

  [ ! -f "$log" ]
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
  ! grep -q '__BITWARDEN_SSH_PUBLIC_KEY__' "$f"
}

@test "sed_escape escapes sed replacement metacharacters" {
  run sed_escape 'Smith & Sons | Co\'
  [ "$output" = 'Smith \& Sons \| Co\\' ]
}

@test "sed_escape passes plain strings through" {
  run sed_escape "Jane Doe"
  [ "$output" = "Jane Doe" ]
}
