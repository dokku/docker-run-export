# Docker CLI Plugin

docker-run-export can be invoked as a [Docker CLI plugin](https://github.com/docker/cli/issues/1534), which means you can use `docker dre` instead of typing the full binary name. Every subcommand works the same way:

```bash
docker dre run --dre-format compose alpine:latest
# equivalent to
docker-run-export run --dre-format compose alpine:latest
```

## How It Works

Docker discovers plugins by scanning specific directories for executables named `docker-<name>`. The docker-run-export plugin binary is named `docker-dre` (Docker CLI plugin names must be lowercase alphanumeric with no hyphens). When Docker finds this binary, running `docker dre <subcommand>` invokes it automatically.

## Plugin Directories

Docker searches these directories for plugins:

- **Per-user:** `~/.docker/cli-plugins/docker-dre`
- **System-wide (Linux):** `/usr/libexec/docker/cli-plugins/docker-dre` or `/usr/local/lib/docker/cli-plugins/docker-dre`
- **System-wide (Homebrew):** `$(brew --prefix)/lib/docker/cli-plugins/docker-dre`

## Automatic Setup by Distribution Channel

The supported distribution channels install the plugin automatically:

- **Debian/Ubuntu:** the `.deb` package installs both `/usr/bin/docker-run-export` (for direct invocation) and `/usr/libexec/docker/cli-plugins/docker-dre` (for Docker CLI plugin lookup).
- **Homebrew:** `brew install dokku/repo/docker-run-export` places the binary under `bin/` and symlinks it into Homebrew's `lib/docker/cli-plugins/`.
- **Install script:** downloads the appropriate release tarball for your OS/architecture and installs the binary at `~/.docker/cli-plugins/docker-dre`.
- **From source:** `make install` builds for your current OS/architecture and copies the binary into `~/.docker/cli-plugins/`.

## Verifying the Plugin

After installation, confirm that Docker sees the plugin:

```bash
docker dre version
```

You can also check that `docker --help` lists `dre` under the "Plugin commands" section.

## Direct Invocation

You can always run the binary directly without the Docker CLI plugin mechanism. This is useful if Docker is not installed on the machine where you are generating configuration:

```bash
docker-run-export run --dre-format compose alpine:latest
```
