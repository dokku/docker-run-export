#!/usr/bin/env bats

export SYSTEM_NAME="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$(uname -m)" in
x86_64 | amd64) export SYSTEM_ARCH="amd64" ;;
aarch64 | arm64) export SYSTEM_ARCH="arm64" ;;
*) export SYSTEM_ARCH="amd64" ;;
esac
export DOCKER_RUN_EXPORT_BIN="build/$SYSTEM_NAME/docker-run-export-$SYSTEM_ARCH"

setup_file() {
  make prebuild $DOCKER_RUN_EXPORT_BIN
}

teardown_file() {
  make clean
}

# Helper: query the YAML portion of the output with yq
yq_s() {
  echo "$output" | yq "$1"
}

# Helper: query the JSON output with jq (skip any non-JSON lines like warnings)
jq_s() {
  echo "$output" | awk '/^\{/,0' | jq -r "$1"
}

# Helper: query the HCL output with dasel. Skips leading non-HCL lines
# (warnings printed to stderr and merged into $output by bats), parses the
# HCL with dasel, outputs JSON, and pipes through jq -r so callers get a
# bare scalar value -- matching the jq_s/yq_s pattern.
hcl_s() {
  echo "$output" | awk '/^job "/,0' | dasel -i hcl -o json "$1" | jq -r
}

# Helper: pipe the HCL portion of $output through `nomad job validate`.
# Writes to a temp file, validates with a bogus NOMAD_ADDR so the command
# does local validation only (no agent required), then removes the temp file.
# Skips the test if the nomad CLI is not installed on this machine.
nomad_validate_hcl() {
  if ! command -v nomad >/dev/null 2>&1; then
    skip "nomad CLI not installed"
  fi
  local tmpfile
  tmpfile="$(mktemp)"
  # Drop any leading warning lines (stderr merged into $output by bats)
  # by keeping everything from the first `job "` line onward.
  echo "$output" | awk '/^job "/,0' >"$tmpfile"
  NOMAD_ADDR=http://127.0.0.1:1 nomad job validate "$tmpfile"
  local nomad_status=$?
  rm -f "$tmpfile"
  return $nomad_status
}

# Helper: pipe the JSON portion of $output through `nomad job run -check-index 0 -output`
# style validation. Uses `nomad job validate` on a temp file so it works for both
# formats. Skips if nomad is unavailable.
nomad_validate_json() {
  if ! command -v nomad >/dev/null 2>&1; then
    skip "nomad CLI not installed"
  fi
  local tmpfile
  tmpfile="$(mktemp)"
  # `nomad job validate` can read either HCL or JSON (via `-json`).
  echo "$output" | awk '/^\{/,0' >"$tmpfile"
  NOMAD_ADDR=http://127.0.0.1:1 nomad job validate -json "$tmpfile"
  local nomad_status=$?
  rm -f "$tmpfile"
  return $nomad_status
}

# Basic functionality

@test "basic: image only" {
  run $DOCKER_RUN_EXPORT_BIN run alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.image')" == "alpine:latest" ]]
}

@test "basic: image with command" {
  run $DOCKER_RUN_EXPORT_BIN run alpine:latest echo hello
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.image')" == "alpine:latest" ]]
  [[ "$(yq_s '.services.app.command[0]')" == "echo" ]]
  [[ "$(yq_s '.services.app.command[1]')" == "hello" ]]
}

@test "basic: project name" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-project myproject alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.name')" == "myproject" ]]
}

@test "basic: container name" {
  run $DOCKER_RUN_EXPORT_BIN run --name mycontainer alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.container_name')" == "mycontainer" ]]
}

# Networking

@test "networking: add-host" {
  run $DOCKER_RUN_EXPORT_BIN run --add-host "myhost:192.168.1.1" alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.extra_hosts[0]')" == "myhost=192.168.1.1" ]]
}

@test "networking: dns" {
  run $DOCKER_RUN_EXPORT_BIN run --dns 8.8.8.8 --dns 8.8.4.4 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.dns[0]')" == "8.8.8.8" ]]
  [[ "$(yq_s '.services.app.dns[1]')" == "8.8.4.4" ]]
}

@test "networking: dns-option" {
  run $DOCKER_RUN_EXPORT_BIN run --dns-option ndots:5 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.dns_opt[0]')" == "ndots:5" ]]
}

@test "networking: dns-search" {
  run $DOCKER_RUN_EXPORT_BIN run --dns-search example.com alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.dns_search[0]')" == "example.com" ]]
}

@test "networking: hostname" {
  run $DOCKER_RUN_EXPORT_BIN run --hostname myhost alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.hostname')" == "myhost" ]]
}

@test "networking: domainname" {
  run $DOCKER_RUN_EXPORT_BIN run --domainname example.com alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.domainname')" == "example.com" ]]
}

@test "networking: mac-address" {
  run $DOCKER_RUN_EXPORT_BIN run --mac-address 92:d0:c6:0a:29:33 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.mac_address')" == "92:d0:c6:0a:29:33" ]]
}

@test "networking: publish" {
  run $DOCKER_RUN_EXPORT_BIN run -p 8080:80 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.ports[0].target')" == "80" ]]
  [[ "$(yq_s '.services.app.ports[0].published')" == "8080" ]]
}

@test "networking: expose" {
  run $DOCKER_RUN_EXPORT_BIN run --expose 8080 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.expose[0]')" == "8080" ]]
}

@test "networking: network" {
  run $DOCKER_RUN_EXPORT_BIN run --network mynetwork alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.networks.default.name')" == "mynetwork" ]]
  [[ "$(yq_s '.networks.default.external')" == "true" ]]
}

@test "networking: network-alias" {
  run $DOCKER_RUN_EXPORT_BIN run --network-alias myalias alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.networks.default.aliases[0]')" == "myalias" ]]
}

@test "networking: ip" {
  run $DOCKER_RUN_EXPORT_BIN run --ip 172.30.100.104 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.networks.default.ipv4_address')" == "172.30.100.104" ]]
}

@test "networking: ip6" {
  run $DOCKER_RUN_EXPORT_BIN run --ip6 "2001:db8::33" alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.networks.default.ipv6_address')" == "2001:db8::33" ]]
}

@test "networking: link" {
  run $DOCKER_RUN_EXPORT_BIN run --link db:database alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.links[0]')" == "db:database" ]]
}

@test "networking: link-local-ip" {
  run $DOCKER_RUN_EXPORT_BIN run --link-local-ip 169.254.1.1 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.networks.default.link_local_ips[0]')" == "169.254.1.1" ]]
}

# Volumes

@test "volumes: bind mount" {
  run $DOCKER_RUN_EXPORT_BIN run -v /host/path:/container/path alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.volumes[0].type')" == "bind" ]]
  [[ "$(yq_s '.services.app.volumes[0].source')" == "/host/path" ]]
  [[ "$(yq_s '.services.app.volumes[0].target')" == "/container/path" ]]
}

@test "volumes: bind mount read-only" {
  run $DOCKER_RUN_EXPORT_BIN run -v /host/path:/container/path:ro alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.volumes[0].read_only')" == "true" ]]
}

@test "volumes: named volume" {
  run $DOCKER_RUN_EXPORT_BIN run -v /data alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.volumes[0].type')" == "volume" ]]
  [[ "$(yq_s '.services.app.volumes[0].target')" == "/data" ]]
}

@test "volumes: mount bind" {
  run $DOCKER_RUN_EXPORT_BIN run --mount type=bind,source=/host,target=/container alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.volumes[0].type')" == "bind" ]]
  [[ "$(yq_s '.services.app.volumes[0].source')" == "/host" ]]
  [[ "$(yq_s '.services.app.volumes[0].target')" == "/container" ]]
}

@test "volumes: mount tmpfs" {
  run $DOCKER_RUN_EXPORT_BIN run --mount type=tmpfs,target=/tmp,tmpfs-size=100m alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.volumes[0].type')" == "tmpfs" ]]
  [[ "$(yq_s '.services.app.volumes[0].target')" == "/tmp" ]]
}

