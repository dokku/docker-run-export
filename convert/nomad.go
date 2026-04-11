package convert

import (
	"docker-run-export/arguments"
	"encoding/json"
	"fmt"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/compose-spec/compose-go/v2/types"
	"github.com/hashicorp/go-multierror"
	"github.com/hashicorp/hcl/v2/hclwrite"
	"github.com/josegonzalez/cli-skeleton/command"
	"github.com/mattn/go-shellwords"
	"github.com/zclconf/go-cty/cty"
)

// NomadOptions holds Nomad-specific configuration that has no docker run equivalent
type NomadOptions struct {
	Datacenters []string
	Region      string
	Namespace   string
	Type        string
	Count       int
}

// NomadJob wraps the top-level Job object for the Nomad JSON API format
type NomadJob struct {
	Job *NomadJobSpec `json:"Job"`
}

// NomadJobSpec represents a Nomad job specification
type NomadJobSpec struct {
	ID          string           `json:"ID"`
	Name        string           `json:"Name"`
	Type        string           `json:"Type"`
	Datacenters []string         `json:"Datacenters"`
	Region      string           `json:"Region,omitempty"`
	Namespace   string           `json:"Namespace,omitempty"`
	TaskGroups  []NomadTaskGroup `json:"TaskGroups"`
}

// NomadTaskGroup represents a Nomad task group
type NomadTaskGroup struct {
	Name          string              `json:"Name"`
	Count         int                 `json:"Count"`
	Networks      []NomadNetwork      `json:"Networks,omitempty"`
	Services      []NomadService      `json:"Services,omitempty"`
	RestartPolicy *NomadRestartPolicy `json:"RestartPolicy,omitempty"`
	Tasks         []NomadTask         `json:"Tasks"`
}

// NomadRestartPolicy represents a Nomad restart stanza at the group level
type NomadRestartPolicy struct {
	Attempts int    `json:"Attempts"`
	Interval int64  `json:"Interval,omitempty"`
	Delay    int64  `json:"Delay,omitempty"`
	Mode     string `json:"Mode,omitempty"`
}

// NomadService represents a service stanza at the group level
type NomadService struct {
	Name     string              `json:"Name"`
	Provider string              `json:"Provider,omitempty"`
	Checks   []NomadServiceCheck `json:"Checks,omitempty"`
}

// NomadServiceCheck represents a check stanza inside a service
type NomadServiceCheck struct {
	Name         string             `json:"Name,omitempty"`
	Type         string             `json:"Type"`
	Command      string             `json:"Command,omitempty"`
	Args         []string           `json:"Args,omitempty"`
	TaskName     string             `json:"TaskName,omitempty"`
	Interval     int64              `json:"Interval,omitempty"`
	Timeout      int64              `json:"Timeout,omitempty"`
	CheckRestart *NomadCheckRestart `json:"CheckRestart,omitempty"`
}

// NomadCheckRestart controls when a failing check triggers a task restart
type NomadCheckRestart struct {
	Limit int   `json:"Limit,omitempty"`
	Grace int64 `json:"Grace,omitempty"`
}

// NomadNetwork represents a Nomad network stanza
type NomadNetwork struct {
	Mode          string      `json:"Mode,omitempty"`
	DynamicPorts  []NomadPort `json:"DynamicPorts,omitempty"`
	ReservedPorts []NomadPort `json:"ReservedPorts,omitempty"`
}

// NomadPort represents a Nomad port definition (dynamic or reserved)
type NomadPort struct {
	Label string `json:"Label"`
	To    int    `json:"To,omitempty"`
	Value int    `json:"Value,omitempty"`
}

// NomadTask represents a single task within a task group
type NomadTask struct {
	Name        string                 `json:"Name"`
	Driver      string                 `json:"Driver"`
	Config      map[string]interface{} `json:"Config"`
	Env         map[string]string      `json:"Env,omitempty"`
	Resources   *NomadResources        `json:"Resources,omitempty"`
	User        string                 `json:"User,omitempty"`
	KillSignal  string                 `json:"KillSignal,omitempty"`
	KillTimeout int64                  `json:"KillTimeout,omitempty"`
}

// NomadResources represents the resource requirements for a Nomad task
type NomadResources struct {
	CPU      int           `json:"CPU,omitempty"`
	MemoryMB int           `json:"MemoryMB,omitempty"`
	Devices  []NomadDevice `json:"Devices,omitempty"`
}

// NomadDevice represents a device stanza under resources
type NomadDevice struct {
	Name  string `json:"Name"`
	Count uint64 `json:"Count,omitempty"`
}

