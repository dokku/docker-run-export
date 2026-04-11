package convert

import (
	"bytes"
	"testing"

	"docker-run-export/arguments"

	"github.com/hashicorp/hcl/v2/hclparse"
	"github.com/hashicorp/nomad/jobspec2"
	"github.com/josegonzalez/cli-skeleton/command"
)

// makeArgs constructs a minimal arguments map used by ToNomad() for tests.
func makeArgs(image string, cmd ...string) map[string]command.Argument {
	return map[string]command.Argument{
		"image":   {Name: "image", Type: command.ArgumentString, HasValue: true, Value: image},
		"command": {Name: "command", Type: command.ArgumentList, HasValue: len(cmd) > 0, Value: cmd},
	}
}

// nomadTestCase describes one docker-run-export input scenario. The test
// runs ToNomad, marshals to HCL, and then parses the result twice: once with
// hclparse (pure syntax) and once with jobspec2 (Nomad's own schema parser).
type nomadTestCase struct {
	name    string
	project string
	image   string
	command []string
	args    arguments.Args
	opts    NomadOptions
}

// nomadTestCases is a representative set of scenarios that exercise the
// generated HCL across most of the supported docker flags.
var nomadTestCases = []nomadTestCase{
	{
		name:    "minimal",
		project: "minimal",
		image:   "alpine:latest",
	},
	{
		name:    "image_and_command",
		project: "echo",
		image:   "alpine:latest",
		command: []string{"echo", "hello"},
	},
	{
		name:    "env_and_labels",
		project: "env-labels",
		image:   "alpine:latest",
		args: arguments.Args{
			Env:                 []string{"FOO=bar", "BAZ=qux"},
			Label:               []string{"com.example.key=value", "plain=true"},
			Pull:                "missing",
			HealthInterval:      "0s",
			HealthStartPeriod:   "0s",
			HealthTimeout:       "0s",
			DisableContentTrust: true,
			SigProxy:            true,
			StopSignal:          "SIGTERM",
		},
	},
	{
		name:    "ports_reserved_and_dynamic",
		project: "web",
		image:   "nginx:latest",
		args: arguments.Args{
			Publish:             []string{"8080:80", "443", "53:53/udp"},
			Pull:                "missing",
			HealthInterval:      "0s",
			HealthStartPeriod:   "0s",
			HealthTimeout:       "0s",
			DisableContentTrust: true,
			SigProxy:            true,
			StopSignal:          "SIGTERM",
		},
	},
	{
		name:    "resources_and_signals",
		project: "svc",
		image:   "nginx:latest",
		args: arguments.Args{
			Cpus:                1.5,
			Memory:              536870912,
			StopSignal:          "SIGINT",
			StopTimeout:         30,
			Pull:                "missing",
			HealthInterval:      "0s",
			HealthStartPeriod:   "0s",
			HealthTimeout:       "0s",
			DisableContentTrust: true,
			SigProxy:            true,
		},
	},
	{
		name:    "security_and_caps",
		project: "sec",
		image:   "alpine:latest",
		args: arguments.Args{
			CapAdd:              []string{"NET_ADMIN", "SYS_TIME"},
			CapDrop:             []string{"ALL"},
			Privileged:          true,
			ReadOnly:            true,
			SecurityOpt:         []string{"no-new-privileges"},
			User:                "1000:1000",
			Pull:                "missing",
			HealthInterval:      "0s",
			HealthStartPeriod:   "0s",
			HealthTimeout:       "0s",
			DisableContentTrust: true,
			SigProxy:            true,
			StopSignal:          "SIGTERM",
		},
	},
	{
		name:    "dns_hostname_volumes",
		project: "net",
		image:   "alpine:latest",
		args: arguments.Args{
			AddHost:             []string{"db:10.0.0.5"},
			Dns:                 []string{"8.8.8.8", "8.8.4.4"},
			DnsSearch:           []string{"example.com"},
			Hostname:            "web1",
			Volume:              []string{"/host/data:/data", "/host/logs:/logs:ro"},
			Workdir:             "/app",
			Pull:                "missing",
			HealthInterval:      "0s",
			HealthStartPeriod:   "0s",
			HealthTimeout:       "0s",
			DisableContentTrust: true,
			SigProxy:            true,
			StopSignal:          "SIGTERM",
		},
	},
	{
		name:    "logging_and_sysctl",
		project: "logs",
		image:   "alpine:latest",
		args: arguments.Args{
			LogDriver:           "json-file",
			LogOpt:              []string{"max-size=10m", "max-file=3"},
			Sysctl:              map[string]string{"net.core.somaxconn": "16384"},
			Ulimit:              []string{"nofile=1024:2048"},
			ShmSize:             67108864,
			Pull:                "missing",
			HealthInterval:      "0s",
			HealthStartPeriod:   "0s",
			HealthTimeout:       "0s",
			DisableContentTrust: true,
			SigProxy:            true,
			StopSignal:          "SIGTERM",
		},
	},
	{
		name:    "healthcheck_basic",
		project: "healthy",
		image:   "nginx:latest",
		args: arguments.Args{
			HealthCmd:           "curl -f http://localhost/",
			HealthInterval:      "30s",
			HealthTimeout:       "10s",
			HealthRetries:       3,
			HealthStartPeriod:   "5s",
			Pull:                "missing",
			DisableContentTrust: true,
			SigProxy:            true,
			StopSignal:          "SIGTERM",
		},
	},
	{
		name:    "driver_config_extras",
		project: "extras",
		image:   "alpine:latest",
		args: arguments.Args{
			Cgroupns:            "host",
			CpuPeriod:           100000,
			CpusetCpus:          "0-3",
			GroupAdd:            []string{"wheel"},
			Init:                true,
			Ip:                  "10.0.0.5",
			Ip6:                 "::1",
			Isolation:           "hyperv",
			NetworkAlias:        []string{"web", "api"},
			OomScore:            -500,
			PidsLimit:           100,
			Pull:                "always",
			Runtime:             "runc",
			Uts:                 "host",
			VolumeDriver:        "local",
			HealthInterval:      "0s",
			HealthStartPeriod:   "0s",
			HealthTimeout:       "0s",
			DisableContentTrust: true,
			SigProxy:            true,
			StopSignal:          "SIGTERM",
		},
	},
	{
		name:    "restart_on_failure",
		project: "restarter",
		image:   "alpine:latest",
		args: arguments.Args{
			Restart:             "on-failure:5",
			Pull:                "missing",
			HealthInterval:      "0s",
			HealthStartPeriod:   "0s",
			HealthTimeout:       "0s",
			DisableContentTrust: true,
			SigProxy:            true,
			StopSignal:          "SIGTERM",
		},
	},
	{
		name:    "gpus_count",
		project: "gpuapp",
		image:   "nvidia/cuda:latest",
		args: arguments.Args{
			Gpus:                "2",
			Pull:                "missing",
			HealthInterval:      "0s",
			HealthStartPeriod:   "0s",
			HealthTimeout:       "0s",
			DisableContentTrust: true,
			SigProxy:            true,
			StopSignal:          "SIGTERM",
		},
	},
	{
		name:    "mount_and_tmpfs",
		project: "mounted",
		image:   "alpine:latest",
		args: arguments.Args{
			Mount: []string{
				"type=bind,source=/host,target=/container,readonly",
				"type=volume,source=data,target=/data",
				"type=tmpfs,target=/scratch,tmpfs-size=67108864",
			},
			Tmpfs:               []string{"/run:size=64m,mode=1770"},
			Pull:                "missing",
			HealthInterval:      "0s",
			HealthStartPeriod:   "0s",
			HealthTimeout:       "0s",
			DisableContentTrust: true,
			SigProxy:            true,
			StopSignal:          "SIGTERM",
		},
	},
	{
		name:    "nomad_options",
		project: "configured",
		image:   "alpine:latest",
		opts: NomadOptions{
			Datacenters: []string{"east", "west"},
			Region:      "us",
			Namespace:   "dev",
			Type:        "batch",
			Count:       3,
		},
		args: arguments.Args{
			Pull:                "missing",
			HealthInterval:      "0s",
			HealthStartPeriod:   "0s",
			HealthTimeout:       "0s",
			DisableContentTrust: true,
			SigProxy:            true,
			StopSignal:          "SIGTERM",
		},
	},
}

