# Command Reference

## Synopsis

```
docker-run-export run [docker-run-flags] [dre-flags] IMAGE [COMMAND [ARG...]]
```

As a Docker CLI plugin:

```
docker dre run [docker-run-flags] [dre-flags] IMAGE [COMMAND [ARG...]]
```

## Arguments

| Argument | Required | Description |
| --- | --- | --- |
| `IMAGE` | Yes | The Docker image to use in the generated configuration. |
| `COMMAND` | No | Command and arguments passed through to the output format's command/args field. |

## DRE Flags

These flags control docker-run-export itself and are not part of `docker run`. They are prefixed with `dre-` to avoid conflicts with docker run flags.

| Flag | Type | Default | Description |
| --- | --- | --- | --- |
| `--dre-format` | string | `compose` | Output format: `compose`, `ecs`, `ecs-cfn`, `nomad`, or `nomad-json`. |
| `--dre-project` | string | | Project name used in the generated configuration (Compose project name, ECS family, Nomad job ID). |
| `--dre-ecs-task-role-arn` | string | | IAM role ARN for the ECS task (maps to `taskRoleArn`). Only applies to `ecs` and `ecs-cfn` formats. |
| `--dre-ecs-execution-role-arn` | string | | IAM role ARN for the ECS agent (maps to `executionRoleArn`). Only applies to `ecs` and `ecs-cfn` formats. |
| `--dre-ecs-launch-type` | string (repeatable) | | ECS launch type compatibility, e.g., `FARGATE` or `EC2` (maps to `requiresCompatibilities`). Pass the flag multiple times for multiple values. Only applies to `ecs` and `ecs-cfn` formats. |
| `--dre-nomad-datacenter` | string (repeatable) | `dc1` | Nomad datacenter(s). Pass the flag multiple times for multiple values. Only applies to `nomad` and `nomad-json` formats. |
| `--dre-nomad-region` | string | | Nomad region (maps to `Region`). Only applies to `nomad` and `nomad-json` formats. |
| `--dre-nomad-namespace` | string | | Nomad namespace (maps to `Namespace`). Only applies to `nomad` and `nomad-json` formats. |
| `--dre-nomad-type` | string | `service` | Nomad job type: `service`, `batch`, or `system`. Only applies to `nomad` and `nomad-json` formats. |
| `--dre-nomad-count` | int | `1` | Number of task group instances. Only applies to `nomad` and `nomad-json` formats. |

## Supported Docker Run Flags

docker-run-export accepts most `docker run` flags. It parses them and maps each flag to the closest equivalent in the target format. Not every flag is supported by every format -- unsupported flags emit a warning on stderr and are otherwise ignored.

For the complete list of flag-to-field mappings and unsupported flags in each format, see:

- [Compose](compose.md#unsupported-flags)
- [ECS](ecs.md#unsupported-flags)
- [Nomad](nomad.md#unsupported-flags)

> **Note:** The `-h` short flag is detected as help by the argument parser. Use `--hostname` instead.

## Output Formats

| Format | `--dre-format` value | Output type | Description |
| --- | --- | --- | --- |
| Compose | `compose` | YAML | Docker Compose service definition (v3.7). |
| ECS Task Definition | `ecs` | JSON | AWS ECS task definition. |
| ECS CloudFormation | `ecs-cfn` | YAML | CloudFormation template with an `AWS::ECS::TaskDefinition` resource. |
| Nomad HCL | `nomad` | HCL | HashiCorp Nomad job specification in HCL. |
| Nomad JSON | `nomad-json` | JSON | Nomad job specification in JSON (for the Nomad HTTP API). |

> **Kubernetes:** For Kubernetes output, generate a Compose file with `--dre-format compose` and convert it with [kompose](https://kompose.io/).

## Examples

Export to Compose (the default format):

```bash
docker-run-export run --dre-project myapp alpine:latest echo hello
```

Export to an ECS task definition with IAM roles and Fargate:

```bash
docker-run-export run --dre-project myapp --dre-format ecs \
  --dre-ecs-task-role-arn arn:aws:iam::123456789:role/task \
  --dre-ecs-execution-role-arn arn:aws:iam::123456789:role/exec \
  --dre-ecs-launch-type FARGATE \
  -p 8080:80 nginx:latest
```

Export to a Nomad HCL job spec with datacenter and region:

```bash
docker-run-export run --dre-project myapp --dre-format nomad \
  --dre-nomad-datacenter us-east-1 --dre-nomad-region us \
  -e FOO=bar -p 8080:80 --cpus 1 --memory 536870912 \
  alpine:latest echo hello
```

Use as a Docker CLI plugin:

```bash
docker dre run --dre-format compose --dre-project myapp -p 8080:80 nginx:latest
```

## See Also

- [Compose](compose.md) -- Compose-specific mappings and unsupported flags
- [ECS](ecs.md) -- ECS-specific mappings, unit conversions, and unsupported flags
- [Nomad](nomad.md) -- Nomad driver config mapping, health checks, and unsupported flags
- [Docker CLI Plugin](docker-cli-plugin.md) -- plugin installation and invocation details