// ToNomad converts docker run arguments to a Nomad job specification
func ToNomad(projectName string, c *arguments.Args, arguments map[string]command.Argument, nomadOpts NomadOptions) (interface{}, *multierror.Error, *multierror.Error) {
	var warnings *multierror.Error
	var errs *multierror.Error

	taskName := "app"
	if len(c.ContainerName) > 0 {
		taskName = c.ContainerName
	}

	jobName := projectName
	if len(jobName) == 0 {
		jobName = taskName
	}

	datacenters := nomadOpts.Datacenters
	if len(datacenters) == 0 {
		datacenters = []string{"dc1"}
	}

	jobType := nomadOpts.Type
	if len(jobType) == 0 {
		jobType = "service"
	}

	count := nomadOpts.Count
	if count <= 0 {
		count = 1
	}

	job := &NomadJobSpec{
		ID:          jobName,
		Name:        jobName,
		Type:        jobType,
		Datacenters: datacenters,
		Region:      nomadOpts.Region,
		Namespace:   nomadOpts.Namespace,
	}

	task := NomadTask{
		Name:   taskName,
		Driver: "docker",
		Config: map[string]interface{}{},
	}

	network := NomadNetwork{}
	var portLabels []string

	// image (positional)
	task.Config["image"] = arguments["image"].StringValue()

	// command (positional)
	if len(arguments["command"].ListValue()) > 0 {
		task.Config["args"] = arguments["command"].ListValue()
	}

	// add-host -> config.extra_hosts
	if len(c.AddHost) > 0 {
		task.Config["extra_hosts"] = append([]string{}, c.AddHost...)
	}

	// unsupported: annotation
	if len(c.Annotation) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --annotation property in nomad job spec as the property is not supported"))
	}

	// unsupported: attach
	if len(c.Attach) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --attach property in nomad job spec as the property is not supported"))
	}

	// unsupported: blkio-weight
	if c.BlkioWeight != 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --blkio-weight property in nomad job spec as the property is not supported"))
	}

	// unsupported: blkio-weight-device
	if len(c.BlkioWeightDevice) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --blkio-weight-device property in nomad job spec as the property is not supported"))
	}

	// cap-add / cap-drop
	if len(c.CapAdd) > 0 {
		task.Config["cap_add"] = append([]string{}, c.CapAdd...)
	}
	if len(c.CapDrop) > 0 {
		task.Config["cap_drop"] = append([]string{}, c.CapDrop...)
	}

	// cgroupns -> config.cgroupns
	if len(c.Cgroupns) > 0 {
		task.Config["cgroupns"] = c.Cgroupns
	}

	// unsupported: cgroup-parent
	if len(c.CgroupParent) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --cgroup-parent property in nomad job spec as the property is not supported"))
	}

	// unsupported: cidfile
	if len(c.Cidfile) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --cidfile property in nomad job spec as the property is not supported"))
	}

	// cpu-period -> config.cpu_cfs_period
	if c.CpuPeriod > 0 {
		task.Config["cpu_cfs_period"] = int64(c.CpuPeriod)
	}

	// unsupported: cpu-quota
	if c.CpuQuota > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --cpu-quota property in nomad job spec as the property is not supported"))
	}

	// unsupported: cpu-rt-period
	if c.CpuRtPeriod > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --cpu-rt-period property in nomad job spec as the property is not supported"))
	}

	// unsupported: cpu-rt-runtime
	if c.CpuRtRuntime > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --cpu-rt-runtime property in nomad job spec as the property is not supported"))
	}

	// cpus -> resources.CPU (MHz); 1.0 CPU = 1000 MHz
	// cpu-shares -> resources.CPU proportionally if --cpus not set
	var resources *NomadResources
	if c.Cpus > 0 {
		if resources == nil {
			resources = &NomadResources{}
		}
		resources.CPU = int(c.Cpus * 1000)
	} else if c.CpuShares > 0 {
		if resources == nil {
			resources = &NomadResources{}
		}
		// Proportional: 1024 shares ~= 1000 MHz
		resources.CPU = c.CpuShares * 1000 / 1024
	}

	// cpuset-cpus -> config.cpuset_cpus
	if len(c.CpusetCpus) > 0 {
		task.Config["cpuset_cpus"] = c.CpusetCpus
	}

	// unsupported: cpuset-mems
	if len(c.CpusetMems) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --cpuset-mems property in nomad job spec as the property is not supported"))
	}

	// unsupported: detach
	if c.Detach {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --detach property in nomad job spec as the property is not supported"))
	}

	// unsupported: detach-keys
	if len(c.DetachKeys) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --detach-keys property in nomad job spec as the property is not supported"))
	}

	// device -> config.devices (list of maps)
	if len(c.Device) > 0 {
		var devices []map[string]interface{}
		for _, device := range c.Device {
			parts := strings.SplitN(device, ":", 3)
			d := map[string]interface{}{
				"host_path": parts[0],
			}
			if len(parts) >= 2 {
				d["container_path"] = parts[1]
			}
			if len(parts) >= 3 {
				d["cgroup_permissions"] = parts[2]
			}
			devices = append(devices, d)
		}
		task.Config["devices"] = devices
	}

	// unsupported: device-cgroup-rule
	if len(c.DeviceCgroupRule) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --device-cgroup-rule property in nomad job spec as the property is not supported"))
	}

	// unsupported: device-read-bps
	if len(c.DeviceReadBps) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --device-read-bps property in nomad job spec as the property is not supported"))
	}

	// unsupported: device-read-iops
	if len(c.DeviceReadIops) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --device-read-iops property in nomad job spec as the property is not supported"))
	}

	// unsupported: device-write-bps
	if len(c.DeviceWriteBps) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --device-write-bps property in nomad job spec as the property is not supported"))
	}

	// unsupported: device-write-iops
	if len(c.DeviceWriteIops) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --device-write-iops property in nomad job spec as the property is not supported"))
	}

	// unsupported: disable-content-trust
	if !c.DisableContentTrust {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --disable-content-trust property in nomad job spec as the property is not supported"))
	}

	// dns -> config.dns_servers
	if len(c.Dns) > 0 {
		task.Config["dns_servers"] = append([]string{}, c.Dns...)
	}

	// dns-option -> config.dns_options
	if len(c.DnsOption) > 0 {
		task.Config["dns_options"] = append([]string{}, c.DnsOption...)
	}

	// dns-search -> config.dns_search_domains
	if len(c.DnsSearch) > 0 {
		task.Config["dns_search_domains"] = append([]string{}, c.DnsSearch...)
	}

	// unsupported: domainname
	if len(c.Domainname) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --domainname property in nomad job spec as the property is not supported"))
	}

	// entrypoint -> config.entrypoint
	if len(c.Entrypoint) > 0 {
		parsed, err := shellwords.Parse(c.Entrypoint)
		if err != nil {
			errs = multierror.Append(errs, fmt.Errorf("unable to parse --entrypoint flag to slice: %w", err))
		} else {
			task.Config["entrypoint"] = parsed
		}
	}

	// env -> task.Env
	if len(c.Env) > 0 {
		task.Env = map[string]string{}
		for _, env := range c.Env {
			parts := strings.SplitN(env, "=", 2)
			if len(parts) == 2 {
				task.Env[parts[0]] = parts[1]
			} else {
				task.Env[parts[0]] = ""
			}
		}
	}

	// unsupported: env-file
	if len(c.EnvFile) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --env-file property in nomad job spec as the property is not supported"))
	}

	// unsupported: expose
	if len(c.Expose) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --expose property in nomad job spec as the property is not supported"))
	}

	// unsupported: gpus
	// gpus -> resources.device { name = "nvidia/gpu", count = N }
	if len(c.Gpus) > 0 {
		device, gErr := parseDockerGpus(c.Gpus)
		if gErr != nil {
			warnings = multierror.Append(warnings, gErr)
		} else {
			if resources == nil {
				resources = &NomadResources{}
			}
			resources.Devices = append(resources.Devices, device)
		}
	}

	// group-add -> config.group_add
	if len(c.GroupAdd) > 0 {
		task.Config["group_add"] = append([]string{}, c.GroupAdd...)
	}

	// health-cmd -> group service { check { type = "script" } }
	var healthService *NomadService
	if len(c.HealthCmd) > 0 {
		if c.NoHealthcheck {
			warnings = multierror.Append(warnings, fmt.Errorf("--no-healthcheck conflicts with --health-cmd; honoring --health-cmd"))
		}
		parts, parseErr := shellwords.Parse(c.HealthCmd)
		if parseErr != nil {
			errs = multierror.Append(errs, fmt.Errorf("unable to parse --health-cmd: %w", parseErr))
		} else if len(parts) == 0 {
			errs = multierror.Append(errs, fmt.Errorf("unable to parse --health-cmd: empty command"))
		} else {
			check := NomadServiceCheck{
				Name:     fmt.Sprintf("%s-health", taskName),
				Type:     "script",
				Command:  parts[0],
				Args:     parts[1:],
				TaskName: taskName,
			}
			if c.HealthInterval != "" && c.HealthInterval != "0s" {
				d, dErr := time.ParseDuration(c.HealthInterval)
				if dErr != nil {
					errs = multierror.Append(errs, fmt.Errorf("unable to parse --health-interval: %w", dErr))
				} else {
					check.Interval = int64(d)
				}
			}
			if c.HealthTimeout != "" && c.HealthTimeout != "0s" {
				d, dErr := time.ParseDuration(c.HealthTimeout)
				if dErr != nil {
					errs = multierror.Append(errs, fmt.Errorf("unable to parse --health-timeout: %w", dErr))
				} else {
					check.Timeout = int64(d)
				}
			}
			if c.HealthRetries > 0 {
				if check.CheckRestart == nil {
					check.CheckRestart = &NomadCheckRestart{}
				}
				check.CheckRestart.Limit = int(c.HealthRetries)
			}
			if c.HealthStartPeriod != "" && c.HealthStartPeriod != "0s" {
				d, dErr := time.ParseDuration(c.HealthStartPeriod)
				if dErr != nil {
					errs = multierror.Append(errs, fmt.Errorf("unable to parse --health-start-period: %w", dErr))
				} else {
					if check.CheckRestart == nil {
						check.CheckRestart = &NomadCheckRestart{}
					}
					check.CheckRestart.Grace = int64(d)
				}
			}
			healthService = &NomadService{
				Name:     taskName,
				Provider: "consul",
				Checks:   []NomadServiceCheck{check},
			}
		}
	} else {
		// Health sub-flags without --health-cmd have nothing to attach to.
		if c.HealthInterval != "" && c.HealthInterval != "0s" {
			warnings = multierror.Append(warnings, fmt.Errorf("--health-interval has no effect without --health-cmd"))
		}
		if c.HealthRetries != 0 {
			warnings = multierror.Append(warnings, fmt.Errorf("--health-retries has no effect without --health-cmd"))
		}
		if c.HealthStartPeriod != "" && c.HealthStartPeriod != "0s" {
			warnings = multierror.Append(warnings, fmt.Errorf("--health-start-period has no effect without --health-cmd"))
		}
		if c.HealthTimeout != "" && c.HealthTimeout != "0s" {
			warnings = multierror.Append(warnings, fmt.Errorf("--health-timeout has no effect without --health-cmd"))
		}
	}

	// hostname -> config.hostname
	if len(c.Hostname) > 0 {
		task.Config["hostname"] = c.Hostname
	}

	// init -> config.init
	if c.Init {
		task.Config["init"] = true
	}

	// interactive -> config.interactive
	if c.Interactive {
		task.Config["interactive"] = true
	}

	// ip -> config.ipv4_address
	if len(c.Ip) > 0 {
		task.Config["ipv4_address"] = c.Ip
	}

	// ip6 -> config.ipv6_address
	if len(c.Ip6) > 0 {
		task.Config["ipv6_address"] = c.Ip6
	}

	// ipc -> config.ipc_mode
	if len(c.Ipc) > 0 {
		task.Config["ipc_mode"] = c.Ipc
	}

	// isolation -> config.isolation
	if len(c.Isolation) > 0 {
		task.Config["isolation"] = c.Isolation
	}

	// unsupported: kernel-memory
	if c.KernelMemory != 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --kernel-memory property in nomad job spec as the property is not supported"))
	}

	// label -> config.labels
	if len(c.Label) > 0 {
		labels := map[string]string{}
		for _, label := range c.Label {
			parts := strings.SplitN(label, "=", 2)
			if len(parts) == 2 {
				labels[parts[0]] = parts[1]
			} else {
				labels[parts[0]] = ""
			}
		}
		task.Config["labels"] = labels
	}

	// unsupported: label-file
	if len(c.LabelFile) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --label-file property in nomad job spec as the property is not supported"))
	}

	// unsupported: link
	if len(c.Link) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --link property in nomad job spec as the property is not supported"))
	}

	// unsupported: link-local-ip
	if len(c.LinkLocalIP) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --link-local-ip property in nomad job spec as the property is not supported"))
	}

	// log-driver / log-opt -> config.logging
	if len(c.LogDriver) > 0 || len(c.LogOpt) > 0 {
		logging := map[string]interface{}{}
		if len(c.LogDriver) > 0 {
			logging["type"] = c.LogDriver
		}
		if len(c.LogOpt) > 0 {
			cfg := map[string]string{}
			for _, opt := range c.LogOpt {
				parts := strings.SplitN(opt, "=", 2)
				if len(parts) == 2 {
					cfg[parts[0]] = parts[1]
				} else {
					cfg[parts[0]] = ""
				}
			}
			logging["config"] = cfg
		}
		task.Config["logging"] = logging
	}

	// mac-address -> config.mac_address
	if len(c.Mac) > 0 {
		task.Config["mac_address"] = c.Mac
	}

	// memory -> resources.MemoryMB
	if c.Memory > 0 {
		if resources == nil {
			resources = &NomadResources{}
		}
		resources.MemoryMB = int(c.Memory / (1024 * 1024))
	}

	// unsupported: memory-reservation
	if c.MemoryReservation > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --memory-reservation property in nomad job spec as the property is not supported"))
	}

	// unsupported: memory-swap
	if c.MemorySwap > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --memory-swap property in nomad job spec as the property is not supported"))
	}

	// unsupported: memory-swappiness
	if c.MemorySwappiness > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --memory-swappiness property in nomad job spec as the property is not supported"))
	}

	// mount -> config.mount (list of bind/volume/tmpfs mount blocks)
	var mounts []map[string]interface{}
	if len(c.Mount) > 0 {
		for _, value := range c.Mount {
			mount, mErr := parseDockerMount(value)
			if mErr != nil {
				errs = multierror.Append(errs, mErr)
				continue
			}
			mounts = append(mounts, mount)
		}
	}

	// network -> network.Mode or config.network_mode
	if len(c.Network) > 0 {
		switch c.Network {
		case "host", "none", "bridge":
			network.Mode = c.Network
		default:
			task.Config["network_mode"] = c.Network
		}
	}

	// network-alias -> config.network_aliases
	if len(c.NetworkAlias) > 0 {
		task.Config["network_aliases"] = append([]string{}, c.NetworkAlias...)
	}

	// no-healthcheck -> task.config.healthchecks { disable = true }
	if c.NoHealthcheck && len(c.HealthCmd) == 0 {
		task.Config["healthchecks"] = map[string]interface{}{
			"disable": true,
		}
	}

	// unsupported: oom-kill-disable
	if c.OomKillDisable {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --oom-kill-disable property in nomad job spec as the property is not supported"))
	}

	// oom-score-adj -> config.oom_score_adj
	if c.OomScore != 0 {
		task.Config["oom_score_adj"] = c.OomScore
	}

	// pid -> config.pid_mode
	if len(c.Pid) > 0 {
		task.Config["pid_mode"] = c.Pid
	}

	// pids-limit -> config.pids_limit
	if c.PidsLimit != 0 {
		task.Config["pids_limit"] = int64(c.PidsLimit)
	}

	// unsupported: platform
	if len(c.Platform) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --platform property in nomad job spec as the property is not supported"))
	}

	// privileged -> config.privileged
	if c.Privileged {
		task.Config["privileged"] = true
	}

	// publish -> network ports + config.ports
	if len(c.Publish) > 0 {
		for _, value := range c.Publish {
			parsed, err := types.ParsePortConfig(value)
			if err != nil {
				errs = multierror.Append(errs, fmt.Errorf("unable to parse --publish flag: %w", err))
				continue
			}
			for _, p := range parsed {
				containerPort := int(p.Target)
				label := fmt.Sprintf("port_%d", containerPort)
				if p.Protocol != "" && p.Protocol != "tcp" {
					label = fmt.Sprintf("port_%d_%s", containerPort, p.Protocol)
				}

				portEntry := NomadPort{
					Label: label,
					To:    containerPort,
				}

				if len(p.Published) > 0 {
					hostPort, pErr := strconv.Atoi(p.Published)
					if pErr != nil {
						errs = multierror.Append(errs, fmt.Errorf("unable to parse --publish host port: %w", pErr))
						continue
					}
					if hostPort > 0 {
						portEntry.Value = hostPort
						network.ReservedPorts = append(network.ReservedPorts, portEntry)
						portLabels = append(portLabels, label)
						continue
					}
				}

				network.DynamicPorts = append(network.DynamicPorts, portEntry)
				portLabels = append(portLabels, label)
			}
		}
		if len(portLabels) > 0 {
			task.Config["ports"] = portLabels
			if network.Mode == "" {
				network.Mode = "bridge"
			}
		}
	}

	// unsupported: publish-all
	if c.PublishAll {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --publish-all property in nomad job spec as the property is not supported"))
	}

	// pull -> config.force_pull (only --pull always has a direct mapping)
	switch c.Pull {
	case "", "missing":
		// default docker behavior; also Nomad docker driver default. nothing to do.
	case "always":
		task.Config["force_pull"] = true
	case "never":
		warnings = multierror.Append(warnings, fmt.Errorf("--pull never is not supported by the Nomad docker driver; image will be pulled if missing"))
	default:
		warnings = multierror.Append(warnings, fmt.Errorf("unknown --pull value %q; ignoring", c.Pull))
	}

	// read-only -> config.readonly_rootfs
	if c.ReadOnly {
		task.Config["readonly_rootfs"] = true
	}

	// restart -> group restart policy
	var restartPolicy *NomadRestartPolicy
	if len(c.Restart) > 0 {
		mode, maxRetries, rErr := parseDockerRestart(c.Restart)
		if rErr != nil {
			errs = multierror.Append(errs, rErr)
		} else {
			switch mode {
			case "no":
				// attempts = 0 + mode = fail means "never restart"
				restartPolicy = &NomadRestartPolicy{Attempts: 0, Mode: "fail"}
			case "on-failure":
				restartPolicy = &NomadRestartPolicy{Attempts: maxRetries, Mode: "fail"}
			case "always", "unless-stopped":
				// mode = delay loops within the interval indefinitely; Nomad will not
				// restart a cleanly-exited task, so this is an approximation of
				// docker's "always" semantics.
				restartPolicy = &NomadRestartPolicy{Attempts: 0, Mode: "delay"}
				warnings = multierror.Append(warnings, fmt.Errorf("--restart %s is approximated by Nomad mode=delay; Nomad does not restart tasks that exit successfully", mode))
			}
		}
	}

	// unsupported: rm
	if c.Rm {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --rm property in nomad job spec as the property is not supported"))
	}

	// runtime -> config.runtime
	if len(c.Runtime) > 0 {
		task.Config["runtime"] = c.Runtime
	}

	// security-opt -> config.security_opt
	if len(c.SecurityOpt) > 0 {
		task.Config["security_opt"] = append([]string{}, c.SecurityOpt...)
	}

	// shm-size -> config.shm_size (bytes)
	if c.ShmSize != 0 {
		task.Config["shm_size"] = c.ShmSize
	}

	// unsupported: sig-proxy
	if !c.SigProxy {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --sig-proxy property in nomad job spec as the property is not supported"))
	}

	// stop-signal -> task.KillSignal
	if len(c.StopSignal) > 0 && c.StopSignal != "SIGTERM" {
		task.KillSignal = c.StopSignal
	}

	// stop-timeout -> task.KillTimeout (seconds -> nanoseconds)
	if c.StopTimeout > 0 {
		task.KillTimeout = int64(time.Duration(c.StopTimeout) * time.Second)
	}

	// storage-opt -> config.storage_opt
	if len(c.StorageOpt) > 0 {
		storageOpt := map[string]string{}
		for _, opt := range c.StorageOpt {
			parts := strings.SplitN(opt, "=", 2)
			if len(parts) == 2 {
				storageOpt[parts[0]] = parts[1]
			} else {
				storageOpt[parts[0]] = ""
			}
		}
		task.Config["storage_opt"] = storageOpt
	}

	// sysctl -> config.sysctl
	if len(c.Sysctl) > 0 {
		sysctl := map[string]string{}
		for k, v := range c.Sysctl {
			sysctl[k] = v
		}
		task.Config["sysctl"] = sysctl
	}

	// tmpfs -> config.mount { type = "tmpfs", target = ... }
	if len(c.Tmpfs) > 0 {
		for _, value := range c.Tmpfs {
			mount, tErr := parseDockerTmpfs(value)
			if tErr != nil {
				errs = multierror.Append(errs, tErr)
				continue
			}
			mounts = append(mounts, mount)
		}
	}
	if len(mounts) > 0 {
		task.Config["mount"] = mounts
	}

	// tty -> config.tty
	if c.Tty {
		task.Config["tty"] = true
	}

	// ulimit -> config.ulimit
	if len(c.Ulimit) > 0 {
		ulimits := map[string]string{}
		for _, value := range c.Ulimit {
			name, limits := extractParts(value, "=")
			soft, hard := extractParts(limits, ":")
			if hard == "" {
				hard = soft
			}
			ulimits[name] = fmt.Sprintf("%s:%s", soft, hard)
		}
		task.Config["ulimit"] = ulimits
	}

	// user -> task.User
	if len(c.User) > 0 {
		task.User = c.User
	}

	// userns -> config.userns_mode
	if len(c.Userns) > 0 {
		task.Config["userns_mode"] = c.Userns
	}

	// uts -> config.uts_mode
	if len(c.Uts) > 0 {
		task.Config["uts_mode"] = c.Uts
	}

	// volume -> config.volumes (Nomad accepts host:container[:mode] strings directly)
	if len(c.Volume) > 0 {
		volumes := append([]string{}, c.Volume...)
		task.Config["volumes"] = volumes
	}

	// volume-driver -> config.volume_driver
	if len(c.VolumeDriver) > 0 {
		task.Config["volume_driver"] = c.VolumeDriver
	}

	// unsupported: volumes-from
	if len(c.VolumesFrom) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --volumes-from property in nomad job spec as the property is not supported"))
	}

	// workdir -> config.work_dir
	if len(c.Workdir) > 0 {
		task.Config["work_dir"] = c.Workdir
	}

	task.Resources = resources

	group := NomadTaskGroup{
		Name:  taskName,
		Count: count,
		Tasks: []NomadTask{task},
	}
	if network.Mode != "" || len(network.DynamicPorts) > 0 || len(network.ReservedPorts) > 0 {
		group.Networks = []NomadNetwork{network}
	}
	if healthService != nil {
		group.Services = []NomadService{*healthService}
	}
	if restartPolicy != nil {
		group.RestartPolicy = restartPolicy
	}

	job.TaskGroups = []NomadTaskGroup{group}

	return &NomadJob{Job: job}, warnings, errs
}