// TestMarshalNomadHCL_ParseSyntax verifies that every generated HCL document
// is syntactically valid HCL2. This is Option 1 validation: it catches bad
// indentation, unquoted attribute names, malformed blocks, etc., but does not
// know about Nomad's schema.
func TestMarshalNomadHCL_ParseSyntax(t *testing.T) {
	for _, tc := range nomadTestCases {
		t.Run(tc.name, func(t *testing.T) {
			args := tc.args
			out, warnings, errs := ToNomad(tc.project, &args, makeArgs(tc.image, tc.command...), tc.opts)
			if errs != nil && errs.ErrorOrNil() != nil {
				t.Fatalf("ToNomad returned errors: %v", errs)
			}
			_ = warnings // warnings are informational only

			job, ok := out.(*NomadJob)
			if !ok || job == nil || job.Job == nil {
				t.Fatalf("ToNomad did not return a *NomadJob: %T", out)
			}

			hcl, err := MarshalNomadHCL(job)
			if err != nil {
				t.Fatalf("MarshalNomadHCL failed: %v", err)
			}

			parser := hclparse.NewParser()
			_, diags := parser.ParseHCL(hcl, tc.name+".nomad")
			if diags.HasErrors() {
				t.Fatalf("HCL syntax errors:\n%s\n--- generated HCL ---\n%s", diags.Error(), hcl)
			}
		})
	}
}

