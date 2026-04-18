# Nomad

HashiCorp Nomad is a workload orchestrator that schedules containers, VMs, and other tasks across a cluster of machines. docker-run-export generates a Nomad job specification from your `docker run` flags, using the Docker task driver. The output is available in HCL (the native Nomad configuration format) or JSON (for the Nomad HTTP API).

## Job Spec HCL (`--dre-format nomad`)

```shell
docker-run-export run --dre-project myapp --dre-format nomad -e FOO=bar -p 8080:80 --cpus 1 --memory 536870912 alpine:latest echo hello
```

output

```hcl
job "myapp" {
  datacenters = ["dc1"]
  type        = "service"

  group "app" {
    count = 1

    network {
      mode = "bridge"
      port "port_80" {
        static = 8080
        to     = 80
      }
    }

    task "app" {
      driver = "docker"

      config {
        args  = ["echo", "hello"]
        image = "alpine:latest"
        ports = ["port_80"]
      }

      env {
        FOO = "bar"
      }

      resources {
        cpu    = 1000
        memory = 512
      }
    }
  }
}
```

## Job Spec JSON (`--dre-format nomad-json`)

```shell
docker-run-export run --dre-project myapp --dre-format nomad-json -e FOO=bar -p 8080:80 --cpus 1 --memory 536870912 alpine:latest echo hello
```

output

```json
{
  "Job": {
    "ID": "myapp",
    "Name": "myapp",
    "Type": "service",
    "Datacenters": ["dc1"],
    "TaskGroups": [
      {
        "Name": "app",
        "Count": 1,
        "Networks": [
          {
            "Mode": "bridge",
            "ReservedPorts": [
              {"Label": "port_80", "To": 80, "Value": 8080}
            ]
          }
        ],
        "Tasks": [
          {
            "Name": "app",
            "Driver": "docker",
            "Config": {
              "args": ["echo", "hello"],
              "image": "alpine:latest",
              "ports": ["port_80"]
            },
            "Env": {"FOO": "bar"},
            "Resources": {"CPU": 1000, "MemoryMB": 512}
          }
        ]
      }
    ]
  }
}
```

## Nomad-Specific Flags