@test "volumes: tmpfs" {
  run $DOCKER_RUN_EXPORT_BIN run --tmpfs /tmp:size=100m alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.volumes[0].type')" == "tmpfs" ]]
  [[ "$(yq_s '.services.app.volumes[0].target')" == "/tmp" ]]
}

@test "volumes: volumes-from" {
  run $DOCKER_RUN_EXPORT_BIN run --volumes-from mycontainer alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.volumes_from[0]')" == "mycontainer" ]]
}

@test "volumes: volume-driver" {
  run $DOCKER_RUN_EXPORT_BIN run --volume-driver local alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.volume_driver')" == "local" ]]
}

@test "volumes: read-only" {
  run $DOCKER_RUN_EXPORT_BIN run --read-only alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.read_only')" == "true" ]]
}

@test "volumes: working directory" {
  run $DOCKER_RUN_EXPORT_BIN run -w /app alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.working_dir')" == "/app" ]]
}

# Resource constraints

@test "resources: cpus" {
  run $DOCKER_RUN_EXPORT_BIN run --cpus 2 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.cpus')" == "2" ]]
  [[ "$(yq_s '.services.app.deploy.resources.limits.cpus')" == "2" ]]
}

@test "resources: memory" {
  run $DOCKER_RUN_EXPORT_BIN run --memory 512 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.mem_limit')" == "512" ]]
  [[ "$(yq_s '.services.app.deploy.resources.limits.memory')" == "512" ]]
}

@test "resources: cpu-shares" {
  run $DOCKER_RUN_EXPORT_BIN run --cpu-shares 512 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.cpu_shares')" == "512" ]]
}

@test "resources: cpu-period" {
  run $DOCKER_RUN_EXPORT_BIN run --cpu-period 100000 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.cpu_period')" == "100000" ]]
}

@test "resources: cpu-quota" {
  run $DOCKER_RUN_EXPORT_BIN run --cpu-quota 50000 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.cpu_quota')" == "50000" ]]
}

@test "resources: cpu-rt-period" {
  run $DOCKER_RUN_EXPORT_BIN run --cpu-rt-period 1000000 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.cpu_rt_period')" == "1000000" ]]
}

@test "resources: cpu-rt-runtime" {
  run $DOCKER_RUN_EXPORT_BIN run --cpu-rt-runtime 950000 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.cpu_rt_runtime')" == "950000" ]]
}

@test "resources: cpuset-cpus" {
  run $DOCKER_RUN_EXPORT_BIN run --cpuset-cpus 0-3 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.cpuset')" == "0-3" ]]
}

@test "resources: memory-reservation" {
  run $DOCKER_RUN_EXPORT_BIN run --memory-reservation 256 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.mem_reservation')" == "256" ]]
}

@test "resources: memory-swap" {
  run $DOCKER_RUN_EXPORT_BIN run --memory-swap 1024 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.memswap_limit')" == "1024" ]]
}

@test "resources: blkio-weight" {
  run $DOCKER_RUN_EXPORT_BIN run --blkio-weight 300 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.blkio_config.weight')" == "300" ]]
}

@test "resources: shm-size" {
  run $DOCKER_RUN_EXPORT_BIN run --shm-size 64 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.shm_size')" == "64" ]]
}

@test "resources: pids-limit" {
  run $DOCKER_RUN_EXPORT_BIN run --pids-limit 100 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.pids_limit')" == "100" ]]
}

@test "resources: ulimit" {
  run $DOCKER_RUN_EXPORT_BIN run --ulimit nofile=1024:2048 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.ulimits.nofile.soft')" == "1024" ]]
  [[ "$(yq_s '.services.app.ulimits.nofile.hard')" == "2048" ]]
}

# Security and privileges

@test "security: cap-add" {
  run $DOCKER_RUN_EXPORT_BIN run --cap-add NET_ADMIN alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.cap_add[0]')" == "NET_ADMIN" ]]
}

@test "security: cap-drop" {
  run $DOCKER_RUN_EXPORT_BIN run --cap-drop ALL alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.cap_drop[0]')" == "ALL" ]]
}

@test "security: privileged" {
  run $DOCKER_RUN_EXPORT_BIN run --privileged alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.privileged')" == "true" ]]
}

@test "security: security-opt" {
  run $DOCKER_RUN_EXPORT_BIN run --security-opt no-new-privileges alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.security_opt[0]')" == "no-new-privileges" ]]
}

@test "security: user" {
  run $DOCKER_RUN_EXPORT_BIN run --user 1000:1000 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.user')" == "1000:1000" ]]
}

@test "security: group-add" {
  run $DOCKER_RUN_EXPORT_BIN run --group-add audio alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.group_add[0]')" == "audio" ]]
}

# Namespace and isolation

@test "namespace: cgroupns" {
  run $DOCKER_RUN_EXPORT_BIN run --cgroupns private alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.cgroup')" == "private" ]]
}

@test "namespace: cgroup-parent" {
  run $DOCKER_RUN_EXPORT_BIN run --cgroup-parent /mygroup alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.cgroup_parent')" == "/mygroup" ]]
}

@test "namespace: pid" {
  run $DOCKER_RUN_EXPORT_BIN run --pid host alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.pid')" == "host" ]]
}

@test "namespace: ipc" {
  run $DOCKER_RUN_EXPORT_BIN run --ipc host alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.ipc')" == "host" ]]
}

@test "namespace: userns" {
  run $DOCKER_RUN_EXPORT_BIN run --userns host alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.userns_mode')" == "host" ]]
}

@test "namespace: uts" {
  run $DOCKER_RUN_EXPORT_BIN run --uts host alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.uts')" == "host" ]]
}

@test "namespace: isolation" {
  run $DOCKER_RUN_EXPORT_BIN run --isolation default alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.isolation')" == "default" ]]
}

# Health check

@test "healthcheck: basic" {
  run $DOCKER_RUN_EXPORT_BIN run --health-cmd "curl -f http://localhost/" --health-interval 30s --health-timeout 10s --health-retries 3 --health-start-period 5s alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.healthcheck.test[0]')" == "curl" ]]
  [[ "$(yq_s '.services.app.healthcheck.interval')" == "30s" ]]
  [[ "$(yq_s '.services.app.healthcheck.timeout')" == "10s" ]]
  [[ "$(yq_s '.services.app.healthcheck.retries')" == "3" ]]
  [[ "$(yq_s '.services.app.healthcheck.start_period')" == "5s" ]]
}

@test "healthcheck: disable" {
  run $DOCKER_RUN_EXPORT_BIN run --no-healthcheck alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.healthcheck.disable')" == "true" ]]
}

@test "healthcheck: conflict warns" {
  run $DOCKER_RUN_EXPORT_BIN run --no-healthcheck --health-cmd "curl localhost" alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"ignoring --health-cmd"* ]]
  [[ "$(yq_s '.services.app.healthcheck.disable')" == "true" ]]
}

# Environment and labels

@test "environment: env" {
  run $DOCKER_RUN_EXPORT_BIN run -e FOO=bar -e BAZ=qux alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.environment.FOO')" == "bar" ]]
  [[ "$(yq_s '.services.app.environment.BAZ')" == "qux" ]]
}

@test "environment: env-file" {
  run $DOCKER_RUN_EXPORT_BIN run --env-file /path/to/.env alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.env_file[0].path')" == "/path/to/.env" ]]
}

@test "labels: label" {
  run $DOCKER_RUN_EXPORT_BIN run -l com.example.key=value alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.labels."com.example.key"')" == "value" ]]
}

@test "labels: label-file" {
  run $DOCKER_RUN_EXPORT_BIN run --label-file /path/to/labels alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.label_file[0]')" == "/path/to/labels" ]]
}

# Lifecycle and process management

@test "lifecycle: restart" {
  run $DOCKER_RUN_EXPORT_BIN run --restart always alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.restart')" == "always" ]]
}

@test "lifecycle: restart unless-stopped" {
  run $DOCKER_RUN_EXPORT_BIN run --restart unless-stopped alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.restart')" == "unless-stopped" ]]
}

