#!/usr/bin/env bats

export SYSTEM_NAME="$(uname -s | tr '[:upper:]' '[:lower:]')"
export DOCKER_RUN_EXPORT_BIN="build/$SYSTEM_NAME/docker-run-export-amd64"

setup_file() {
  make prebuild $DOCKER_RUN_EXPORT_BIN
}

teardown_file() {
  make clean
}

# Basic functionality

@test "basic: image only" {
  run $DOCKER_RUN_EXPORT_BIN run alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"image: alpine:latest"* ]]
}

@test "basic: image with command" {
  run $DOCKER_RUN_EXPORT_BIN run alpine:latest echo hello
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"image: alpine:latest"* ]]
  [[ "$output" == *"command:"* ]]
  [[ "$output" == *"- echo"* ]]
  [[ "$output" == *"- hello"* ]]
}

@test "basic: project name" {
  run $DOCKER_RUN_EXPORT_BIN run --dre-project myproject alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"name: myproject"* ]]
}

@test "basic: container name" {
  run $DOCKER_RUN_EXPORT_BIN run --name mycontainer alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"container_name: mycontainer"* ]]
}

# Networking

@test "networking: add-host" {
  run $DOCKER_RUN_EXPORT_BIN run --add-host "myhost:192.168.1.1" alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"extra_hosts"* ]]
  [[ "$output" == *"myhost"* ]]
  [[ "$output" == *"192.168.1.1"* ]]
}

@test "networking: dns" {
  run $DOCKER_RUN_EXPORT_BIN run --dns 8.8.8.8 --dns 8.8.4.4 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"dns:"* ]]
  [[ "$output" == *"8.8.8.8"* ]]
  [[ "$output" == *"8.8.4.4"* ]]
}

@test "networking: dns-option" {
  run $DOCKER_RUN_EXPORT_BIN run --dns-option ndots:5 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"dns_opt:"* ]]
  [[ "$output" == *"ndots:5"* ]]
}

@test "networking: dns-search" {
  run $DOCKER_RUN_EXPORT_BIN run --dns-search example.com alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"dns_search:"* ]]
  [[ "$output" == *"example.com"* ]]
}

@test "networking: hostname" {
  run $DOCKER_RUN_EXPORT_BIN run --hostname myhost alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"hostname: myhost"* ]]
}

@test "networking: domainname" {
  run $DOCKER_RUN_EXPORT_BIN run --domainname example.com alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"domainname: example.com"* ]]
}

@test "networking: mac-address" {
  run $DOCKER_RUN_EXPORT_BIN run --mac-address 92:d0:c6:0a:29:33 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"mac_address: 92:d0:c6:0a:29:33"* ]]
}

@test "networking: publish" {
  run $DOCKER_RUN_EXPORT_BIN run -p 8080:80 -p 443:443 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"ports:"* ]]
}

@test "networking: expose" {
  run $DOCKER_RUN_EXPORT_BIN run --expose 8080 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"expose:"* ]]
  [[ "$output" == *"8080"* ]]
}

@test "networking: network" {
  run $DOCKER_RUN_EXPORT_BIN run --network mynetwork alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"networks:"* ]]
  [[ "$output" == *"mynetwork"* ]]
}

@test "networking: network-alias" {
  run $DOCKER_RUN_EXPORT_BIN run --network-alias myalias alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"aliases:"* ]]
  [[ "$output" == *"myalias"* ]]
}

@test "networking: ip" {
  run $DOCKER_RUN_EXPORT_BIN run --ip 172.30.100.104 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"ipv4_address: 172.30.100.104"* ]]
}

@test "networking: ip6" {
  run $DOCKER_RUN_EXPORT_BIN run --ip6 "2001:db8::33" alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"ipv6_address:"* ]]
  [[ "$output" == *"2001:db8::33"* ]]
}

@test "networking: link" {
  run $DOCKER_RUN_EXPORT_BIN run --link db:database alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"links:"* ]]
  [[ "$output" == *"db:database"* ]]
}

@test "networking: link-local-ip" {
  run $DOCKER_RUN_EXPORT_BIN run --link-local-ip 169.254.1.1 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"link_local_ips:"* ]]
  [[ "$output" == *"169.254.1.1"* ]]
}

# Volumes

@test "volumes: bind mount" {
  run $DOCKER_RUN_EXPORT_BIN run -v /host/path:/container/path alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"volumes:"* ]]
  [[ "$output" == *"source: /host/path"* ]]
  [[ "$output" == *"target: /container/path"* ]]
  [[ "$output" == *"type: bind"* ]]
}

