# docker-run-export

Exports `docker run` flags to configuration files for Docker Compose, AWS ECS, and HashiCorp Nomad.

## Installation

Install with the quick install script:

```bash
curl -fsSL https://raw.githubusercontent.com/dokku/docker-run-export/main/install.sh | sh
```

Or via Homebrew:

```bash
brew install dokku/repo/docker-run-export
```

Or build from source:

```bash
make install
```

See the [Getting Started](docs/getting-started.md#installation) guide for all distribution channels (Debian/Ubuntu packages, binary downloads, etc.).

Once installed, the plugin is available via `docker dre`.

## Usage

Export a `docker run` command to a Compose file:

```bash
docker dre run --dre-project myapp --dre-format compose -e FOO=bar -p 8080:80 nginx:latest
```

Change `--dre-format` to target a different platform:

```bash
docker dre run --dre-project myapp --dre-format ecs -p 8080:80 nginx:latest
docker dre run --dre-project myapp --dre-format nomad -p 8080:80 nginx:latest
```

See the [command reference](docs/command-reference.md) for all flags and options.

## Documentation

- [Getting Started](docs/getting-started.md) -- why docker-run-export, installation, and your first export
- [Command Reference](docs/command-reference.md) -- all DRE flags, supported docker run flags, and output formats
- [Compose](docs/compose.md) -- exporting to docker-compose.yml
- [ECS](docs/ecs.md) -- exporting to ECS task definitions and CloudFormation templates
- [Nomad](docs/nomad.md) -- exporting to Nomad job specifications in HCL and JSON
- [Docker CLI Plugin](docs/docker-cli-plugin.md) -- using docker-run-export as `docker dre`

## License

[MIT](LICENSE)