@test "lifecycle: restart on-failure" {
  run $DOCKER_RUN_EXPORT_BIN run --restart on-failure:5 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.restart')" == "on-failure:5" ]]
}

@test "lifecycle: restart default not emitted" {
  run $DOCKER_RUN_EXPORT_BIN run --restart no alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.restart')" == "null" ]]
}

@test "lifecycle: init" {
  run $DOCKER_RUN_EXPORT_BIN run --init alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.init')" == "true" ]]
}

@test "lifecycle: stop-signal" {
  run $DOCKER_RUN_EXPORT_BIN run --stop-signal SIGINT alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.stop_signal')" == "SIGINT" ]]
}

@test "lifecycle: stop-signal default not emitted" {
  run $DOCKER_RUN_EXPORT_BIN run --stop-signal SIGTERM alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.stop_signal')" == "null" ]]
}

@test "lifecycle: stop-timeout" {
  run $DOCKER_RUN_EXPORT_BIN run --stop-timeout 30 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.stop_grace_period')" == "30s" ]]
}

@test "lifecycle: oom-kill-disable" {
  run $DOCKER_RUN_EXPORT_BIN run --oom-kill-disable alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.oom_kill_disable')" == "true" ]]
}

@test "lifecycle: oom-score-adj" {
  run $DOCKER_RUN_EXPORT_BIN run --oom-score-adj 500 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.oom_score_adj')" == "500" ]]
}

# TTY and stdin

@test "tty: tty" {
  run $DOCKER_RUN_EXPORT_BIN run -t alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.tty')" == "true" ]]
}

@test "tty: interactive" {
  run $DOCKER_RUN_EXPORT_BIN run -i alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.stdin_open')" == "true" ]]
}

# Devices

@test "devices: device" {
  run $DOCKER_RUN_EXPORT_BIN run --device /dev/sda:/dev/xvdc:rwm alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.devices[0].source')" == "/dev/sda" ]]
  [[ "$(yq_s '.services.app.devices[0].target')" == "/dev/xvdc" ]]
  [[ "$(yq_s '.services.app.devices[0].permissions')" == "rwm" ]]
}

@test "devices: device-cgroup-rule" {
  run $DOCKER_RUN_EXPORT_BIN run --device-cgroup-rule "c 42:* rmw" alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.device_cgroup_rules[0]')" == "c 42:* rmw" ]]
}

# Logging

@test "logging: log-driver and log-opt" {
  run $DOCKER_RUN_EXPORT_BIN run --log-driver json-file --log-opt max-size=10m --log-opt max-file=3 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.log_driver')" == "json-file" ]]
  [[ "$(yq_s '.services.app.log_opt."max-size"')" == "10m" ]]
  [[ "$(yq_s '.services.app.log_opt."max-file"')" == "3" ]]
}

# Platform and runtime

@test "platform: platform" {
  run $DOCKER_RUN_EXPORT_BIN run --platform linux/amd64 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.platform')" == "linux/amd64" ]]
}

@test "platform: runtime" {
  run $DOCKER_RUN_EXPORT_BIN run --runtime nvidia alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.runtime')" == "nvidia" ]]
}

# Entrypoint

@test "entrypoint: entrypoint" {
  run $DOCKER_RUN_EXPORT_BIN run --entrypoint /bin/sh alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.entrypoint[0]')" == "/bin/sh" ]]
}

# Sysctl

@test "sysctl: sysctl" {
  run $DOCKER_RUN_EXPORT_BIN run --sysctl net.core.somaxconn=1024 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.sysctls."net.core.somaxconn"')" == "1024" ]]
}

# New flags added in this update

@test "new: annotation" {
  run $DOCKER_RUN_EXPORT_BIN run --annotation com.example.key=value alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.annotations."com.example.key"')" == "value" ]]
}

@test "new: pull-policy always" {
  run $DOCKER_RUN_EXPORT_BIN run --pull always alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.pull_policy')" == "always" ]]
}

@test "new: pull-policy never" {
  run $DOCKER_RUN_EXPORT_BIN run --pull never alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.pull_policy')" == "never" ]]
}

@test "new: pull-policy default not emitted" {
  run $DOCKER_RUN_EXPORT_BIN run --pull missing alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.pull_policy')" == "null" ]]
}

@test "new: gpus all" {
  run $DOCKER_RUN_EXPORT_BIN run --gpus all alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.gpus[0].capabilities[0]')" == "gpu" ]]
  [[ "$(yq_s '.services.app.gpus[0].count')" == "-1" ]]
}

@test "new: storage-opt" {
  run $DOCKER_RUN_EXPORT_BIN run --storage-opt size=120G alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.storage_opt.size')" == "120G" ]]
}

# Unsupported flags should warn

@test "unsupported: attach warns" {
  run $DOCKER_RUN_EXPORT_BIN run -a stdout alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --attach"* ]]
}

@test "unsupported: cidfile warns" {
  run $DOCKER_RUN_EXPORT_BIN run --cidfile /tmp/cid alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --cidfile"* ]]
}

@test "unsupported: cpuset-mems warns" {
  run $DOCKER_RUN_EXPORT_BIN run --cpuset-mems 0-1 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --cpuset-mems"* ]]
}

@test "unsupported: detach warns" {
  run $DOCKER_RUN_EXPORT_BIN run -d alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --detach"* ]]
}

@test "unsupported: detach-keys warns" {
  run $DOCKER_RUN_EXPORT_BIN run --detach-keys ctrl-p alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --detach-keys"* ]]
}

@test "unsupported: kernel-memory warns" {
  run $DOCKER_RUN_EXPORT_BIN run --kernel-memory 128 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --kernel-memory"* ]]
}

@test "unsupported: publish-all warns" {
  run $DOCKER_RUN_EXPORT_BIN run -P alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --publish-all"* ]]
}

@test "unsupported: rm warns" {
  run $DOCKER_RUN_EXPORT_BIN run --rm alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --rm"* ]]
}

@test "unsupported: sig-proxy warns" {
  run $DOCKER_RUN_EXPORT_BIN run --sig-proxy=false alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --sig-proxy"* ]]
}

# Previously unsupported flags that should now work (no warnings)

@test "now-supported: cgroupns no warning" {
  run $DOCKER_RUN_EXPORT_BIN run --cgroupns private alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"unable to set"* ]]
  [[ "$(yq_s '.services.app.cgroup')" == "private" ]]
}

@test "now-supported: cpu-period no warning" {
  run $DOCKER_RUN_EXPORT_BIN run --cpu-period 100000 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"unable to set"* ]]
  [[ "$(yq_s '.services.app.cpu_period')" == "100000" ]]
}

@test "now-supported: cpu-quota no warning" {
  run $DOCKER_RUN_EXPORT_BIN run --cpu-quota 50000 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"unable to set"* ]]
  [[ "$(yq_s '.services.app.cpu_quota')" == "50000" ]]
}

@test "now-supported: cpuset-cpus no warning" {
  run $DOCKER_RUN_EXPORT_BIN run --cpuset-cpus 0-3 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"unable to set"* ]]
  [[ "$(yq_s '.services.app.cpuset')" == "0-3" ]]
}

@test "now-supported: interactive no warning" {
  run $DOCKER_RUN_EXPORT_BIN run -i alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"unable to set"* ]]
  [[ "$(yq_s '.services.app.stdin_open')" == "true" ]]
}

@test "now-supported: storage-opt no warning" {
  run $DOCKER_RUN_EXPORT_BIN run --storage-opt size=120G alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"unable to set"* ]]
  [[ "$(yq_s '.services.app.storage_opt.size')" == "120G" ]]
}

@test "now-supported: gpus no warning" {
  run $DOCKER_RUN_EXPORT_BIN run --gpus all alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"unable to set"* ]]
  [[ "$(yq_s '.services.app.gpus[0].capabilities[0]')" == "gpu" ]]
}