// TestMarshalNomadHCL_NomadSchema verifies that every generated HCL document
// parses cleanly through Nomad's own HCL2 parser (jobspec2). This is Option 3
// validation: it catches schema errors (wrong attribute names, wrong types,
// unknown blocks) that pure HCL syntax parsing misses.
func TestMarshalNomadHCL_NomadSchema(t *testing.T) {
	for _, tc := range nomadTestCases {
		t.Run(tc.name, func(t *testing.T) {
			args := tc.args
			out, _, errs := ToNomad(tc.project, &args, makeArgs(tc.image, tc.command...), tc.opts)
			if errs != nil && errs.ErrorOrNil() != nil {
				t.Fatalf("ToNomad returned errors: %v", errs)
			}

			job := out.(*NomadJob)
			hcl, err := MarshalNomadHCL(job)
			if err != nil {
				t.Fatalf("MarshalNomadHCL failed: %v", err)
			}

			parsed, err := jobspec2.Parse(tc.name+".nomad", bytes.NewReader(hcl))
			if err != nil {
				t.Fatalf("Nomad schema parse failed: %v\n--- generated HCL ---\n%s", err, hcl)
			}

			if parsed.Name == nil || *parsed.Name != job.Job.Name {
				t.Errorf("parsed job name = %v, want %q", parsed.Name, job.Job.Name)
			}
			if len(parsed.TaskGroups) != 1 {
				t.Errorf("expected 1 task group, got %d", len(parsed.TaskGroups))
			} else {
				tg := parsed.TaskGroups[0]
				if len(tg.Tasks) != 1 {
					t.Errorf("expected 1 task in group, got %d", len(tg.Tasks))
				} else {
					task := tg.Tasks[0]
					if task.Driver != "docker" {
						t.Errorf("task driver = %q, want docker", task.Driver)
					}
					img, hasImage := task.Config["image"]
					if !hasImage || img != tc.image {
						t.Errorf("task config.image = %v, want %q", img, tc.image)
					}
				}
			}
		})
	}
}