@test "volumes: bind mount read-only" {
  run $DOCKER_RUN_EXPORT_BIN run -v /host/path:/container/path:ro alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"read_only: true"* ]]
}

@test "volumes: named volume" {
  run $DOCKER_RUN_EXPORT_BIN run -v /data alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"type: volume"* ]]
  [[ "$output" == *"target: /data"* ]]
}

@test "volumes: mount bind" {
  run $DOCKER_RUN_EXPORT_BIN run --mount type=bind,source=/host,target=/container alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"type: bind"* ]]
  [[ "$output" == *"source: /host"* ]]
  [[ "$output" == *"target: /container"* ]]
}

@test "volumes: mount tmpfs" {
  run $DOCKER_RUN_EXPORT_BIN run --mount type=tmpfs,target=/tmp,tmpfs-size=100m alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"type: tmpfs"* ]]
  [[ "$output" == *"target: /tmp"* ]]
}

@test "volumes: tmpfs" {
  run $DOCKER_RUN_EXPORT_BIN run --tmpfs /tmp:size=100m alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"type: tmpfs"* ]]
  [[ "$output" == *"target: /tmp"* ]]
}

@test "volumes: volumes-from" {
  run $DOCKER_RUN_EXPORT_BIN run --volumes-from mycontainer alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"volumes_from:"* ]]
  [[ "$output" == *"mycontainer"* ]]
}

@test "volumes: volume-driver" {
  run $DOCKER_RUN_EXPORT_BIN run --volume-driver local alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"volume_driver: local"* ]]
}

@test "volumes: read-only" {
  run $DOCKER_RUN_EXPORT_BIN run --read-only alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"read_only: true"* ]]
}

@test "volumes: working directory" {
  run $DOCKER_RUN_EXPORT_BIN run -w /app alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"working_dir: /app"* ]]
}

# Resource constraints

@test "resources: cpus" {
  run $DOCKER_RUN_EXPORT_BIN run --cpus 2 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"cpus: 2"* ]]
  [[ "$output" == *"deploy:"* ]]
  [[ "$output" == *"limits:"* ]]
}

@test "resources: memory" {
  run $DOCKER_RUN_EXPORT_BIN run --memory 512 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"mem_limit:"* ]]
  [[ "$output" == *"deploy:"* ]]
  [[ "$output" == *"limits:"* ]]
}

@test "resources: cpu-shares" {
  run $DOCKER_RUN_EXPORT_BIN run --cpu-shares 512 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"cpu_shares: 512"* ]]
}

@test "resources: cpu-period" {
  run $DOCKER_RUN_EXPORT_BIN run --cpu-period 100000 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"cpu_period: 100000"* ]]
}

@test "resources: cpu-quota" {
  run $DOCKER_RUN_EXPORT_BIN run --cpu-quota 50000 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"cpu_quota: 50000"* ]]
}

@test "resources: cpu-rt-period" {
  run $DOCKER_RUN_EXPORT_BIN run --cpu-rt-period 1000000 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"cpu_rt_period: 1000000"* ]]
}

@test "resources: cpu-rt-runtime" {
  run $DOCKER_RUN_EXPORT_BIN run --cpu-rt-runtime 950000 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"cpu_rt_runtime: 950000"* ]]
}

@test "resources: cpuset-cpus" {
  run $DOCKER_RUN_EXPORT_BIN run --cpuset-cpus 0-3 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"cpuset: 0-3"* ]]
}

@test "resources: memory-reservation" {
  run $DOCKER_RUN_EXPORT_BIN run --memory-reservation 256 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"mem_reservation:"* ]]
}

@test "resources: memory-swap" {
  run $DOCKER_RUN_EXPORT_BIN run --memory-swap 1024 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"memswap_limit:"* ]]
}

@test "resources: blkio-weight" {
  run $DOCKER_RUN_EXPORT_BIN run --blkio-weight 300 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"blkio_config:"* ]]
  [[ "$output" == *"weight: 300"* ]]
}

@test "resources: shm-size" {
  run $DOCKER_RUN_EXPORT_BIN run --shm-size 64 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"shm_size:"* ]]
}

@test "resources: pids-limit" {
  run $DOCKER_RUN_EXPORT_BIN run --pids-limit 100 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"pids_limit: 100"* ]]
}

@test "resources: ulimit" {
  run $DOCKER_RUN_EXPORT_BIN run --ulimit nofile=1024:2048 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"ulimits:"* ]]
  [[ "$output" == *"nofile:"* ]]
  [[ "$output" == *"soft: 1024"* ]]
  [[ "$output" == *"hard: 2048"* ]]
}