@test "now-supported: label-file no warning" {
  run $DOCKER_RUN_EXPORT_BIN run --label-file /path/to/labels alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"unable to set"* ]]
  [[ "$(yq_s '.services.app.label_file[0]')" == "/path/to/labels" ]]
}

@test "now-supported: pull always no warning" {
  run $DOCKER_RUN_EXPORT_BIN run --pull always alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"unable to set"* ]]
  [[ "$(yq_s '.services.app.pull_policy')" == "always" ]]
}

# Combined flags

@test "combined: multiple flags together" {
  run $DOCKER_RUN_EXPORT_BIN run \
    --name myapp \
    --hostname myhost \
    -e FOO=bar \
    -p 8080:80 \
    -v /data:/data:ro \
    --restart always \
    --cpus 2 \
    --memory 512 \
    --cap-add NET_ADMIN \
    --cap-drop ALL \
    --init \
    --read-only \
    -l com.example=test \
    alpine:latest echo hello
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.services.app.container_name')" == "myapp" ]]
  [[ "$(yq_s '.services.app.hostname')" == "myhost" ]]
  [[ "$(yq_s '.services.app.environment.FOO')" == "bar" ]]
  [[ "$(yq_s '.services.app.ports[0].target')" == "80" ]]
  [[ "$(yq_s '.services.app.volumes[0].type')" == "bind" ]]
  [[ "$(yq_s '.services.app.restart')" == "always" ]]
  [[ "$(yq_s '.services.app.cpus')" == "2" ]]
  [[ "$(yq_s '.services.app.cap_add[0]')" == "NET_ADMIN" ]]
  [[ "$(yq_s '.services.app.cap_drop[0]')" == "ALL" ]]
  [[ "$(yq_s '.services.app.init')" == "true" ]]
  [[ "$(yq_s '.services.app.read_only')" == "true" ]]
  [[ "$(yq_s '.services.app.labels."com.example"')" == "test" ]]
  [[ "$(yq_s '.services.app.image')" == "alpine:latest" ]]
  [[ "$(yq_s '.services.app.command[0]')" == "echo" ]]
}

# ==========================================
# ECS Task Definition Tests
# ==========================================

# ECS Basic functionality

@test "ecs basic: image only" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].image')" == "alpine:latest" ]]
  [[ "$(jq_s '.containerDefinitions[0].name')" == "app" ]]
  [[ "$(jq_s '.containerDefinitions[0].essential')" == "true" ]]
}

@test "ecs basic: valid json output" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs alpine:latest
  [[ "$status" -eq 0 ]]
  echo "$output" | jq . >/dev/null 2>&1
}

@test "ecs basic: image with command" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs alpine:latest echo hello
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].image')" == "alpine:latest" ]]
  [[ "$(jq_s '.containerDefinitions[0].command[0]')" == "echo" ]]
  [[ "$(jq_s '.containerDefinitions[0].command[1]')" == "hello" ]]
}

@test "ecs basic: family from project name" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --dre-project myapp alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.family')" == "myapp" ]]
}

@test "ecs basic: container name from --name" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --name mycontainer alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].name')" == "mycontainer" ]]
}

@test "ecs basic: family falls back to container name" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --name mycontainer alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.family')" == "mycontainer" ]]
}

@test "ecs basic: entrypoint" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --entrypoint /bin/sh alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].entryPoint[0]')" == "/bin/sh" ]]
}

# ECS Networking

@test "ecs networking: add-host" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --add-host "myhost:192.168.1.1" alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].extraHosts[0].hostname')" == "myhost" ]]
  [[ "$(jq_s '.containerDefinitions[0].extraHosts[0].ipAddress')" == "192.168.1.1" ]]
}

@test "ecs networking: dns" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --dns 8.8.8.8 --dns 8.8.4.4 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].dnsServers[0]')" == "8.8.8.8" ]]
  [[ "$(jq_s '.containerDefinitions[0].dnsServers[1]')" == "8.8.4.4" ]]
}

@test "ecs networking: dns-search" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --dns-search example.com alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].dnsSearchDomains[0]')" == "example.com" ]]
}

@test "ecs networking: hostname" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --hostname myhost alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].hostname')" == "myhost" ]]
}

@test "ecs networking: publish" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs -p 8080:80 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].portMappings[0].containerPort')" == "80" ]]
  [[ "$(jq_s '.containerDefinitions[0].portMappings[0].hostPort')" == "8080" ]]
}

@test "ecs networking: publish with protocol" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs -p 8080:80/udp alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].portMappings[0].protocol')" == "udp" ]]
}

@test "ecs networking: network mode host" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --network host alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.networkMode')" == "host" ]]
}

@test "ecs networking: network mode bridge" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --network bridge alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.networkMode')" == "bridge" ]]
}

@test "ecs networking: custom network maps to awsvpc" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --network mynetwork alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.networkMode')" == "awsvpc" ]]
}

@test "ecs networking: link" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --link db:database alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].links[0]')" == "db:database" ]]
}

# ECS Resource Constraints

@test "ecs resources: cpu-shares" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --cpu-shares 512 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].cpu')" == "512" ]]
}

@test "ecs resources: cpus at task level" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --cpus 2 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.cpu')" == "2048" ]]
}

@test "ecs resources: memory" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --memory 536870912 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].memory')" == "512" ]]
  [[ "$(jq_s '.memory')" == "512" ]]
}

@test "ecs resources: memory-reservation" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --memory-reservation 268435456 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].memoryReservation')" == "256" ]]
}

@test "ecs resources: ulimits" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --ulimit nofile=1024:2048 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].ulimits[0].name')" == "nofile" ]]
  [[ "$(jq_s '.containerDefinitions[0].ulimits[0].softLimit')" == "1024" ]]
  [[ "$(jq_s '.containerDefinitions[0].ulimits[0].hardLimit')" == "2048" ]]
}

@test "ecs resources: ulimits single value" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --ulimit nofile=1024 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].ulimits[0].softLimit')" == "1024" ]]
  [[ "$(jq_s '.containerDefinitions[0].ulimits[0].hardLimit')" == "1024" ]]
}

@test "ecs resources: shm-size" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --shm-size 67108864 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].linuxParameters.sharedMemorySize')" == "64" ]]
}

# ECS Environment and Labels

@test "ecs environment: env" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs -e FOO=bar -e BAZ=qux alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].environment | length')" == "2" ]]
  [[ "$(jq_s '.containerDefinitions[0].environment[0].name')" == "FOO" ]]
  [[ "$(jq_s '.containerDefinitions[0].environment[0].value')" == "bar" ]]
}

@test "ecs labels: docker-labels" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs -l com.example.key=value alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].dockerLabels."com.example.key"')" == "value" ]]
}

# ECS Security and Linux Parameters

@test "ecs security: cap-add" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --cap-add NET_ADMIN alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].linuxParameters.capabilities.add[0]')" == "NET_ADMIN" ]]
}

@test "ecs security: cap-drop" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --cap-drop ALL alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].linuxParameters.capabilities.drop[0]')" == "ALL" ]]
}

@test "ecs security: privileged" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --privileged alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].privileged')" == "true" ]]
}

@test "ecs security: read-only" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --read-only alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].readonlyRootFilesystem')" == "true" ]]
}

@test "ecs security: security-opt" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --security-opt no-new-privileges alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].dockerSecurityOptions[0]')" == "no-new-privileges" ]]
}

@test "ecs security: init" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --init alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].linuxParameters.initProcessEnabled')" == "true" ]]
}

@test "ecs security: user" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --user 1000:1000 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].user')" == "1000:1000" ]]
}

# ECS Health Check

@test "ecs healthcheck: basic" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs \
    --health-cmd "curl -f http://localhost/" \
    --health-interval 30s \
    --health-timeout 10s \
    --health-retries 3 \
    --health-start-period 5s \
    alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].healthCheck.command[0]')" == "CMD-SHELL" ]]
  [[ "$(jq_s '.containerDefinitions[0].healthCheck.command[1]')" == "curl -f http://localhost/" ]]
  [[ "$(jq_s '.containerDefinitions[0].healthCheck.interval')" == "30" ]]
  [[ "$(jq_s '.containerDefinitions[0].healthCheck.timeout')" == "10" ]]
  [[ "$(jq_s '.containerDefinitions[0].healthCheck.retries')" == "3" ]]
  [[ "$(jq_s '.containerDefinitions[0].healthCheck.startPeriod')" == "5" ]]
}

