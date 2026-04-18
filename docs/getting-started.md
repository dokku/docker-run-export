# Getting Started

## Why docker-run-export?

Most developers learn Docker through `docker run`. You know how to set environment variables with `-e`, publish ports with `-p`, and mount volumes with `-v`. But when it comes time to deploy that same container on a platform like AWS ECS or HashiCorp Nomad, you need to translate those familiar flags into a completely different configuration format -- JSON task definitions, HCL job specs, or Compose YAML.

docker-run-export does that translation for you. Give it the `docker run` command you would use locally, and it produces the equivalent configuration file for your target platform. You do not need to memorize three different configuration formats or worry about unit conversions (like bytes to MiB for memory limits).

## Installation

Once installed, the tool is available as a Docker CLI plugin:

```bash
docker dre version
```

### Quick Install (Linux and macOS)

Use the install script to download the latest release and install it as a Docker CLI plugin:

```bash
curl -fsSL https://raw.githubusercontent.com/dokku/docker-run-export/main/install.sh | sh
```

To install a specific version:

```bash
VERSION=0.2.0 curl -fsSL https://raw.githubusercontent.com/dokku/docker-run-export/main/install.sh | sh
```

To install to a custom directory:

```bash
PLUGIN_DIR=/usr/libexec/docker/cli-plugins curl -fsSL https://raw.githubusercontent.com/dokku/docker-run-export/main/install.sh | sh
```

### Homebrew (macOS)

```bash
brew install dokku/repo/docker-run-export
```

### Debian/Ubuntu

```bash
sudo apt-get update
sudo apt-get install docker-run-export
```

The Debian package installs the binary to both `/usr/bin/docker-run-export` (for direct invocation) and `/usr/libexec/docker/cli-plugins/docker-dre` (for automatic Docker CLI plugin discovery).

### Binary Download

Download a pre-built binary from [GitHub Releases](https://github.com/dokku/docker-run-export/releases) and place it in your Docker CLI plugins directory:

```bash
mkdir -p ~/.docker/cli-plugins
install -m 0755 docker-run-export-amd64 ~/.docker/cli-plugins/docker-dre
```

The binary must be named `docker-dre` and be executable. Docker looks for plugins in:

- `~/.docker/cli-plugins/` (per-user)
- `/usr/libexec/docker/cli-plugins/` (system-wide)

### From Source

Build and install as a Docker CLI plugin:

```bash
make install
```

This builds the binary for your platform and copies it to `~/.docker/cli-plugins/docker-dre`.

## Prerequisites

- Docker Engine (docker-run-export parses `docker run` flags but does not require a running Docker daemon to generate output)

## Your First Export

Start with a `docker run` command and convert it to a Compose file. The `--dre-format` flag tells docker-run-export which output format to use, and `--dre-project` sets the project name:

```bash
docker-run-export run --dre-project myapp --dre-format compose -e FOO=bar -p 8080:80 alpine:latest echo hello
```

output:

```yaml
---
name: myapp
services:
  app:
    command:
    - echo
    - hello
    environment:
      FOO: bar
    image: alpine:latest
    ports:
    - 8080:80/tcp
```

The `-e`, `-p`, and positional arguments were translated into Compose YAML fields. The image became `services.app.image`, the environment variable became `services.app.environment`, and the port mapping became `services.app.ports`.

Now export the same command to an ECS task definition by changing the format flag:

```bash
docker-run-export run --dre-project myapp --dre-format ecs -e FOO=bar -p 8080:80 alpine:latest echo hello
```

output:

```json
{
  "family": "myapp",
  "containerDefinitions": [
    {
      "name": "app",
      "image": "alpine:latest",
      "portMappings": [
        {
          "containerPort": 80,
          "hostPort": 8080,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "command": [
        "echo",
        "hello"
      ],
      "environment": [
        {
          "name": "FOO",
          "value": "bar"
        }
      ]
    }
  ]
}
```

The same `docker run` flags produced a valid ECS task definition. Each format handles the translation differently -- for example, ECS uses an array of `{name, value}` objects for environment variables instead of a simple map.

> **Note:** Not every `docker run` flag is supported by every format. When a flag cannot be translated, docker-run-export prints a warning to stderr and continues.

## What to Read Next

- [Command Reference](command-reference.md) -- all DRE flags and supported docker run flags
- [Compose](compose.md) -- Compose-specific output details and unsupported flags
- [ECS](ecs.md) -- ECS task definition output, unit conversions, and CloudFormation
- [Nomad](nomad.md) -- Nomad HCL/JSON output, driver config mapping, and health checks
- [Docker CLI Plugin](docker-cli-plugin.md) -- using the tool as `docker dre`
