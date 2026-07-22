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
