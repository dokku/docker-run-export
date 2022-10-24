# Compose

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

## Unsupported Flags

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

Partially implemented:

- `--mount`: Compose V3 does not support the following options:
  - `bind-nonrecursive`
  - `volume-driver`
  - `volume-label`
  - `volume-opt`
  - `tmpfs-mode`
- `--volume`: does not properly parse windows paths
