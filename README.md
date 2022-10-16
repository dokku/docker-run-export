# docker-run-export

Exports the flags passed to a `docker run` call to a variety of formats.

This is a work in progress

## Building

```shell
go build
```

## Formats supported

- docker-compose.yml 3.7 (WIP)
- nomad-job.json (planned)

## Usage

> Warning: not all formats will support all flags. Warnings will be emitted on stderr. Some flags may be validated if they contain units or formatting of some sort, which may result in errors being output as well.

```shell
docker-run-export run --dre-project derp --add-host "somehost:162.242.195.82" --cap-add DERP --cpus 5 --expose 5:5 alpine:latest key echo "hi derp"
```

output

```yaml
---
name: derp
services:
  app:
    blkioconfig: {}
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
    healthcheck: {}
    image: alpine:latest
```

Non `docker run` supported flags:

- `dre-project`: the project name
- `dre-format`: the format to export as

Unsupported `docker run` flags:

- `-h`: (hostname) detected as help. Use `--hostname` instead.
