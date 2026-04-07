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
    cpus: 5
    command:
    - key
    - echo
    - hi derp
    deploy:
      resources:
        limits:
          cpus: 5
    expose:
    - "5:5"
    extra_hosts:
    - somehost=162.242.195.82
    image: alpine:latest
```

## Unsupported Flags

Unsupported `docker run` flags:

- `-h`: (hostname) detected as help. Use `--hostname` instead.

Not supported by the Compose Specification:

- `--attach`
- `--cidfile`
- `--cpuset-mems`
- `--detach`
- `--detach-keys`
- `--disable-content-trust`
- `--kernel-memory`
- `--publish-all`
- `--rm`
- `--sig-proxy`

Partially implemented:

- `--mount`: The following options are not supported:
  - `bind-nonrecursive`
  - `volume-driver`
  - `volume-label`
  - `volume-opt`
  - `tmpfs-mode`
- `--volume`: does not properly parse windows paths
