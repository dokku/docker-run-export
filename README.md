# docker-run-export

Exports the flags passed to a `docker run` call to a variety of formats.

This is a work in progress

## Building

```shell
go build
```

## Formats

- docker `docker-compose.yml` 3.7: [Docs](/docs/compose.md)
- ecs `task-definition.json`: [Docs](/docs/ecs.md)
- ecs-cfn CloudFormation `AWS::ECS::TaskDefinition`: [Docs](/docs/ecs.md)
- nomad `job.nomad` HCL: [Docs](/docs/nomad.md)
- nomad-json `job.json`: [Docs](/docs/nomad.md)
- kubernetes `deployment.yml`: Use [kompose](https://kompose.io/)

## Docker CLI plugin

`docker-run-export` can be invoked as a [Docker CLI plugin](https://github.com/docker/cli/issues/1534), exposing every subcommand under `docker dre`:

```shell
docker dre run --dre-format compose alpine:latest
# equivalent to
docker-run-export run --dre-format compose alpine:latest
```

The plugin binary is named `docker-dre` (Docker CLI plugin names must be lowercase alphanumeric, no hyphens). It is registered as a plugin by placing (or symlinking) it into one of Docker's plugin lookup directories:

- Per-user: `~/.docker/cli-plugins/docker-dre`
- System-wide (Linux): `/usr/libexec/docker/cli-plugins/docker-dre` or `/usr/local/lib/docker/cli-plugins/docker-dre`
- System-wide (Homebrew): `$(brew --prefix)/lib/docker/cli-plugins/docker-dre`

The supported distribution channels wire this up automatically:

- **Debian/Ubuntu:** the `.deb` package installs both `/usr/bin/docker-run-export` (for direct invocation) and `/usr/libexec/docker/cli-plugins/docker-dre` (for Docker CLI plugin lookup).
- **Homebrew:** `brew install docker-run-export` places the binary under `bin/` and symlinks it into Homebrew's `lib/docker/cli-plugins/`.
- **Release tarball / install script:** run

  ```shell
  curl -fsSL https://raw.githubusercontent.com/dokku/docker-run-export/main/install.sh | sh
  ```

  to download the appropriate release tarball for your OS/arch and install the binary at `~/.docker/cli-plugins/docker-dre`.
- **From source:** `make install` builds for your current OS/arch and drops the binary into `~/.docker/cli-plugins/`.

Once installed, `docker --help` will list `dre*` under the "Plugin commands" section, and `docker dre <subcommand>` works identically to the bare binary.

## Usage

> Warning: not all formats will support all flags. Warnings will be emitted on stderr. Some flags may be validated if they contain units or formatting of some sort, which may result in errors being output as well.

```shell
docker-run-export run --dre-project derp --dre-format compose --add-host "somehost:162.242.195.82" --cap-add DERP --cpus 5 --expose 5:5 alpine:latest key echo "hi derp"
```

Non `docker run` supported flags:

- `dre-project`: the project name
- `dre-format`: the format to export as
