# ECS

Amazon Elastic Container Service (ECS) runs Docker containers on AWS. docker-run-export generates either a standalone ECS task definition (JSON) or a CloudFormation template containing an `AWS::ECS::TaskDefinition` resource. This lets you take a `docker run` command that works locally and produce the configuration AWS needs to run the same container in the cloud.

## Task Definition JSON (`--dre-format ecs`)

```shell
docker-run-export run --dre-project myapp --dre-format ecs -e FOO=bar -p 8080:80 --cpus 1 --memory 536870912 alpine:latest echo hello
```

output

```json
{
  "family": "myapp",
  "containerDefinitions": [
    {
      "name": "app",
      "image": "alpine:latest",
      "memory": 512,
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
  ],
  "cpu": "1024",
  "memory": "512"
}
```

## CloudFormation YAML (`--dre-format ecs-cfn`)

```shell
docker-run-export run --dre-project myapp --dre-format ecs-cfn -p 8080:80 alpine:latest
```

output

```yaml
---
AWSTemplateFormatVersion: "2010-09-09"
Resources:
  TaskDefinition:
    Type: AWS::ECS::TaskDefinition
    Properties:
      Family: myapp
      ContainerDefinitions:
        - Name: app
          Image: alpine:latest
          Essential: true
          PortMappings:
            - ContainerPort: 80
              HostPort: 8080
              Protocol: tcp
```

## ECS-Specific Flags

These flags have no `docker run` equivalent and are prefixed with `dre-ecs-`. They are also listed in the [Command Reference](command-reference.md#dre-flags).

- `--dre-ecs-task-role-arn`: IAM role ARN for the task (maps to `taskRoleArn`)
- `--dre-ecs-execution-role-arn`: IAM role ARN for the ECS agent (maps to `executionRoleArn`)
- `--dre-ecs-launch-type`: Launch type compatibility, e.g., `FARGATE` or `EC2` (maps to `requiresCompatibilities`)

## Unit Conversions

- `--memory` and `--memory-reservation`: bytes to MiB (e.g., `536870912` bytes = `512` MiB)
- `--cpus`: float to ECS CPU units (e.g., `1.0` = `1024` units)
- `--cpu-shares`: maps directly to container-level `cpu`
- `--health-interval`, `--health-timeout`, `--health-start-period`: Go duration strings to seconds (e.g., `30s` = `30`)
- `--shm-size`: bytes to MiB

## Unsupported Flags

Not supported by the ECS task definition specification:

- `--attach`
- `--annotation`
- `--blkio-weight`
- `--blkio-weight-device`
- `--cgroup-parent`
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
- `--device-cgroup-rule`
- `--device-read-bps`
- `--device-read-iops`
- `--device-write-bps`
- `--device-write-iops`
- `--disable-content-trust`
- `--dns-option`
- `--domainname`
- `--env-file` (ECS uses S3-based environment files instead)
- `--expose`
- `--group-add`
- `--ip`
- `--ip6`
- `--isolation`
- `--kernel-memory`
- `--label-file`
- `--link-local-ip`
- `--mac-address`
- `--network-alias`
- `--no-healthcheck`
- `--oom-kill-disable`
- `--oom-score-adj`
- `--pids-limit`
- `--publish-all`
- `--pull`
- `--restart` (use ECS service restart policy instead)
- `--rm`
- `--runtime`
- `--sig-proxy`
- `--stop-signal`
- `--storage-opt`
- `--userns`
- `--uts`
- `--volume-driver`

## Notes

- The `--network` flag maps `host`, `none`, and `bridge` directly. Other network names are mapped to `awsvpc` with a warning.
- For Fargate launch type, `networkMode` must be `awsvpc` and CPU/memory must use valid Fargate combinations.
- The `--platform` flag is converted to ECS `runtimePlatform` (e.g., `linux/amd64` becomes `cpuArchitecture: X86_64, operatingSystemFamily: LINUX`).
- A single container named `app` (or `--name` value) is always marked as `essential: true`.