// MarshalNomadJSON marshals a Nomad job to the Nomad API-compatible JSON format
func MarshalNomadJSON(job *NomadJob) ([]byte, error) {
	return json.MarshalIndent(job, "", "  ")
}

// MarshalNomadHCL marshals a Nomad job to HCL format
func MarshalNomadHCL(job *NomadJob) ([]byte, error) {
	f := hclwrite.NewEmptyFile()
	rootBody := f.Body()

	spec := job.Job
	jobBlock := rootBody.AppendNewBlock("job", []string{spec.Name})
	jobBody := jobBlock.Body()
	jobBody.SetAttributeValue("datacenters", ctyStringList(spec.Datacenters))
	jobBody.SetAttributeValue("type", cty.StringVal(spec.Type))
	if spec.Region != "" {
		jobBody.SetAttributeValue("region", cty.StringVal(spec.Region))
	}
	if spec.Namespace != "" {
		jobBody.SetAttributeValue("namespace", cty.StringVal(spec.Namespace))
	}

	for _, tg := range spec.TaskGroups {
		writeTaskGroup(jobBody, tg)
	}

	return f.Bytes(), nil
}

// writeTaskGroup appends a Nomad group block to the parent body
func writeTaskGroup(parent *hclwrite.Body, tg NomadTaskGroup) {
	parent.AppendNewline()
	groupBlock := parent.AppendNewBlock("group", []string{tg.Name})
	groupBody := groupBlock.Body()
	groupBody.SetAttributeValue("count", cty.NumberIntVal(int64(tg.Count)))

	for _, net := range tg.Networks {
		writeNetwork(groupBody, net)
	}

	if tg.RestartPolicy != nil {
		writeRestartPolicy(groupBody, tg.RestartPolicy)
	}

	for _, svc := range tg.Services {
		writeService(groupBody, svc)
	}

	for _, task := range tg.Tasks {
		writeTask(groupBody, task)
	}
}

