# docker-run-export

Exports the flags passed to a `docker run` call to a variety of formats.

This is a work in progress

## Building

```shell
go build
```

## Formats supported

- `docker-compose.yml` 3.7 (WIP)
- nomad `job.json` (planned)
- kubernetes `deployment.yml` (planned)
- ecs `task-definition.json` (planned)

## Usage

> Warning: not all formats will support all flags. Warnings will be emitted on stderr. Some flags may be validated if they contain units or formatting of some sort, which may result in errors being output as well.

### Compose

```shell
docker-run-export run --dre-project derp --add-host "somehost:162.242.195.82" --cap-add DERP --cpus 5 --expose 5:5 alpine:latest key echo "hi derp"
```

output

```yaml
---
name: derp
services:
  app:
    cap_add:
    - DERP
    command:
    - key
    - echo
    - hi derp
    deploy:
      resources:
        limits:
          cpus: "5.000000"
    expose:
    - "5:5"
    extra_hosts:
      somehost: 162.242.195.82
    image: alpine:latest
```

Non `docker run` supported flags:

- `dre-project`: the project name
- `dre-format`: the format to export as

Unsupported `docker run` flags:

- `-h`: (hostname) detected as help. Use `--hostname` instead.
- `--pull`: compose behavior is to only pull if image is missing

Unsupported by Compose v3:

- `--attach`
- `--cgroupns`
- `--cidfile`
- `--cpu-period`
- `--cpu-quota`
- `--cpu-rt-period`
- `--cpu-rt-runtime`
- `--cpuset-cpus`
- `--cpuset-mems`
- `--detach`
- `--detach-keys`
- `--disable-trust-content`
- `--gpus`
- `--interactive`
- `--kernel-memory`
- `--label-file`
- `--publish-all`
- `--rm`
- `--sig-proxy`
- `--storage-opt`

Requires parsing and may be supported in the future:

- `--device-read-bps`
- `--device-write-bps`
- `--ulimit`

Partially implemented:

- `--mount`: missing type-specific options for bind/tmpfs/volume types
- `--volume`: does not properly parse windows paths