These flags have no `docker run` equivalent and are prefixed with `dre-nomad-`. They are also listed in the [Command Reference](command-reference.md#dre-flags).

- `--dre-nomad-datacenter`: Nomad datacenter(s); can be passed multiple times. Defaults to `dc1`.
- `--dre-nomad-region`: Nomad region (maps to `Region`).
- `--dre-nomad-namespace`: Nomad namespace (maps to `Namespace`).
- `--dre-nomad-type`: Nomad job type. One of `service`, `batch`, `system`. Defaults to `service`.
- `--dre-nomad-count`: Number of task group instances. Defaults to `1`.

## Unit Conversions

- `--cpus`: float CPUs to Nomad CPU MHz (e.g., `1.0` = `1000` MHz, `2.5` = `2500` MHz).
- `--cpu-shares`: relative weight converted proportionally to MHz (`shares * 1000 / 1024`). Only used if `--cpus` is not set.
- `--memory`: bytes to MiB (e.g., `536870912` bytes = `512` MiB).
- `--stop-timeout`: seconds to nanoseconds for the JSON API, or a Go duration string (e.g. `30s`) in HCL.

## Docker Driver Config Mapping

Most docker run flags map directly to fields on the Nomad Docker driver `config` block:

| Docker flag | Nomad location |
|---|---|
| `image` (positional) | `task.config.image` |
| `command` (positional) | `task.config.args` |
| `--entrypoint` | `task.config.entrypoint` |
| `--env` | `task.env` |
| `--label` | `task.config.labels` |
| `--workdir` | `task.config.work_dir` |
| `--user` | `task.user` |
| `--hostname` | `task.config.hostname` |
| `--mac-address` | `task.config.mac_address` |
| `--cap-add` / `--cap-drop` | `task.config.cap_add` / `task.config.cap_drop` |
| `--privileged` | `task.config.privileged` |
| `--read-only` | `task.config.readonly_rootfs` |
| `--security-opt` | `task.config.security_opt` |
| `--tty` | `task.config.tty` |
| `--interactive` | `task.config.interactive` |
| `--userns` | `task.config.userns_mode` |
| `--pid` | `task.config.pid_mode` |
| `--ipc` | `task.config.ipc_mode` |
| `--dns` | `task.config.dns_servers` |
| `--dns-search` | `task.config.dns_search_domains` |
| `--dns-option` | `task.config.dns_options` |
| `--add-host` | `task.config.extra_hosts` |
| `--volume` / `-v` | `task.config.volumes` |
| `--device` | `task.config.devices` |
| `--shm-size` | `task.config.shm_size` |
| `--sysctl` | `task.config.sysctl` |
| `--log-driver` | `task.config.logging.type` |
| `--log-opt` | `task.config.logging.config` |
| `--ulimit` | `task.config.ulimit` |
| `--storage-opt` | `task.config.storage_opt` |
| `--stop-signal` | `task.kill_signal` |
| `--stop-timeout` | `task.kill_timeout` |
| `--cpus` | `task.resources.cpu` (MHz) |
| `--cpu-shares` | `task.resources.cpu` (MHz, proportional) |
| `--memory` | `task.resources.memory` (MiB) |
| `--network` | group `network.mode` (host/bridge/none) or `task.config.network_mode` |
| `--network-alias` | `task.config.network_aliases` |
| `--publish` / `-p` | group `network` port blocks plus `task.config.ports` |
| `--ip` | `task.config.ipv4_address` |
| `--ip6` | `task.config.ipv6_address` |
| `--cpuset-cpus` | `task.config.cpuset_cpus` |
| `--cpu-period` | `task.config.cpu_cfs_period` |
| `--pids-limit` | `task.config.pids_limit` |
| `--init` | `task.config.init` |
| `--runtime` | `task.config.runtime` |
| `--isolation` | `task.config.isolation` |
| `--cgroupns` | `task.config.cgroupns` |
| `--uts` | `task.config.uts_mode` |
| `--group-add` | `task.config.group_add` |
| `--oom-score-adj` | `task.config.oom_score_adj` |
| `--volume-driver` | `task.config.volume_driver` |
| `--pull always` | `task.config.force_pull = true` |
| `--mount` | `task.config.mount` block (bind/volume/tmpfs) |
| `--tmpfs` | `task.config.mount` block with `type = "tmpfs"` |
| `--gpus` | `task.resources.device "nvidia/gpu" { count = N }` |
| `--restart` | group-level `restart { attempts, mode }` stanza |
| `--health-cmd` | group `service.check.command` + `args` (with `type = "script"`) |
| `--health-interval` | group `service.check.interval` |
| `--health-timeout` | group `service.check.timeout` |
| `--health-retries` | group `service.check.check_restart.limit` |
| `--health-start-period` | group `service.check.check_restart.grace` |
| `--no-healthcheck` | `task.config.healthchecks.disable = true` |

## Health Checks

Docker health check flags are translated into a group-level `service` stanza with a `script`-type `check`. The script runs inside the task's container via `docker exec`, matching docker's `HEALTHCHECK CMD` semantics.

```shell
docker-run-export run --dre-project myapp --dre-format nomad \
  --health-cmd "curl -f http://localhost/" \
  --health-interval 30s --health-timeout 10s \
  --health-retries 3 --health-start-period 5s \
  nginx:latest
```

output (health-check portion shown):

```hcl
job "myapp" {
  # ...
  group "app" {
    service {
      name     = "app"
      provider = "consul"

      check {
        name     = "app-health"
        type     = "script"
        command  = "curl"
        args     = ["-f", "http://localhost/"]
        task     = "app"
        interval = "30s"
        timeout  = "10s"
        check_restart {
          limit = 3
          grace = "5s"
        }
      }
    }
    # ...
  }
}
```

Notes:

- The service's `provider` is set to `"consul"` because Nomad's native service provider only supports `tcp`, `http`, and `grpc` check types — script checks require the Consul provider. This means the generated job requires a Consul agent running alongside Nomad. If you don't have Consul and want to keep docker-style "arbitrary command" health checks, remove the `service` stanza and rely on the image's Dockerfile `HEALTHCHECK`, or rewrite the check as `tcp`/`http` and switch provider to `nomad`.
- `--health-cmd` is parsed with shell-words semantics (same parser used for `--entrypoint`). The first token becomes the check's `command` and the rest become `args`.
- `--health-retries` maps to `check_restart.limit` (the number of consecutive failures that will trigger a task restart). Script checks are binary pass/fail in Nomad and do not support `failures_before_critical`, so `check_restart.limit` is the closest functional equivalent to docker's retry semantics.
- `--health-start-period` is expressed as `check_restart.grace`, which is Nomad's analog of "don't count failing checks during startup".
- Sub-flags (`--health-interval`, `--health-timeout`, `--health-retries`, `--health-start-period`) emit a warning and are ignored if `--health-cmd` is not also set, because there is nothing to attach them to.
- `--no-healthcheck` is honored by setting the Nomad docker driver's `task.config.healthchecks.disable = true`, which tells the driver to ignore the image's Dockerfile `HEALTHCHECK`.

## Unsupported Flags

Not supported by the Nomad job specification or the Nomad Docker driver:

- `--annotation`
- `--attach`
- `--blkio-weight`
- `--blkio-weight-device`
- `--cgroup-parent`
- `--cidfile`
- `--cpu-quota`
- `--cpu-rt-period`
- `--cpu-rt-runtime`
- `--cpuset-mems`
- `--detach`
- `--detach-keys`
- `--device-cgroup-rule`
- `--device-read-bps`
- `--device-read-iops`
- `--device-write-bps`
- `--device-write-iops`
- `--disable-content-trust`
- `--domainname`
- `--env-file`
- `--expose`
- `--kernel-memory`
- `--label-file`
- `--link`
- `--link-local-ip`
- `--memory-reservation`
- `--memory-swap`
- `--memory-swappiness`
- `--oom-kill-disable`
- `--platform`
- `--publish-all`
- `--pull never` (Nomad docker driver always pulls missing images; warns)
- `--rm`
- `--sig-proxy`
- `--volumes-from`

## Notes

- A single task group and single task are emitted, both named after `--name` (or `app` if unset). The job `ID`/`Name` defaults to `--dre-project`, falling back to the task name.
- Each `--publish` flag generates a port definition under the group `network` stanza and adds its label to `task.config.ports`. Host-mapped ports (e.g., `8080:80`) become `ReservedPorts` with a `static` value; container-only ports (e.g., `80`) become `DynamicPorts`. Port labels are generated as `port_<containerPort>` (with `_<protocol>` appended for non-tcp protocols).
- When any port is published without an explicit `--network`, the network mode defaults to `bridge` so that Nomad assigns host ports correctly.
- `--network host`, `--network bridge`, and `--network none` map to the group `network.mode`. Any other value is passed through as the Docker driver's `network_mode` config field.
- Labels and sysctl keys that are not valid bare HCL identifiers (e.g., `com.example.key`, `net.core.somaxconn`) are emitted with quoted keys in HCL output.
- Health checks in Nomad live on a `service` stanza at the group level. The Docker health-check flags are translated into a script-type check — see the [Health Checks](#health-checks) section.
- `--restart` maps to a group-level `restart` stanza. `no` becomes `attempts = 0, mode = "fail"`. `on-failure[:N]` becomes `attempts = N, mode = "fail"`. `always` and `unless-stopped` are approximated with `mode = "delay"` and emit a warning, because Nomad does not restart tasks that exit successfully (docker's "always" does).
- `--gpus` maps to a `resources.device "nvidia/gpu" { count = N }` block. `all` is treated as `count = 1`. `device=<ids>` sets `count` to the number of IDs. `capabilities=...` is ignored because Nomad's device stanza does not express it. `driver=<vendor>` changes the device name to `<vendor>/gpu`.
- `--mount` and `--tmpfs` both emit `task.config.mount` blocks on the Nomad docker driver. Docker's `type=bind|volume|tmpfs`, `source`/`src`, `target`/`dst`/`destination`, `readonly`/`ro`, `bind-propagation`, `volume-nocopy`, `volume-label`, `volume-driver`, `volume-opt`, `tmpfs-size`, and `tmpfs-mode` options are all honored. `--tmpfs` size values accept k/m/g suffixes and are normalized to bytes.
- `--pull always` sets the Nomad docker driver's `force_pull = true`. `--pull missing` is the driver default, so nothing is emitted. `--pull never` has no Nomad equivalent (the driver will pull missing images regardless) and emits a warning.