// writeRestartPolicy appends a restart block to the parent (group) body
func writeRestartPolicy(parent *hclwrite.Body, rp *NomadRestartPolicy) {
	parent.AppendNewline()
	block := parent.AppendNewBlock("restart", nil)
	body := block.Body()
	body.SetAttributeValue("attempts", cty.NumberIntVal(int64(rp.Attempts)))
	if rp.Interval > 0 {
		body.SetAttributeValue("interval", cty.StringVal(time.Duration(rp.Interval).String()))
	}
	if rp.Delay > 0 {
		body.SetAttributeValue("delay", cty.StringVal(time.Duration(rp.Delay).String()))
	}
	if rp.Mode != "" {
		body.SetAttributeValue("mode", cty.StringVal(rp.Mode))
	}
}

// writeService appends a service block (with check blocks) to the parent body
func writeService(parent *hclwrite.Body, svc NomadService) {
	parent.AppendNewline()
	svcBlock := parent.AppendNewBlock("service", nil)
	svcBody := svcBlock.Body()
	if svc.Name != "" {
		svcBody.SetAttributeValue("name", cty.StringVal(svc.Name))
	}
	if svc.Provider != "" {
		svcBody.SetAttributeValue("provider", cty.StringVal(svc.Provider))
	}
	for _, check := range svc.Checks {
		writeCheck(svcBody, check)
	}
}