# ECS Volumes

@test "ecs volumes: bind mount" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs -v /host/path:/container/path alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].mountPoints[0].containerPath')" == "/container/path" ]]
  [[ "$(jq_s '.containerDefinitions[0].mountPoints[0].sourceVolume')" == "volume-0" ]]
  [[ "$(jq_s '.volumes[0].host.sourcePath')" == "/host/path" ]]
}

@test "ecs volumes: bind mount read-only" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs -v /host/path:/container/path:ro alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].mountPoints[0].readOnly')" == "true" ]]
}

@test "ecs volumes: volumes-from" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --volumes-from mycontainer alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].volumesFrom[0].sourceContainer')" == "mycontainer" ]]
}

@test "ecs volumes: volumes-from read-only" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --volumes-from mycontainer:ro alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].volumesFrom[0].readOnly')" == "true" ]]
}

# ECS Logging

@test "ecs logging: log-driver and log-opt" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --log-driver awslogs --log-opt awslogs-group=mygroup --log-opt awslogs-region=us-east-1 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].logConfiguration.logDriver')" == "awslogs" ]]
  [[ "$(jq_s '.containerDefinitions[0].logConfiguration.options."awslogs-group"')" == "mygroup" ]]
  [[ "$(jq_s '.containerDefinitions[0].logConfiguration.options."awslogs-region"')" == "us-east-1" ]]
}

# ECS Lifecycle

@test "ecs lifecycle: stop-timeout" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --stop-timeout 30 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].stopTimeout')" == "30" ]]
}

@test "ecs lifecycle: interactive" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs -i alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].interactive')" == "true" ]]
}

@test "ecs lifecycle: tty" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs -t alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].pseudoTerminal')" == "true" ]]
}

@test "ecs lifecycle: workdir" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --workdir /app alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].workingDirectory')" == "/app" ]]
}

# ECS Namespace and isolation

@test "ecs namespace: pid" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --pid host alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.pidMode')" == "host" ]]
}

@test "ecs namespace: ipc" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --ipc host alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.ipcMode')" == "host" ]]
}

# ECS Sysctl

@test "ecs sysctl: system controls" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --sysctl net.core.somaxconn=1024 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].systemControls[0].namespace')" == "net.core.somaxconn" ]]
  [[ "$(jq_s '.containerDefinitions[0].systemControls[0].value')" == "1024" ]]
}

# ECS Platform

@test "ecs platform: linux/amd64" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --platform linux/amd64 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.runtimePlatform.operatingSystemFamily')" == "LINUX" ]]
  [[ "$(jq_s '.runtimePlatform.cpuArchitecture')" == "X86_64" ]]
}

@test "ecs platform: linux/arm64" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --platform linux/arm64 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.runtimePlatform.cpuArchitecture')" == "ARM64" ]]
}

# ECS Device

@test "ecs device: basic device mapping" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --device /dev/sda:/dev/xvdc alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].linuxParameters.devices[0].hostPath')" == "/dev/sda" ]]
  [[ "$(jq_s '.containerDefinitions[0].linuxParameters.devices[0].containerPath')" == "/dev/xvdc" ]]
}

# ECS GPUs

@test "ecs gpus: all gpus" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --gpus all alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.containerDefinitions[0].resourceRequirements[0].type')" == "GPU" ]]
  [[ "$(jq_s '.containerDefinitions[0].resourceRequirements[0].value')" == "1" ]]
}

# ECS-specific flags

@test "ecs specific: task role arn" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --dre-ecs-task-role-arn "arn:aws:iam::123456789012:role/my-role" alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.taskRoleArn')" == "arn:aws:iam::123456789012:role/my-role" ]]
}

@test "ecs specific: execution role arn" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --dre-ecs-execution-role-arn "arn:aws:iam::123456789012:role/exec-role" alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.executionRoleArn')" == "arn:aws:iam::123456789012:role/exec-role" ]]
}

@test "ecs specific: launch type" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --dre-ecs-launch-type FARGATE alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.requiresCompatibilities[0]')" == "FARGATE" ]]
}

# ECS Unsupported flags

@test "ecs unsupported: blkio-weight warns" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --blkio-weight 300 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --blkio-weight"* ]]
}

@test "ecs unsupported: restart warns" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --restart always alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --restart"* ]]
}

@test "ecs unsupported: cgroupns warns" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --cgroupns host alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --cgroupns"* ]]
}

@test "ecs unsupported: expose warns" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --expose 8080 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --expose"* ]]
}

@test "ecs unsupported: env-file warns" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs --env-file /dev/null alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --env-file"* ]]
}

# ECS Combined flags

@test "ecs combined: multiple flags together" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs \
    --dre-project myapp \
    --name mycontainer \
    --hostname myhost \
    -e FOO=bar \
    -p 8080:80 \
    -v /data:/data:ro \
    --cpu-shares 512 \
    --cap-add NET_ADMIN \
    --init \
    --read-only \
    -l com.example=test \
    alpine:latest echo hello
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.family')" == "myapp" ]]
  [[ "$(jq_s '.containerDefinitions[0].name')" == "mycontainer" ]]
  [[ "$(jq_s '.containerDefinitions[0].hostname')" == "myhost" ]]
  [[ "$(jq_s '.containerDefinitions[0].image')" == "alpine:latest" ]]
  [[ "$(jq_s '.containerDefinitions[0].command[0]')" == "echo" ]]
  [[ "$(jq_s '.containerDefinitions[0].essential')" == "true" ]]
  [[ "$(jq_s '.containerDefinitions[0].environment[0].name')" == "FOO" ]]
  [[ "$(jq_s '.containerDefinitions[0].portMappings[0].containerPort')" == "80" ]]
  [[ "$(jq_s '.containerDefinitions[0].mountPoints[0].readOnly')" == "true" ]]
  [[ "$(jq_s '.containerDefinitions[0].cpu')" == "512" ]]
  [[ "$(jq_s '.containerDefinitions[0].linuxParameters.capabilities.add[0]')" == "NET_ADMIN" ]]
  [[ "$(jq_s '.containerDefinitions[0].linuxParameters.initProcessEnabled')" == "true" ]]
  [[ "$(jq_s '.containerDefinitions[0].readonlyRootFilesystem')" == "true" ]]
  [[ "$(jq_s '.containerDefinitions[0].dockerLabels."com.example"')" == "test" ]]
}

# ==========================================
# ECS CloudFormation Tests
# ==========================================

@test "ecs-cfn basic: valid yaml output" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs-cfn alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.AWSTemplateFormatVersion')" == "2010-09-09" ]]
}

@test "ecs-cfn basic: has task definition resource" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs-cfn alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.Resources.TaskDefinition.Type')" == "AWS::ECS::TaskDefinition" ]]
}

@test "ecs-cfn basic: image in properties" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs-cfn alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.Resources.TaskDefinition.Properties.ContainerDefinitions[0].Image')" == "alpine:latest" ]]
}

@test "ecs-cfn basic: family in properties" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs-cfn --dre-project myapp alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.Resources.TaskDefinition.Properties.Family')" == "myapp" ]]
}

@test "ecs-cfn basic: command in properties" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs-cfn alpine:latest echo hello
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.Resources.TaskDefinition.Properties.ContainerDefinitions[0].Command[0]')" == "echo" ]]
}

@test "ecs-cfn networking: port mappings use PascalCase" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs-cfn -p 8080:80 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.Resources.TaskDefinition.Properties.ContainerDefinitions[0].PortMappings[0].ContainerPort')" == "80" ]]
  [[ "$(yq_s '.Resources.TaskDefinition.Properties.ContainerDefinitions[0].PortMappings[0].HostPort')" == "8080" ]]
}

