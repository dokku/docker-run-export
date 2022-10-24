#!/usr/bin/env bats

export SYSTEM_NAME="$(uname -s | tr '[:upper:]' '[:lower:]')"
export DOCKER_RUN_EXPORT_BIN="build/$SYSTEM_NAME/docker-run-export-amd64"

setup_file() {
  make prebuild $DOCKER_RUN_EXPORT_BIN
}

teardown_file() {
  make clean
}

@test "[stub]" {
  run true
  echo "output: $output"
  echo "status: $status"
}