# Security and privileges

@test "security: cap-add" {
  run $DOCKER_RUN_EXPORT_BIN run --cap-add NET_ADMIN alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"cap_add:"* ]]
  [[ "$output" == *"NET_ADMIN"* ]]
}

@test "security: cap-drop" {
  run $DOCKER_RUN_EXPORT_BIN run --cap-drop ALL alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"cap_drop:"* ]]
  [[ "$output" == *"ALL"* ]]
}

@test "security: privileged" {
  run $DOCKER_RUN_EXPORT_BIN run --privileged alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"privileged: true"* ]]
}

@test "security: security-opt" {
  run $DOCKER_RUN_EXPORT_BIN run --security-opt no-new-privileges alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"security_opt:"* ]]
  [[ "$output" == *"no-new-privileges"* ]]
}

@test "security: user" {
  run $DOCKER_RUN_EXPORT_BIN run --user 1000:1000 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"user: "* ]]
  [[ "$output" == *"1000:1000"* ]]
}

@test "security: group-add" {
  run $DOCKER_RUN_EXPORT_BIN run --group-add audio alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"group_add:"* ]]
  [[ "$output" == *"audio"* ]]
}

# Namespace and isolation

@test "namespace: cgroupns" {
  run $DOCKER_RUN_EXPORT_BIN run --cgroupns private alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"cgroup: private"* ]]
}

@test "namespace: cgroup-parent" {
  run $DOCKER_RUN_EXPORT_BIN run --cgroup-parent /mygroup alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"cgroup_parent: /mygroup"* ]]
}

@test "namespace: pid" {
  run $DOCKER_RUN_EXPORT_BIN run --pid host alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"pid: host"* ]]
}

@test "namespace: ipc" {
  run $DOCKER_RUN_EXPORT_BIN run --ipc host alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"ipc: host"* ]]
}

@test "namespace: userns" {
  run $DOCKER_RUN_EXPORT_BIN run --userns host alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"userns_mode: host"* ]]
}

@test "namespace: uts" {
  run $DOCKER_RUN_EXPORT_BIN run --uts host alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"uts: host"* ]]
}

@test "namespace: isolation" {
  run $DOCKER_RUN_EXPORT_BIN run --isolation default alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"isolation: default"* ]]
}

# Health check

@test "healthcheck: basic" {
  run $DOCKER_RUN_EXPORT_BIN run --health-cmd "curl -f http://localhost/" --health-interval 30s --health-timeout 10s --health-retries 3 --health-start-period 5s alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"healthcheck:"* ]]
  [[ "$output" == *"test:"* ]]
  [[ "$output" == *"curl"* ]]
  [[ "$output" == *"interval: 30s"* ]]
  [[ "$output" == *"timeout: 10s"* ]]
  [[ "$output" == *"retries: 3"* ]]
  [[ "$output" == *"start_period: 5s"* ]]
}

@test "healthcheck: disable" {
  run $DOCKER_RUN_EXPORT_BIN run --no-healthcheck alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"healthcheck:"* ]]
  [[ "$output" == *"disable: true"* ]]
}

@test "healthcheck: conflict warns" {
  run $DOCKER_RUN_EXPORT_BIN run --no-healthcheck --health-cmd "curl localhost" alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"ignoring --health-cmd"* ]]
  [[ "$output" == *"disable: true"* ]]
}

# Environment and labels

@test "environment: env" {
  run $DOCKER_RUN_EXPORT_BIN run -e FOO=bar -e BAZ=qux alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"environment:"* ]]
  [[ "$output" == *"FOO: bar"* ]]
  [[ "$output" == *"BAZ: qux"* ]]
}

@test "environment: env-file" {
  run $DOCKER_RUN_EXPORT_BIN run --env-file /path/to/.env alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"env_file:"* ]]
  [[ "$output" == *"/path/to/.env"* ]]
}

@test "labels: label" {
  run $DOCKER_RUN_EXPORT_BIN run -l com.example.key=value alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"labels:"* ]]
  [[ "$output" == *"com.example.key: value"* ]]
}

@test "labels: label-file" {
  run $DOCKER_RUN_EXPORT_BIN run --label-file /path/to/labels alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"label_file:"* ]]
  [[ "$output" == *"/path/to/labels"* ]]
}

# Lifecycle and process management

@test "lifecycle: restart" {
  run $DOCKER_RUN_EXPORT_BIN run --restart always alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"restart: always"* ]]
}

@test "lifecycle: restart unless-stopped" {
  run $DOCKER_RUN_EXPORT_BIN run --restart unless-stopped alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"restart: unless-stopped"* ]]
}

