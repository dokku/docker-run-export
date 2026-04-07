#!/usr/bin/env bats

export SYSTEM_NAME="$(uname -s | tr '[:upper:]' '[:lower:]')"
export DOCKER_RUN_EXPORT_BIN="build/$SYSTEM_NAME/docker-run-export-amd64"

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
  echo "$output" | jq . > /dev/null 2>&1
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