@test "ecs-cfn specific: launch type" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format ecs-cfn --dre-ecs-launch-type FARGATE alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(yq_s '.Resources.TaskDefinition.Properties.RequiresCompatibilities[0]')" == "FARGATE" ]]
}

# Nomad JSON Basic Tests

@test "nomad-json basic: image only" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.image')" == "alpine:latest" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Driver')" == "docker" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Name')" == "app" ]]
  [[ "$(jq_s '.Job.Type')" == "service" ]]
}

@test "nomad-json basic: valid json output" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json alpine:latest
  [[ "$status" -eq 0 ]]
  echo "$output" | jq . >/dev/null 2>&1
}

@test "nomad-json basic: image with command" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json alpine:latest echo hello
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.args[0]')" == "echo" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.args[1]')" == "hello" ]]
}

@test "nomad-json basic: job name from project" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --dre-project myapp alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.Name')" == "myapp" ]]
  [[ "$(jq_s '.Job.ID')" == "myapp" ]]
}

@test "nomad-json basic: task name from --name" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --name mycontainer alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Name')" == "mycontainer" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Name')" == "mycontainer" ]]
}

@test "nomad-json basic: job name falls back to container name" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --name mycontainer alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.Name')" == "mycontainer" ]]
}

@test "nomad-json basic: entrypoint" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --entrypoint /bin/sh alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.entrypoint[0]')" == "/bin/sh" ]]
}

# Nomad JSON Networking

@test "nomad-json networking: add-host" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --add-host "myhost:192.168.1.1" alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.extra_hosts[0]')" == "myhost:192.168.1.1" ]]
}

@test "nomad-json networking: dns" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --dns 8.8.8.8 --dns 8.8.4.4 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.dns_servers[0]')" == "8.8.8.8" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.dns_servers[1]')" == "8.8.4.4" ]]
}

@test "nomad-json networking: dns-search" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --dns-search example.com alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.dns_search_domains[0]')" == "example.com" ]]
}

@test "nomad-json networking: hostname" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --hostname myhost alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.hostname')" == "myhost" ]]
}

@test "nomad-json networking: publish reserved port" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json -p 8080:80 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Networks[0].ReservedPorts[0].Label')" == "port_80" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Networks[0].ReservedPorts[0].To')" == "80" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Networks[0].ReservedPorts[0].Value')" == "8080" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.ports[0]')" == "port_80" ]]
}

@test "nomad-json networking: publish dynamic port" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json -p 80 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Networks[0].DynamicPorts[0].Label')" == "port_80" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Networks[0].DynamicPorts[0].To')" == "80" ]]
}

@test "nomad-json networking: publish with protocol" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json -p 8080:80/udp alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Networks[0].ReservedPorts[0].Label')" == "port_80_udp" ]]
}

@test "nomad-json networking: network host" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --network host alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Networks[0].Mode')" == "host" ]]
}

@test "nomad-json networking: network bridge" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --network bridge alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Networks[0].Mode')" == "bridge" ]]
}

@test "nomad-json networking: mac-address" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --mac-address 02:42:ac:11:00:02 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.mac_address')" == "02:42:ac:11:00:02" ]]
}

# Nomad JSON Resources

@test "nomad-json resources: cpus to MHz" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --cpus 2 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Resources.CPU')" == "2000" ]]
}

@test "nomad-json resources: cpu-shares to MHz" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --cpu-shares 1024 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Resources.CPU')" == "1000" ]]
}

@test "nomad-json resources: memory to MB" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --memory 536870912 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Resources.MemoryMB')" == "512" ]]
}

# Nomad JSON Env and Labels

@test "nomad-json env: env vars" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json -e FOO=bar -e BAZ=qux alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Env.FOO')" == "bar" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Env.BAZ')" == "qux" ]]
}

@test "nomad-json labels: docker labels" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json -l com.example.key=value alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.labels."com.example.key"')" == "value" ]]
}

# Nomad JSON Security

@test "nomad-json security: cap-add" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --cap-add NET_ADMIN alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.cap_add[0]')" == "NET_ADMIN" ]]
}

@test "nomad-json security: cap-drop" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --cap-drop ALL alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.cap_drop[0]')" == "ALL" ]]
}

@test "nomad-json security: privileged" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --privileged alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.privileged')" == "true" ]]
}

@test "nomad-json security: read-only" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --read-only alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.readonly_rootfs')" == "true" ]]
}

@test "nomad-json security: security-opt" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --security-opt no-new-privileges alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.security_opt[0]')" == "no-new-privileges" ]]
}

@test "nomad-json security: user" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --user 1000:1000 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].User')" == "1000:1000" ]]
}

# Nomad JSON Volumes

@test "nomad-json volumes: bind mount" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json -v /host:/container alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.volumes[0]')" == "/host:/container" ]]
}

@test "nomad-json volumes: read-only volume" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json -v /host:/container:ro alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.volumes[0]')" == "/host:/container:ro" ]]
}

# Nomad JSON Docker Driver Config

@test "nomad-json config: tty" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --tty alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.tty')" == "true" ]]
}

@test "nomad-json config: interactive" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --interactive alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.interactive')" == "true" ]]
}

@test "nomad-json config: workdir" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --workdir /app alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.work_dir')" == "/app" ]]
}

@test "nomad-json config: sysctl" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --sysctl net.core.somaxconn=16384 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.sysctl."net.core.somaxconn"')" == "16384" ]]
}

@test "nomad-json config: shm-size" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --shm-size 67108864 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.shm_size')" == "67108864" ]]
}

@test "nomad-json config: log driver and opts" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --log-driver json-file --log-opt max-size=10m alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.logging.type')" == "json-file" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.logging.config."max-size"')" == "10m" ]]
}

@test "nomad-json config: ulimit" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --ulimit nofile=1024:2048 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.ulimit.nofile')" == "1024:2048" ]]
}

@test "nomad-json config: device" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --device /dev/sda:/dev/xvda:rwm alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.devices[0].host_path')" == "/dev/sda" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.devices[0].container_path')" == "/dev/xvda" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.devices[0].cgroup_permissions')" == "rwm" ]]
}

# Nomad JSON Signal and Timeout

@test "nomad-json signal: stop-signal to KillSignal" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --stop-signal SIGINT alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].KillSignal')" == "SIGINT" ]]
}

@test "nomad-json signal: stop-timeout to KillTimeout in ns" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --stop-timeout 30 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].KillTimeout')" == "30000000000" ]]
}

# Nomad healthcheck

@test "nomad-json healthcheck: basic" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json \
    --health-cmd "curl -f http://localhost/" \
    --health-interval 30s \
    --health-timeout 10s \
    --health-retries 3 \
    --health-start-period 5s \
    alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Services[0].Name')" == "app" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Services[0].Provider')" == "consul" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Services[0].Checks[0].Type')" == "script" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Services[0].Checks[0].Command')" == "curl" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Services[0].Checks[0].Args[0]')" == "-f" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Services[0].Checks[0].Args[1]')" == "http://localhost/" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Services[0].Checks[0].TaskName')" == "app" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Services[0].Checks[0].Interval')" == "30000000000" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Services[0].Checks[0].Timeout')" == "10000000000" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Services[0].Checks[0].CheckRestart.Limit')" == "3" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Services[0].Checks[0].CheckRestart.Grace')" == "5000000000" ]]
}

@test "nomad-json healthcheck: health-cmd only" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --health-cmd "/bin/true" alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Services[0].Checks[0].Type')" == "script" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Services[0].Checks[0].Command')" == "/bin/true" ]]
}

@test "nomad-json healthcheck: health-interval without health-cmd warns" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --health-interval 30s alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"--health-interval has no effect without --health-cmd"* ]]
}

@test "nomad-json healthcheck: no-healthcheck sets docker driver healthchecks.disable" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --no-healthcheck alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.healthchecks.disable')" == "true" ]]
}

# Nomad-specific flags

@test "nomad-json specific: datacenter single" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --dre-nomad-datacenter east alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.Datacenters[0]')" == "east" ]]
}