// writeCheck appends a check block to the parent (service) body
func writeCheck(parent *hclwrite.Body, check NomadServiceCheck) {
	parent.AppendNewline()
	checkBlock := parent.AppendNewBlock("check", nil)
	checkBody := checkBlock.Body()
	if check.Name != "" {
		checkBody.SetAttributeValue("name", cty.StringVal(check.Name))
	}
	checkBody.SetAttributeValue("type", cty.StringVal(check.Type))
	if check.Command != "" {
		checkBody.SetAttributeValue("command", cty.StringVal(check.Command))
	}
	if len(check.Args) > 0 {
		checkBody.SetAttributeValue("args", ctyStringList(check.Args))
	}
	if check.TaskName != "" {
		checkBody.SetAttributeValue("task", cty.StringVal(check.TaskName))
	}
	if check.Interval > 0 {
		checkBody.SetAttributeValue("interval", cty.StringVal(time.Duration(check.Interval).String()))
	}
	if check.Timeout > 0 {
		checkBody.SetAttributeValue("timeout", cty.StringVal(time.Duration(check.Timeout).String()))
	}
	if check.CheckRestart != nil && (check.CheckRestart.Limit > 0 || check.CheckRestart.Grace > 0) {
		restartBlock := checkBody.AppendNewBlock("check_restart", nil)
		restartBody := restartBlock.Body()
		if check.CheckRestart.Limit > 0 {
			restartBody.SetAttributeValue("limit", cty.NumberIntVal(int64(check.CheckRestart.Limit)))
		}
		if check.CheckRestart.Grace > 0 {
			restartBody.SetAttributeValue("grace", cty.StringVal(time.Duration(check.CheckRestart.Grace).String()))
		}
	}
}