@test "lifecycle: restart on-failure" {
  run $DOCKER_RUN_EXPORT_BIN run --restart on-failure:5 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"restart: on-failure:5"* ]]
}

@test "lifecycle: restart default not emitted" {
  run $DOCKER_RUN_EXPORT_BIN run --restart no alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"restart:"* ]]
}

@test "lifecycle: init" {
  run $DOCKER_RUN_EXPORT_BIN run --init alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"init: true"* ]]
}

@test "lifecycle: stop-signal" {
  run $DOCKER_RUN_EXPORT_BIN run --stop-signal SIGINT alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"stop_signal: SIGINT"* ]]
}

@test "lifecycle: stop-signal default not emitted" {
  run $DOCKER_RUN_EXPORT_BIN run --stop-signal SIGTERM alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"stop_signal:"* ]]
}

@test "lifecycle: stop-timeout" {
  run $DOCKER_RUN_EXPORT_BIN run --stop-timeout 30 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"stop_grace_period: 30s"* ]]
}

@test "lifecycle: oom-kill-disable" {
  run $DOCKER_RUN_EXPORT_BIN run --oom-kill-disable alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"oom_kill_disable: true"* ]]
}

@test "lifecycle: oom-score-adj" {
  run $DOCKER_RUN_EXPORT_BIN run --oom-score-adj 500 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"oom_score_adj: 500"* ]]
}

# TTY and stdin

@test "tty: tty" {
  run $DOCKER_RUN_EXPORT_BIN run -t alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"tty: true"* ]]
}

@test "tty: interactive" {
  run $DOCKER_RUN_EXPORT_BIN run -i alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"stdin_open: true"* ]]
}

# Devices

@test "devices: device" {
  run $DOCKER_RUN_EXPORT_BIN run --device /dev/sda:/dev/xvdc:rwm alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"devices:"* ]]
  [[ "$output" == *"source: /dev/sda"* ]]
  [[ "$output" == *"target: /dev/xvdc"* ]]
  [[ "$output" == *"permissions: rwm"* ]]
}

@test "devices: device-cgroup-rule" {
  run $DOCKER_RUN_EXPORT_BIN run --device-cgroup-rule "c 42:* rmw" alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"device_cgroup_rules:"* ]]
  [[ "$output" == *"c 42:* rmw"* ]]
}

# Logging

@test "logging: log-driver and log-opt" {
  run $DOCKER_RUN_EXPORT_BIN run --log-driver json-file --log-opt max-size=10m --log-opt max-file=3 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"log_driver: json-file"* ]]
  [[ "$output" == *"log_opt:"* ]]
  [[ "$output" == *"max-size: 10m"* ]]
  [[ "$output" == *"max-file:"* ]]
}

# Platform and runtime

@test "platform: platform" {
  run $DOCKER_RUN_EXPORT_BIN run --platform linux/amd64 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"platform: linux/amd64"* ]]
}

@test "platform: runtime" {
  run $DOCKER_RUN_EXPORT_BIN run --runtime nvidia alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"runtime: nvidia"* ]]
}

# Entrypoint

@test "entrypoint: entrypoint" {
  run $DOCKER_RUN_EXPORT_BIN run --entrypoint /bin/sh alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"entrypoint:"* ]]
  [[ "$output" == *"/bin/sh"* ]]
}

# Sysctl

@test "sysctl: sysctl" {
  run $DOCKER_RUN_EXPORT_BIN run --sysctl net.core.somaxconn=1024 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"sysctls:"* ]]
  [[ "$output" == *"net.core.somaxconn: \"1024\""* ]]
}

# New flags added in this update

@test "new: annotation" {
  run $DOCKER_RUN_EXPORT_BIN run --annotation com.example.key=value alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"annotations:"* ]]
  [[ "$output" == *"com.example.key: value"* ]]
}

@test "new: pull-policy always" {
  run $DOCKER_RUN_EXPORT_BIN run --pull always alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"pull_policy: always"* ]]
}

@test "new: pull-policy never" {
  run $DOCKER_RUN_EXPORT_BIN run --pull never alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"pull_policy: never"* ]]
}

@test "new: pull-policy default not emitted" {
  run $DOCKER_RUN_EXPORT_BIN run --pull missing alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"pull_policy:"* ]]
}

@test "new: gpus all" {
  run $DOCKER_RUN_EXPORT_BIN run --gpus all alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"gpus:"* ]]
  [[ "$output" == *"capabilities:"* ]]
  [[ "$output" == *"gpu"* ]]
  [[ "$output" == *"count: -1"* ]]
}