@test "nomad-json specific: datacenter multiple" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --dre-nomad-datacenter east --dre-nomad-datacenter west alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.Datacenters[0]')" == "east" ]]
  [[ "$(jq_s '.Job.Datacenters[1]')" == "west" ]]
}

@test "nomad-json specific: region" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --dre-nomad-region us-east alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.Region')" == "us-east" ]]
}

@test "nomad-json specific: namespace" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --dre-nomad-namespace dev alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.Namespace')" == "dev" ]]
}

@test "nomad-json specific: job type batch" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --dre-nomad-type batch alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.Type')" == "batch" ]]
}

@test "nomad-json specific: count" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --dre-nomad-count 3 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Count')" == "3" ]]
}

# Nomad HCL Output

@test "nomad hcl: basic structure" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad --dre-project myapp alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(hcl_s 'job.myapp.type')" == "service" ]]
  [[ "$(hcl_s 'job.myapp.datacenters[0]')" == "dc1" ]]
  [[ "$(hcl_s 'job.myapp.group.app.count')" == "1" ]]
  [[ "$(hcl_s 'job.myapp.group.app.task.app.driver')" == "docker" ]]
  [[ "$(hcl_s 'job.myapp.group.app.task.app.config.image')" == "alpine:latest" ]]
}

@test "nomad hcl: port block" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad -p 8080:80 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(hcl_s 'job.app.group.app.network.mode')" == "bridge" ]]
  [[ "$(hcl_s 'job.app.group.app.network.port.port_80.static')" == "8080" ]]
  [[ "$(hcl_s 'job.app.group.app.network.port.port_80.to')" == "80" ]]
}

@test "nomad hcl: env block" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad -e FOO=bar alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(hcl_s 'job.app.group.app.task.app.env.FOO')" == "bar" ]]
}

@test "nomad hcl: resources block" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad --cpus 1 --memory 536870912 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(hcl_s 'job.app.group.app.task.app.resources.cpu')" == "1000" ]]
  [[ "$(hcl_s 'job.app.group.app.task.app.resources.memory')" == "512" ]]
}

@test "nomad hcl: kill signal and timeout" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad --stop-signal SIGINT --stop-timeout 30 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(hcl_s 'job.app.group.app.task.app.kill_signal')" == "SIGINT" ]]
  [[ "$(hcl_s 'job.app.group.app.task.app.kill_timeout')" == "30s" ]]
}

@test "nomad hcl: labels with dotted key" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad -l com.example.key=value alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(hcl_s "job.app.group.app.task.app.config.labels['com.example.key']")" == "value" ]]
}

@test "nomad hcl: healthcheck service and check blocks" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad \
    --health-cmd "curl -f http://localhost/" \
    --health-interval 30s \
    --health-timeout 10s \
    --health-retries 3 \
    --health-start-period 5s \
    alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(hcl_s 'job.app.group.app.service.name')" == "app" ]]
  [[ "$(hcl_s 'job.app.group.app.service.provider')" == "consul" ]]
  [[ "$(hcl_s 'job.app.group.app.service.check.name')" == "app-health" ]]
  [[ "$(hcl_s 'job.app.group.app.service.check.type')" == "script" ]]
  [[ "$(hcl_s 'job.app.group.app.service.check.command')" == "curl" ]]
  [[ "$(hcl_s 'job.app.group.app.service.check.args[0]')" == "-f" ]]
  [[ "$(hcl_s 'job.app.group.app.service.check.args[1]')" == "http://localhost/" ]]
  [[ "$(hcl_s 'job.app.group.app.service.check.task')" == "app" ]]
  [[ "$(hcl_s 'job.app.group.app.service.check.interval')" == "30s" ]]
  [[ "$(hcl_s 'job.app.group.app.service.check.timeout')" == "10s" ]]
  [[ "$(hcl_s 'job.app.group.app.service.check.check_restart.limit')" == "3" ]]
  [[ "$(hcl_s 'job.app.group.app.service.check.check_restart.grace')" == "5s" ]]
}

# Nomad driver config extras (direct docker driver field mappings)

@test "nomad-json driver config: cpuset-cpus" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --cpuset-cpus 0-3 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.cpuset_cpus')" == "0-3" ]]
}

@test "nomad-json driver config: init" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --init alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.init')" == "true" ]]
}

@test "nomad-json driver config: pids-limit" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --pids-limit 100 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.pids_limit')" == "100" ]]
}

@test "nomad-json driver config: runtime" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --runtime runc alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.runtime')" == "runc" ]]
}

@test "nomad-json driver config: group-add" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --group-add wheel --group-add disk alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.group_add[0]')" == "wheel" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.group_add[1]')" == "disk" ]]
}

@test "nomad-json driver config: ip and ip6" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --ip 10.0.0.5 --ip6 ::1 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.ipv4_address')" == "10.0.0.5" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.ipv6_address')" == "::1" ]]
}

@test "nomad-json driver config: isolation" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --isolation hyperv alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.isolation')" == "hyperv" ]]
}

@test "nomad-json driver config: uts" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --uts host alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.uts_mode')" == "host" ]]
}

@test "nomad-json driver config: network-alias" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --network-alias web --network-alias api alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.network_aliases[0]')" == "web" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.network_aliases[1]')" == "api" ]]
}

@test "nomad-json driver config: oom-score-adj" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --oom-score-adj -500 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.oom_score_adj')" == "-500" ]]
}

@test "nomad-json driver config: volume-driver" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --volume-driver local alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.volume_driver')" == "local" ]]
}

@test "nomad-json driver config: cgroupns" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --cgroupns host alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.cgroupns')" == "host" ]]
}

@test "nomad-json driver config: cpu-period" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --cpu-period 100000 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.cpu_cfs_period')" == "100000" ]]
}

@test "nomad-json driver config: pull always sets force_pull" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --pull always alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.force_pull')" == "true" ]]
}

@test "nomad-json driver config: pull never warns" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --pull never alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"--pull never is not supported"* ]]
}

# Nomad restart policy (maps to group-level restart stanza)

@test "nomad-json restart: on-failure with retries" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --restart on-failure:5 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].RestartPolicy.Attempts')" == "5" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].RestartPolicy.Mode')" == "fail" ]]
}

@test "nomad-json restart: on-failure without retries" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --restart on-failure alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].RestartPolicy.Mode')" == "fail" ]]
}

@test "nomad-json restart: always approximates with mode=delay" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --restart always alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].RestartPolicy.Mode')" == "delay" ]]
  [[ "$output" == *"approximated by Nomad mode=delay"* ]]
}

@test "nomad-json restart: no" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --restart no alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].RestartPolicy.Mode')" == "fail" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].RestartPolicy.Attempts')" == "0" ]]
}

@test "nomad hcl: restart stanza" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad --restart on-failure:3 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(hcl_s 'job.app.group.app.restart.attempts')" == "3" ]]
  [[ "$(hcl_s 'job.app.group.app.restart.mode')" == "fail" ]]
}

# Nomad GPU device stanza

@test "nomad-json gpus: integer count" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --gpus 2 nvidia/cuda:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Resources.Devices[0].Name')" == "nvidia/gpu" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Resources.Devices[0].Count')" == "2" ]]
}

@test "nomad-json gpus: all" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --gpus all nvidia/cuda:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Resources.Devices[0].Name')" == "nvidia/gpu" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Resources.Devices[0].Count')" == "1" ]]
}

@test "nomad hcl: device block" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad --gpus 2 nvidia/cuda:latest
  [[ "$status" -eq 0 ]]
  [[ "$(hcl_s 'job.app.group.app.task.app.resources.device["nvidia/gpu"].count')" == "2" ]]
}

# Nomad mount and tmpfs blocks

@test "nomad-json mount: bind" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json \
    --mount type=bind,source=/host,target=/container,readonly \
    alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.mount[0].type')" == "bind" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.mount[0].source')" == "/host" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.mount[0].target')" == "/container" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.mount[0].readonly')" == "true" ]]
}