// writeNetwork appends a network block (with port blocks) to the parent body
func writeNetwork(parent *hclwrite.Body, net NomadNetwork) {
	parent.AppendNewline()
	netBlock := parent.AppendNewBlock("network", nil)
	netBody := netBlock.Body()
	if net.Mode != "" {
		netBody.SetAttributeValue("mode", cty.StringVal(net.Mode))
	}
	for _, p := range net.ReservedPorts {
		portBlock := netBody.AppendNewBlock("port", []string{p.Label})
		portBody := portBlock.Body()
		if p.Value > 0 {
			portBody.SetAttributeValue("static", cty.NumberIntVal(int64(p.Value)))
		}
		if p.To > 0 {
			portBody.SetAttributeValue("to", cty.NumberIntVal(int64(p.To)))
		}
	}
	for _, p := range net.DynamicPorts {
		portBlock := netBody.AppendNewBlock("port", []string{p.Label})
		portBody := portBlock.Body()
		if p.To > 0 {
			portBody.SetAttributeValue("to", cty.NumberIntVal(int64(p.To)))
		}
	}
}

// writeTask appends a task block to the parent body
func writeTask(parent *hclwrite.Body, task NomadTask) {
	parent.AppendNewline()
	taskBlock := parent.AppendNewBlock("task", []string{task.Name})
	taskBody := taskBlock.Body()
	taskBody.SetAttributeValue("driver", cty.StringVal(task.Driver))

	if task.User != "" {
		taskBody.SetAttributeValue("user", cty.StringVal(task.User))
	}
	if task.KillSignal != "" {
		taskBody.SetAttributeValue("kill_signal", cty.StringVal(task.KillSignal))
	}
	if task.KillTimeout > 0 {
		taskBody.SetAttributeValue("kill_timeout", cty.StringVal(time.Duration(task.KillTimeout).String()))
	}

	// config block
	taskBody.AppendNewline()
	configBlock := taskBody.AppendNewBlock("config", nil)
	writeConfigBody(configBlock.Body(), task.Config)

	// env block
	if len(task.Env) > 0 {
		taskBody.AppendNewline()
		envBlock := taskBody.AppendNewBlock("env", nil)
		envBody := envBlock.Body()
		for _, k := range sortedKeys(task.Env) {
			envBody.SetAttributeValue(k, cty.StringVal(task.Env[k]))
		}
	}

	// resources block
	if task.Resources != nil && (task.Resources.CPU > 0 || task.Resources.MemoryMB > 0 || len(task.Resources.Devices) > 0) {
		taskBody.AppendNewline()
		resBlock := taskBody.AppendNewBlock("resources", nil)
		resBody := resBlock.Body()
		if task.Resources.CPU > 0 {
			resBody.SetAttributeValue("cpu", cty.NumberIntVal(int64(task.Resources.CPU)))
		}
		if task.Resources.MemoryMB > 0 {
			resBody.SetAttributeValue("memory", cty.NumberIntVal(int64(task.Resources.MemoryMB)))
		}
		for _, device := range task.Resources.Devices {
			deviceBlock := resBody.AppendNewBlock("device", []string{device.Name})
			if device.Count > 0 {
				deviceBlock.Body().SetAttributeValue("count", cty.NumberUIntVal(device.Count))
			}
		}
	}
}