@test "new: storage-opt" {
  run $DOCKER_RUN_EXPORT_BIN run --storage-opt size=120G alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"storage_opt:"* ]]
  [[ "$output" == *"size: 120G"* ]]
}

# Unsupported flags should warn

@test "unsupported: attach warns" {
  run $DOCKER_RUN_EXPORT_BIN run -a stdout alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --attach"* ]]
}

@test "unsupported: cidfile warns" {
  run $DOCKER_RUN_EXPORT_BIN run --cidfile /tmp/cid alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --cidfile"* ]]
}

@test "unsupported: cpuset-mems warns" {
  run $DOCKER_RUN_EXPORT_BIN run --cpuset-mems 0-1 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --cpuset-mems"* ]]
}

@test "unsupported: detach warns" {
  run $DOCKER_RUN_EXPORT_BIN run -d alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --detach"* ]]
}

@test "unsupported: detach-keys warns" {
  run $DOCKER_RUN_EXPORT_BIN run --detach-keys ctrl-p alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --detach-keys"* ]]
}

@test "unsupported: kernel-memory warns" {
  run $DOCKER_RUN_EXPORT_BIN run --kernel-memory 128 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --kernel-memory"* ]]
}

@test "unsupported: publish-all warns" {
  run $DOCKER_RUN_EXPORT_BIN run -P alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --publish-all"* ]]
}

@test "unsupported: rm warns" {
  run $DOCKER_RUN_EXPORT_BIN run --rm alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --rm"* ]]
}

@test "unsupported: sig-proxy warns" {
  run $DOCKER_RUN_EXPORT_BIN run --sig-proxy=false alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unable to set --sig-proxy"* ]]
}

# Previously unsupported flags that should now work (no warnings)

@test "now-supported: cgroupns no warning" {
  run $DOCKER_RUN_EXPORT_BIN run --cgroupns private alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"unable to set"* ]]
  [[ "$output" == *"cgroup: private"* ]]
}

@test "now-supported: cpu-period no warning" {
  run $DOCKER_RUN_EXPORT_BIN run --cpu-period 100000 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"unable to set"* ]]
  [[ "$output" == *"cpu_period: 100000"* ]]
}

@test "now-supported: cpu-quota no warning" {
  run $DOCKER_RUN_EXPORT_BIN run --cpu-quota 50000 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"unable to set"* ]]
  [[ "$output" == *"cpu_quota: 50000"* ]]
}

@test "now-supported: cpuset-cpus no warning" {
  run $DOCKER_RUN_EXPORT_BIN run --cpuset-cpus 0-3 alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"unable to set"* ]]
  [[ "$output" == *"cpuset: 0-3"* ]]
}

@test "now-supported: interactive no warning" {
  run $DOCKER_RUN_EXPORT_BIN run -i alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"unable to set"* ]]
  [[ "$output" == *"stdin_open: true"* ]]
}

@test "now-supported: storage-opt no warning" {
  run $DOCKER_RUN_EXPORT_BIN run --storage-opt size=120G alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"unable to set"* ]]
  [[ "$output" == *"storage_opt:"* ]]
}

@test "now-supported: gpus no warning" {
  run $DOCKER_RUN_EXPORT_BIN run --gpus all alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"unable to set"* ]]
  [[ "$output" == *"gpus:"* ]]
}

@test "now-supported: label-file no warning" {
  run $DOCKER_RUN_EXPORT_BIN run --label-file /path/to/labels alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"unable to set"* ]]
  [[ "$output" == *"label_file:"* ]]
}

@test "now-supported: pull always no warning" {
  run $DOCKER_RUN_EXPORT_BIN run --pull always alpine:latest
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"unable to set"* ]]
  [[ "$output" == *"pull_policy: always"* ]]
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
  echo "output: $output"
  echo "status: $status"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"container_name: myapp"* ]]
  [[ "$output" == *"hostname: myhost"* ]]
  [[ "$output" == *"environment:"* ]]
  [[ "$output" == *"ports:"* ]]
  [[ "$output" == *"volumes:"* ]]
  [[ "$output" == *"restart: always"* ]]
  [[ "$output" == *"cpus: 2"* ]]
  [[ "$output" == *"cap_add:"* ]]
  [[ "$output" == *"cap_drop:"* ]]
  [[ "$output" == *"init: true"* ]]
  [[ "$output" == *"read_only: true"* ]]
  [[ "$output" == *"labels:"* ]]
  [[ "$output" == *"image: alpine:latest"* ]]
  [[ "$output" == *"command:"* ]]
}
