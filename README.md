# docker-run-export

Exports the flags passed to a `docker run` call to a variety of formats.

This is a work in progress

## Building

```shell
go build
```

## Formats

- docker `docker-compose.yml` 3.7: [Docs](/docs/compose.md)
- nomad `job.json` (planned)
- kubernetes `deployment.yml` (planned)
- ecs `task-definition.json` (planned)

## Usage

> Warning: not all formats will support all flags. Warnings will be emitted on stderr. Some flags may be validated if they contain units or formatting of some sort, which may result in errors being output as well.

```shell
docker-run-export run --dre-project derp --dre-format compose --add-host "somehost:162.242.195.82" --cap-add DERP --cpus 5 --expose 5:5 alpine:latest key echo "hi derp"
```

Non `docker run` supported flags:

- `dre-project`: the project name
- `dre-format`: the format to export as
