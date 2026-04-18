# Compose

Docker Compose is a tool for defining multi-container applications with a YAML file. docker-run-export generates a Compose service definition from your `docker run` flags, which you can save to a `docker-compose.yml` and run with `docker compose up`.

## Example

```bash
docker-run-export run --dre-project derp --dre-format compose --add-host "somehost:162.242.195.82" --cap-add DERP --cpus 5 --expose 5:5 alpine:latest key echo "hi derp"
```

output:

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

Each `docker run` flag maps to a Compose YAML field. For example, `--cap-add` becomes `cap_add`, `--cpus` becomes both `cpus` and `deploy.resources.limits.cpus`, and `--add-host` becomes `extra_hosts`.

## Unsupported Flags

### Parser Limitations

- `-h`: detected as help by the flag parser. Use `--hostname` instead.

### Not Supported by the Compose Specification

These flags have no equivalent in the Compose specification and are ignored with a warning:

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

### Partially Implemented

- `--mount`: The following mount options are not supported:
  - `bind-nonrecursive`
  - `volume-driver`
  - `volume-label`
  - `volume-opt`
  - `tmpfs-mode`
- `--volume`: does not properly parse Windows paths.
