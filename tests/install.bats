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

@test "install_homebrew primes sudo before running the installer" {
  stubs="$BATS_TEST_TMPDIR/stubs"
  log="$BATS_TEST_TMPDIR/calls.log"
  mkdir -p "$stubs"
  printf '#!/bin/bash\necho "sudo $*" >> "%s"\n' "$log" > "$stubs/sudo"
  printf '#!/bin/bash\necho "echo installer-ran >> %s"\n' "$log" > "$stubs/curl"
  chmod +x "$stubs/sudo" "$stubs/curl"

  PATH="$stubs:$PATH" install_homebrew

  run cat "$log"
  [ "${lines[0]}" = "sudo -v" ]
  [ "${lines[1]}" = "installer-ran" ]
}

@test "check_remote_readable succeeds for a repo that needs no credentials" {
  repo="$BATS_TEST_TMPDIR/repo.git"
  git init --bare -q "$repo"
  run check_remote_readable "$repo"
  [ "$status" -eq 0 ]
}

@test "check_remote_readable fails for a missing or private repo" {
  run check_remote_readable "$BATS_TEST_TMPDIR/does-not-exist.git"
  [ "$status" -ne 0 ]
}