@test "nomad-json mount: volume with labels" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json \
    --mount type=volume,source=data,target=/data,volume-label=env=prod \
    alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.mount[0].type')" == "volume" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.mount[0].source')" == "data" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.mount[0].volume_options.labels.env')" == "prod" ]]
}

@test "nomad-json mount: tmpfs" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json \
    --mount type=tmpfs,target=/scratch,tmpfs-size=67108864 \
    alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.mount[0].type')" == "tmpfs" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.mount[0].target')" == "/scratch" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.mount[0].tmpfs_options.size')" == "67108864" ]]
}

@test "nomad-json tmpfs: with size suffix" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --tmpfs '/run:size=64m,mode=1770' alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.mount[0].type')" == "tmpfs" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.mount[0].target')" == "/run" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.mount[0].tmpfs_options.size')" == "67108864" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.mount[0].tmpfs_options.mode')" == "1016" ]]
}

@test "nomad-json tmpfs: plain path" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --tmpfs /tmp alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.mount[0].type')" == "tmpfs" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.mount[0].target')" == "/tmp" ]]
}

@test "nomad-json mount: multiple mounts" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json \
    --mount type=bind,source=/host1,target=/c1 \
    --mount type=volume,source=data,target=/data \
    alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.mount[0].source')" == "/host1" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.mount[1].source')" == "data" ]]
}

# Nomad remaining unsupported flag warnings

@test "nomad-json unsupported: expose emits warning" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --expose 8080 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --expose property in nomad job spec"* ]]
}

@test "nomad-json unsupported: blkio-weight emits warning" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --blkio-weight 500 alpine:latest
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --blkio-weight property in nomad job spec"* ]]
}

# Nomad combined flags

@test "nomad-json combined: realistic app" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --dre-project web \
    -e DB_HOST=db.example.com -p 8080:80 --cpus 1 --memory 536870912 \
    --hostname web1 --cap-add NET_ADMIN nginx:latest
  [[ "$status" -eq 0 ]]
  [[ "$(jq_s '.Job.Name')" == "web" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.image')" == "nginx:latest" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.hostname')" == "web1" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Config.cap_add[0]')" == "NET_ADMIN" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Env.DB_HOST')" == "db.example.com" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Resources.CPU')" == "1000" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Tasks[0].Resources.MemoryMB')" == "512" ]]
  [[ "$(jq_s '.Job.TaskGroups[0].Networks[0].ReservedPorts[0].Value')" == "8080" ]]
}

# Nomad CLI validation tests: run output through `nomad job validate` to
# confirm it matches Nomad's own schema. These tests skip when the nomad
# binary is not installed (e.g., local dev without brew install nomad).

@test "nomad validate: minimal hcl" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad --dre-project myapp alpine:latest
  [[ "$status" -eq 0 ]]
  nomad_validate_hcl
}

@test "nomad validate: minimal json" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --dre-project myapp alpine:latest
  [[ "$status" -eq 0 ]]
  nomad_validate_json
}

@test "nomad validate: hcl with command and env" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad --dre-project worker \
    -e FOO=bar -e BAZ=qux alpine:latest echo hello
  [[ "$status" -eq 0 ]]
  nomad_validate_hcl
}

@test "nomad validate: hcl with reserved and dynamic ports" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad --dre-project web \
    -p 8080:80 -p 443 -p 53:53/udp nginx:latest
  [[ "$status" -eq 0 ]]
  nomad_validate_hcl
}

@test "nomad validate: json with reserved and dynamic ports" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --dre-project web \
    -p 8080:80 -p 443 -p 53:53/udp nginx:latest
  [[ "$status" -eq 0 ]]
  nomad_validate_json
}

@test "nomad validate: hcl with resources and signals" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad --dre-project svc \
    --cpus 1.5 --memory 536870912 --stop-signal SIGINT --stop-timeout 30 alpine:latest
  [[ "$status" -eq 0 ]]
  nomad_validate_hcl
}

@test "nomad validate: hcl with dns volumes workdir" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad --dre-project net \
    --add-host "db:10.0.0.5" --dns 8.8.8.8 --hostname web1 \
    -v /host/data:/data -v /host/logs:/logs:ro --workdir /app alpine:latest
  [[ "$status" -eq 0 ]]
  nomad_validate_hcl
}

@test "nomad validate: hcl with caps and security" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad --dre-project sec \
    --cap-add NET_ADMIN --cap-drop ALL --privileged --read-only \
    --security-opt no-new-privileges --user 1000:1000 alpine:latest
  [[ "$status" -eq 0 ]]
  nomad_validate_hcl
}

@test "nomad validate: hcl with logging and sysctl" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad --dre-project logs \
    --log-driver json-file --log-opt max-size=10m --log-opt max-file=3 \
    --sysctl net.core.somaxconn=16384 --ulimit nofile=1024:2048 \
    --shm-size 67108864 alpine:latest
  [[ "$status" -eq 0 ]]
  nomad_validate_hcl
}

@test "nomad validate: hcl with labels containing dots" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad --dre-project labeled \
    -l com.example.key=value -l plain=true alpine:latest
  [[ "$status" -eq 0 ]]
  nomad_validate_hcl
}

@test "nomad validate: hcl with nomad options" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad --dre-project configured \
    --dre-nomad-datacenter east --dre-nomad-datacenter west \
    --dre-nomad-region us --dre-nomad-namespace dev \
    --dre-nomad-type batch --dre-nomad-count 3 alpine:latest
  [[ "$status" -eq 0 ]]
  nomad_validate_hcl
}

@test "nomad validate: hcl with healthcheck" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad --dre-project healthy \
    --health-cmd "curl -f http://localhost/" --health-interval 30s \
    --health-timeout 10s --health-retries 3 --health-start-period 5s \
    nginx:latest
  [[ "$status" -eq 0 ]]
  nomad_validate_hcl
}

@test "nomad validate: json with healthcheck" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --dre-project healthy \
    --health-cmd "curl -f http://localhost/" --health-interval 30s \
    --health-timeout 10s --health-retries 3 --health-start-period 5s \
    nginx:latest
  [[ "$status" -eq 0 ]]
  nomad_validate_json
}

@test "nomad validate: hcl combined realistic app" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad --dre-project web \
    -e DB_HOST=db.example.com -p 8080:80 --cpus 1 --memory 536870912 \
    --hostname web1 --cap-add NET_ADMIN nginx:latest
  [[ "$status" -eq 0 ]]
  nomad_validate_hcl
}

@test "nomad validate: json combined realistic app" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad-json --dre-project web \
    -e DB_HOST=db.example.com -p 8080:80 --cpus 1 --memory 536870912 \
    --hostname web1 --cap-add NET_ADMIN nginx:latest
  [[ "$status" -eq 0 ]]
  nomad_validate_json
}

@test "nomad validate: hcl with driver config extras" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad --dre-project extras \
    --cpuset-cpus 0-3 --init --pids-limit 100 --runtime runc \
    --group-add wheel --uts host --network-alias web --oom-score-adj -500 \
    --volume-driver local --cgroupns host --cpu-period 100000 --pull always \
    alpine:latest
  [[ "$status" -eq 0 ]]
  nomad_validate_hcl
}

@test "nomad validate: hcl with restart policy" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad --dre-project restarter \
    --restart on-failure:3 alpine:latest
  [[ "$status" -eq 0 ]]
  nomad_validate_hcl
}

@test "nomad validate: hcl with gpus" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad --dre-project gpuapp \
    --gpus 2 nvidia/cuda:latest
  [[ "$status" -eq 0 ]]
  nomad_validate_hcl
}

@test "nomad validate: hcl with mount blocks" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-format nomad --dre-project mounted \
    --mount type=bind,source=/host,target=/container,readonly \
    --mount type=volume,source=data,target=/data \
    --mount type=tmpfs,target=/scratch,tmpfs-size=67108864 \
    --tmpfs '/run:size=64m,mode=1770' \
    alpine:latest
  [[ "$status" -eq 0 ]]
  nomad_validate_hcl
}