// writeConfigBody fills a Nomad docker driver config block body with the given key/value map
func writeConfigBody(body *hclwrite.Body, config map[string]interface{}) {
	keys := make([]string, 0, len(config))
	for k := range config {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	for _, k := range keys {
		v := config[k]
		switch val := v.(type) {
		case map[string]string:
			// Use attribute syntax with an object value so that keys containing
			// characters that are not valid bare HCL identifiers (e.g., dots in
			// docker labels like "com.example.key") are rendered as quoted keys.
			body.SetAttributeValue(k, ctyStringObject(val))
		case map[string]interface{}:
			block := body.AppendNewBlock(k, nil)
			writeConfigBody(block.Body(), val)
		case []map[string]interface{}:
			for _, entry := range val {
				block := body.AppendNewBlock(k, nil)
				writeConfigBody(block.Body(), entry)
			}
		default:
			if ctyVal, ok := goValueToCty(v); ok {
				body.SetAttributeValue(k, ctyVal)
			}
		}
	}
}

// ctyStringObject converts a map[string]string to a cty object value
func ctyStringObject(m map[string]string) cty.Value {
	if len(m) == 0 {
		return cty.EmptyObjectVal
	}
	out := map[string]cty.Value{}
	for k, v := range m {
		out[k] = cty.StringVal(v)
	}
	return cty.ObjectVal(out)
}

// goValueToCty converts primitive Go values (and slices of them) to cty.Value
func goValueToCty(v interface{}) (cty.Value, bool) {
	switch val := v.(type) {
	case string:
		return cty.StringVal(val), true
	case bool:
		return cty.BoolVal(val), true
	case int:
		return cty.NumberIntVal(int64(val)), true
	case int32:
		return cty.NumberIntVal(int64(val)), true
	case int64:
		return cty.NumberIntVal(val), true
	case float32:
		return cty.NumberFloatVal(float64(val)), true
	case float64:
		return cty.NumberFloatVal(val), true
	case []string:
		return ctyStringList(val), true
	}
	return cty.NilVal, false
}

// ctyStringList converts a []string to a cty list of strings
func ctyStringList(values []string) cty.Value {
	if len(values) == 0 {
		return cty.ListValEmpty(cty.String)
	}
	out := make([]cty.Value, 0, len(values))
	for _, v := range values {
		out = append(out, cty.StringVal(v))
	}
	return cty.ListVal(out)
}

// parseDockerMount parses a docker --mount value into a Nomad docker driver
// mount block. Supported types are bind, volume, and tmpfs. Keys src/dst are
// accepted as synonyms for source/target.
func parseDockerMount(value string) (map[string]interface{}, error) {
	out := map[string]interface{}{}
	bindOpts := map[string]interface{}{}
	volumeOpts := map[string]interface{}{}
	volumeLabels := map[string]string{}
	volumeDriver := map[string]interface{}{}
	volumeDriverOpts := map[string]string{}
	tmpfsOpts := map[string]interface{}{}

	for _, part := range strings.Split(value, ",") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		kv := strings.SplitN(part, "=", 2)
		key := strings.TrimSpace(kv[0])
		val := ""
		if len(kv) == 2 {
			val = strings.TrimSpace(kv[1])
		}
		switch key {
		case "type":
			out["type"] = val
		case "source", "src":
			out["source"] = val
		case "target", "dst", "destination":
			out["target"] = val
		case "readonly", "ro":
			if val == "" || val == "true" || val == "1" {
				out["readonly"] = true
			}
		case "bind-propagation":
			bindOpts["propagation"] = val
		case "volume-nocopy":
			if val == "" || val == "true" || val == "1" {
				volumeOpts["no_copy"] = true
			}
		case "volume-label":
			parts := strings.SplitN(val, "=", 2)
			if len(parts) == 2 {
				volumeLabels[parts[0]] = parts[1]
			} else {
				volumeLabels[parts[0]] = ""
			}
		case "volume-driver":
			volumeDriver["name"] = val
		case "volume-opt":
			parts := strings.SplitN(val, "=", 2)
			if len(parts) == 2 {
				volumeDriverOpts[parts[0]] = parts[1]
			} else {
				volumeDriverOpts[parts[0]] = ""
			}
		case "tmpfs-size":
			size, err := strconv.ParseInt(val, 10, 64)
			if err != nil {
				return nil, fmt.Errorf("unable to parse tmpfs-size %q: %w", val, err)
			}
			tmpfsOpts["size"] = size
		case "tmpfs-mode":
			mode, err := strconv.ParseInt(val, 8, 32)
			if err != nil {
				return nil, fmt.Errorf("unable to parse tmpfs-mode %q: %w", val, err)
			}
			tmpfsOpts["mode"] = int(mode)
		default:
			return nil, fmt.Errorf("unknown --mount key %q in %q", key, value)
		}
	}

	if _, ok := out["type"]; !ok {
		out["type"] = "volume"
	}
	if _, ok := out["target"]; !ok {
		return nil, fmt.Errorf("--mount missing target: %q", value)
	}

	if len(bindOpts) > 0 {
		out["bind_options"] = bindOpts
	}
	if len(volumeLabels) > 0 {
		volumeOpts["labels"] = volumeLabels
	}
	if len(volumeDriverOpts) > 0 {
		volumeDriver["options"] = volumeDriverOpts
	}
	if len(volumeDriver) > 0 {
		volumeOpts["driver_config"] = volumeDriver
	}
	if len(volumeOpts) > 0 {
		out["volume_options"] = volumeOpts
	}
	if len(tmpfsOpts) > 0 {
		out["tmpfs_options"] = tmpfsOpts
	}
	return out, nil
}

