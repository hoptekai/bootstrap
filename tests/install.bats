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