// parseDockerTmpfs parses a docker --tmpfs value (e.g. "/tmp" or
// "/tmp:size=64m,mode=1770") into a Nomad docker driver mount block.
func parseDockerTmpfs(value string) (map[string]interface{}, error) {
	target := value
	var rawOpts string
	if idx := strings.Index(value, ":"); idx >= 0 {
		target = value[:idx]
		rawOpts = value[idx+1:]
	}
	if target == "" {
		return nil, fmt.Errorf("--tmpfs missing target: %q", value)
	}
	out := map[string]interface{}{
		"type":   "tmpfs",
		"target": target,
	}
	tmpfsOpts := map[string]interface{}{}
	if rawOpts != "" {
		for _, part := range strings.Split(rawOpts, ",") {
			part = strings.TrimSpace(part)
			if part == "" {
				continue
			}
			kv := strings.SplitN(part, "=", 2)
			if len(kv) != 2 {
				return nil, fmt.Errorf("unknown --tmpfs option %q in %q", part, value)
			}
			key := strings.TrimSpace(kv[0])
			val := strings.TrimSpace(kv[1])
			switch key {
			case "size":
				// Docker accepts values like "64m"; Nomad wants bytes.
				size, err := parseTmpfsSize(val)
				if err != nil {
					return nil, fmt.Errorf("unable to parse --tmpfs size %q: %w", val, err)
				}
				tmpfsOpts["size"] = size
			case "mode":
				mode, err := strconv.ParseInt(val, 8, 32)
				if err != nil {
					return nil, fmt.Errorf("unable to parse --tmpfs mode %q: %w", val, err)
				}
				tmpfsOpts["mode"] = int(mode)
			default:
				return nil, fmt.Errorf("unknown --tmpfs option %q in %q", key, value)
			}
		}
	}
	if len(tmpfsOpts) > 0 {
		out["tmpfs_options"] = tmpfsOpts
	}
	return out, nil
}

// parseTmpfsSize parses a docker-style size value (digits followed by an
// optional k/m/g suffix, case-insensitive) into bytes.
func parseTmpfsSize(value string) (int64, error) {
	value = strings.TrimSpace(value)
	if value == "" {
		return 0, fmt.Errorf("empty size")
	}
	var multiplier int64 = 1
	last := value[len(value)-1]
	switch last {
	case 'k', 'K':
		multiplier = 1024
		value = value[:len(value)-1]
	case 'm', 'M':
		multiplier = 1024 * 1024
		value = value[:len(value)-1]
	case 'g', 'G':
		multiplier = 1024 * 1024 * 1024
		value = value[:len(value)-1]
	}
	n, err := strconv.ParseInt(value, 10, 64)
	if err != nil {
		return 0, err
	}
	return n * multiplier, nil
}

// parseDockerGpus parses a docker --gpus value like "all", "2", or
// "device=0,1" / "count=2,driver=nvidia" into a NomadDevice. Unknown
// driver/capability keys are silently ignored; the device name defaults
// to "nvidia/gpu" because that's the default --gpus provider in docker.
func parseDockerGpus(value string) (NomadDevice, error) {
	device := NomadDevice{Name: "nvidia/gpu", Count: 1}
	trimmed := strings.Trim(value, "\"'")
	if trimmed == "" {
		return device, fmt.Errorf("--gpus value is empty")
	}
	if trimmed == "all" {
		return device, nil
	}
	if n, err := strconv.ParseUint(trimmed, 10, 64); err == nil {
		device.Count = n
		return device, nil
	}
	// Treat as comma-separated key=value pairs.
	for _, part := range strings.Split(trimmed, ",") {
		kv := strings.SplitN(part, "=", 2)
		if len(kv) != 2 {
			continue
		}
		key := strings.TrimSpace(kv[0])
		val := strings.TrimSpace(kv[1])
		switch key {
		case "count":
			if val == "all" {
				device.Count = 1
				continue
			}
			n, err := strconv.ParseUint(val, 10, 64)
			if err != nil {
				return device, fmt.Errorf("unable to parse --gpus count %q: %w", val, err)
			}
			device.Count = n
		case "device", "devices":
			ids := strings.Split(val, ",")
			if len(ids) > 0 {
				device.Count = uint64(len(ids))
			}
		case "driver":
			device.Name = val + "/gpu"
		case "capabilities":
			// Nomad's device stanza doesn't express capabilities; ignore.
		}
	}
	return device, nil
}

// parseDockerRestart parses a docker --restart value like "no", "always",
// "unless-stopped", "on-failure", or "on-failure:N" into a canonical mode
// and maximum retry count. maxRetries is zero unless explicitly set.
func parseDockerRestart(value string) (string, int, error) {
	mode := value
	maxRetries := 0
	if idx := strings.Index(value, ":"); idx >= 0 {
		mode = value[:idx]
		nStr := value[idx+1:]
		n, err := strconv.Atoi(nStr)
		if err != nil {
			return "", 0, fmt.Errorf("unable to parse --restart max retries %q: %w", nStr, err)
		}
		maxRetries = n
	}
	switch mode {
	case "no", "always", "unless-stopped", "on-failure":
		return mode, maxRetries, nil
	default:
		return "", 0, fmt.Errorf("unknown --restart value %q", value)
	}
}

// sortedKeys returns the keys of a map[string]string sorted alphabetically
func sortedKeys(m map[string]string) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}
