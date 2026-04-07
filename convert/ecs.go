package convert

import (
	"docker-run-export/arguments"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/compose-spec/compose-go/v2/types"
	"github.com/hashicorp/go-multierror"
	"github.com/josegonzalez/cli-skeleton/command"
	"github.com/mattn/go-shellwords"
	"gopkg.in/yaml.v2"
)

// ECSOptions holds ECS-specific configuration that has no docker run equivalent
type ECSOptions struct {
	TaskRoleArn             string
	ExecutionRoleArn        string
	RequiresCompatibilities []string
}

// ECSTaskDefinition represents an AWS ECS task definition
type ECSTaskDefinition struct {
	Family                  string                   `json:"family"                             yaml:"Family"`
	ContainerDefinitions    []ECSContainerDefinition `json:"containerDefinitions"               yaml:"ContainerDefinitions"`
	Volumes                 []ECSVolume              `json:"volumes,omitempty"                  yaml:"Volumes,omitempty"`
	NetworkMode             string                   `json:"networkMode,omitempty"              yaml:"NetworkMode,omitempty"`
	PidMode                 string                   `json:"pidMode,omitempty"                  yaml:"PidMode,omitempty"`
	IpcMode                 string                   `json:"ipcMode,omitempty"                  yaml:"IpcMode,omitempty"`
	CPU                     string                   `json:"cpu,omitempty"                      yaml:"Cpu,omitempty"`
	Memory                  string                   `json:"memory,omitempty"                   yaml:"Memory,omitempty"`
	RuntimePlatform         *ECSRuntimePlatform      `json:"runtimePlatform,omitempty"          yaml:"RuntimePlatform,omitempty"`
	TaskRoleArn             string                   `json:"taskRoleArn,omitempty"              yaml:"TaskRoleArn,omitempty"`
	ExecutionRoleArn        string                   `json:"executionRoleArn,omitempty"         yaml:"ExecutionRoleArn,omitempty"`
	RequiresCompatibilities []string                 `json:"requiresCompatibilities,omitempty"   yaml:"RequiresCompatibilities,omitempty"`
}

// ECSContainerDefinition represents a container within an ECS task definition
type ECSContainerDefinition struct {
	Name                   string                  `json:"name"                              yaml:"Name"`
	Image                  string                  `json:"image"                             yaml:"Image"`
	CPU                    int                     `json:"cpu,omitempty"                     yaml:"Cpu,omitempty"`
	Memory                 int                     `json:"memory,omitempty"                  yaml:"Memory,omitempty"`
	MemoryReservation      int                     `json:"memoryReservation,omitempty"       yaml:"MemoryReservation,omitempty"`
	PortMappings           []ECSPortMapping        `json:"portMappings,omitempty"            yaml:"PortMappings,omitempty"`
	Essential              bool                    `json:"essential"                         yaml:"Essential"`
	EntryPoint             []string                `json:"entryPoint,omitempty"              yaml:"EntryPoint,omitempty"`
	Command                []string                `json:"command,omitempty"                 yaml:"Command,omitempty"`
	Environment            []ECSKeyValuePair       `json:"environment,omitempty"             yaml:"Environment,omitempty"`
	MountPoints            []ECSMountPoint         `json:"mountPoints,omitempty"             yaml:"MountPoints,omitempty"`
	VolumesFrom            []ECSVolumeFrom         `json:"volumesFrom,omitempty"             yaml:"VolumesFrom,omitempty"`
	LinuxParameters        *ECSLinuxParameters     `json:"linuxParameters,omitempty"         yaml:"LinuxParameters,omitempty"`
	Hostname               string                  `json:"hostname,omitempty"                yaml:"Hostname,omitempty"`
	User                   string                  `json:"user,omitempty"                    yaml:"User,omitempty"`
	WorkingDirectory       string                  `json:"workingDirectory,omitempty"        yaml:"WorkingDirectory,omitempty"`
	Privileged             bool                    `json:"privileged,omitempty"              yaml:"Privileged,omitempty"`
	ReadonlyRootFilesystem bool                    `json:"readonlyRootFilesystem,omitempty"  yaml:"ReadonlyRootFilesystem,omitempty"`
	DnsServers             []string                `json:"dnsServers,omitempty"              yaml:"DnsServers,omitempty"`
	DnsSearchDomains       []string                `json:"dnsSearchDomains,omitempty"        yaml:"DnsSearchDomains,omitempty"`
	ExtraHosts             []ECSHostEntry          `json:"extraHosts,omitempty"              yaml:"ExtraHosts,omitempty"`
	DockerSecurityOptions  []string                `json:"dockerSecurityOptions,omitempty"   yaml:"DockerSecurityOptions,omitempty"`
	Interactive            bool                    `json:"interactive,omitempty"             yaml:"Interactive,omitempty"`
	PseudoTerminal         bool                    `json:"pseudoTerminal,omitempty"          yaml:"PseudoTerminal,omitempty"`
	DockerLabels           map[string]string       `json:"dockerLabels,omitempty"            yaml:"DockerLabels,omitempty"`
	Ulimits                []ECSUlimit             `json:"ulimits,omitempty"                 yaml:"Ulimits,omitempty"`
	LogConfiguration       *ECSLogConfiguration    `json:"logConfiguration,omitempty"        yaml:"LogConfiguration,omitempty"`
	HealthCheck            *ECSHealthCheck         `json:"healthCheck,omitempty"             yaml:"HealthCheck,omitempty"`
	SystemControls         []ECSSystemControl      `json:"systemControls,omitempty"          yaml:"SystemControls,omitempty"`
	ResourceRequirements   []ECSResourceRequirement `json:"resourceRequirements,omitempty"   yaml:"ResourceRequirements,omitempty"`
	Links                  []string                `json:"links,omitempty"                   yaml:"Links,omitempty"`
	StopTimeout            int                     `json:"stopTimeout,omitempty"             yaml:"StopTimeout,omitempty"`
}

// ECSPortMapping represents a port mapping in an ECS container definition
type ECSPortMapping struct {
	ContainerPort int    `json:"containerPort"          yaml:"ContainerPort"`
	HostPort      int    `json:"hostPort,omitempty"     yaml:"HostPort,omitempty"`
	Protocol      string `json:"protocol,omitempty"     yaml:"Protocol,omitempty"`
}

// ECSKeyValuePair represents a name/value pair for environment variables
type ECSKeyValuePair struct {
	Name  string `json:"name"   yaml:"Name"`
	Value string `json:"value"  yaml:"Value"`
}

// ECSMountPoint represents a mount point in an ECS container definition
type ECSMountPoint struct {
	SourceVolume  string `json:"sourceVolume"           yaml:"SourceVolume"`
	ContainerPath string `json:"containerPath"          yaml:"ContainerPath"`
	ReadOnly      bool   `json:"readOnly,omitempty"     yaml:"ReadOnly,omitempty"`
}

// ECSVolumeFrom represents a volume from another container
type ECSVolumeFrom struct {
	SourceContainer string `json:"sourceContainer"        yaml:"SourceContainer"`
	ReadOnly        bool   `json:"readOnly,omitempty"     yaml:"ReadOnly,omitempty"`
}

// ECSLinuxParameters represents Linux-specific options for an ECS container
type ECSLinuxParameters struct {
	Capabilities       *ECSCapabilities `json:"capabilities,omitempty"       yaml:"Capabilities,omitempty"`
	Devices            []ECSDevice      `json:"devices,omitempty"            yaml:"Devices,omitempty"`
	InitProcessEnabled bool             `json:"initProcessEnabled,omitempty" yaml:"InitProcessEnabled,omitempty"`
	SharedMemorySize   int              `json:"sharedMemorySize,omitempty"   yaml:"SharedMemorySize,omitempty"`
	Tmpfs              []ECSTmpfs       `json:"tmpfs,omitempty"              yaml:"Tmpfs,omitempty"`
	MaxSwap            int              `json:"maxSwap,omitempty"            yaml:"MaxSwap,omitempty"`
	Swappiness         int              `json:"swappiness,omitempty"         yaml:"Swappiness,omitempty"`
}

// ECSCapabilities represents Linux capabilities for an ECS container
type ECSCapabilities struct {
	Add  []string `json:"add,omitempty"   yaml:"Add,omitempty"`
	Drop []string `json:"drop,omitempty"  yaml:"Drop,omitempty"`
}

// ECSDevice represents a host device to expose to an ECS container
type ECSDevice struct {
	HostPath      string   `json:"hostPath"                yaml:"HostPath"`
	ContainerPath string   `json:"containerPath,omitempty" yaml:"ContainerPath,omitempty"`
	Permissions   []string `json:"permissions,omitempty"   yaml:"Permissions,omitempty"`
}

// ECSTmpfs represents a tmpfs mount for an ECS container
type ECSTmpfs struct {
	ContainerPath string   `json:"containerPath"           yaml:"ContainerPath"`
	Size          int      `json:"size"                    yaml:"Size"`
	MountOptions  []string `json:"mountOptions,omitempty"  yaml:"MountOptions,omitempty"`
}

// ECSHostEntry represents an extra host entry
type ECSHostEntry struct {
	Hostname  string `json:"hostname"   yaml:"Hostname"`
	IpAddress string `json:"ipAddress"  yaml:"IpAddress"`
}

// ECSUlimit represents a ulimit setting for an ECS container
type ECSUlimit struct {
	Name      string `json:"name"       yaml:"Name"`
	SoftLimit int    `json:"softLimit"  yaml:"SoftLimit"`
	HardLimit int    `json:"hardLimit"  yaml:"HardLimit"`
}

// ECSLogConfiguration represents the log configuration for an ECS container
type ECSLogConfiguration struct {
	LogDriver string            `json:"logDriver"          yaml:"LogDriver"`
	Options   map[string]string `json:"options,omitempty"  yaml:"Options,omitempty"`
}

// ECSHealthCheck represents a health check configuration for an ECS container
type ECSHealthCheck struct {
	Command     []string `json:"command"                yaml:"Command"`
	Interval    int      `json:"interval,omitempty"     yaml:"Interval,omitempty"`
	Timeout     int      `json:"timeout,omitempty"      yaml:"Timeout,omitempty"`
	Retries     int      `json:"retries,omitempty"      yaml:"Retries,omitempty"`
	StartPeriod int      `json:"startPeriod,omitempty"  yaml:"StartPeriod,omitempty"`
}

// ECSSystemControl represents a sysctl setting for an ECS container
type ECSSystemControl struct {
	Namespace string `json:"namespace"  yaml:"Namespace"`
	Value     string `json:"value"      yaml:"Value"`
}

// ECSResourceRequirement represents a resource requirement (e.g., GPU)
type ECSResourceRequirement struct {
	Value string `json:"value"  yaml:"Value"`
	Type  string `json:"type"   yaml:"Type"`
}

// ECSVolume represents a task-level volume definition
type ECSVolume struct {
	Name string                  `json:"name"             yaml:"Name"`
	Host *ECSHostVolumeProperties `json:"host,omitempty"  yaml:"Host,omitempty"`
}

// ECSHostVolumeProperties represents the host path for a volume
type ECSHostVolumeProperties struct {
	SourcePath string `json:"sourcePath,omitempty"  yaml:"SourcePath,omitempty"`
}

// ECSRuntimePlatform represents the runtime platform for an ECS task
type ECSRuntimePlatform struct {
	CpuArchitecture        string `json:"cpuArchitecture"        yaml:"CpuArchitecture"`
	OperatingSystemFamily  string `json:"operatingSystemFamily"  yaml:"OperatingSystemFamily"`
}

// CloudFormationTemplate represents a CloudFormation template wrapping an ECS task definition
type CloudFormationTemplate struct {
	AWSTemplateFormatVersion string                              `yaml:"AWSTemplateFormatVersion"`
	Resources                map[string]CloudFormationResource   `yaml:"Resources"`
}

// CloudFormationResource represents a CloudFormation resource
type CloudFormationResource struct {
	Type       string             `yaml:"Type"`
	Properties *ECSTaskDefinition `yaml:"Properties"`
}

// ToECS converts docker run arguments to an ECS task definition
func ToECS(projectName string, c *arguments.Args, arguments map[string]command.Argument, ecsOpts ECSOptions) (interface{}, *multierror.Error, *multierror.Error) {
	var warnings *multierror.Error
	var errs *multierror.Error

	containerName := "app"
	if len(c.ContainerName) > 0 {
		containerName = c.ContainerName
	}

	family := projectName
	if len(family) == 0 {
		family = containerName
	}

	taskDef := &ECSTaskDefinition{
		Family: family,
	}

	container := &ECSContainerDefinition{
		Name:      containerName,
		Essential: true,
	}

	var taskVolumes []ECSVolume

	// extra hosts
	for _, hostMap := range c.AddHost {
		parts := strings.SplitN(hostMap, ":", 2)
		if len(parts) == 2 {
			container.ExtraHosts = append(container.ExtraHosts, ECSHostEntry{
				Hostname:  parts[0],
				IpAddress: parts[1],
			})
		}
	}

	// unsupported: annotation
	if len(c.Annotation) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --annotation property in ecs task definition as the property is not supported"))
	}

	// unsupported: attach
	if len(c.Attach) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --attach property in ecs task definition as the property is not supported"))
	}

	// unsupported: blkio-weight
	if c.BlkioWeight != 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --blkio-weight property in ecs task definition as the property is not supported"))
	}

	// unsupported: blkio-weight-device
	if len(c.BlkioWeightDevice) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --blkio-weight-device property in ecs task definition as the property is not supported"))
	}

	// cap-add / cap-drop
	if len(c.CapAdd) > 0 || len(c.CapDrop) > 0 {
		if container.LinuxParameters == nil {
			container.LinuxParameters = &ECSLinuxParameters{}
		}
		if container.LinuxParameters.Capabilities == nil {
			container.LinuxParameters.Capabilities = &ECSCapabilities{}
		}
		container.LinuxParameters.Capabilities.Add = c.CapAdd
		container.LinuxParameters.Capabilities.Drop = c.CapDrop
	}

	// unsupported: cgroupns
	if len(c.Cgroupns) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --cgroupns property in ecs task definition as the property is not supported"))
	}

	// unsupported: cgroup-parent
	if len(c.CgroupParent) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --cgroup-parent property in ecs task definition as the property is not supported"))
	}

	// unsupported: cidfile
	if len(c.Cidfile) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --cidfile property in ecs task definition as the property is not supported"))
	}

	// unsupported: cpu-period
	if c.CpuPeriod > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --cpu-period property in ecs task definition as the property is not supported"))
	}

	// unsupported: cpu-quota
	if c.CpuQuota > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --cpu-quota property in ecs task definition as the property is not supported"))
	}

	// unsupported: cpu-rt-period
	if c.CpuRtPeriod > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --cpu-rt-period property in ecs task definition as the property is not supported"))
	}

	// unsupported: cpu-rt-runtime
	if c.CpuRtRuntime > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --cpu-rt-runtime property in ecs task definition as the property is not supported"))
	}

	// cpus -> task-level cpu (1 vCPU = 1024 units)
	if c.Cpus > 0 {
		cpuUnits := int(c.Cpus * 1024)
		taskDef.CPU = strconv.Itoa(cpuUnits)
	}

	// cpu-shares -> container-level cpu
	if c.CpuShares > 0 {
		container.CPU = c.CpuShares
	}

	// unsupported: cpuset-cpus
	if len(c.CpusetCpus) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --cpuset-cpus property in ecs task definition as the property is not supported"))
	}

	// unsupported: cpuset-mems
	if len(c.CpusetMems) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --cpuset-mems property in ecs task definition as the property is not supported"))
	}

	// unsupported: detach
	if c.Detach {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --detach property in ecs task definition as the property is not supported"))
	}

	// unsupported: detach-keys
	if len(c.DetachKeys) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --detach-keys property in ecs task definition as the property is not supported"))
	}

	// device
	if len(c.Device) > 0 {
		if container.LinuxParameters == nil {
			container.LinuxParameters = &ECSLinuxParameters{}
		}
		for _, device := range c.Device {
			parts := strings.SplitN(device, ":", 3)
			d := ECSDevice{
				HostPath: parts[0],
			}
			if len(parts) >= 2 {
				d.ContainerPath = parts[1]
			}
			if len(parts) >= 3 {
				d.Permissions = strings.Split(parts[2], "")
			}
			container.LinuxParameters.Devices = append(container.LinuxParameters.Devices, d)
		}
	}

	// unsupported: device-cgroup-rule
	if len(c.DeviceCgroupRule) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --device-cgroup-rule property in ecs task definition as the property is not supported"))
	}

	// unsupported: device-read-bps
	if len(c.DeviceReadBps) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --device-read-bps property in ecs task definition as the property is not supported"))
	}

	// unsupported: device-read-iops
	if len(c.DeviceReadIops) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --device-read-iops property in ecs task definition as the property is not supported"))
	}

	// unsupported: device-write-bps
	if len(c.DeviceWriteBps) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --device-write-bps property in ecs task definition as the property is not supported"))
	}

	// unsupported: device-write-iops
	if len(c.DeviceWriteIops) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --device-write-iops property in ecs task definition as the property is not supported"))
	}

	// unsupported: disable-content-trust
	if !c.DisableContentTrust {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --disable-content-trust property in ecs task definition as the property is not supported"))
	}

	// dns
	if len(c.Dns) > 0 {
		container.DnsServers = c.Dns
	}

	// unsupported: dns-option
	if len(c.DnsOption) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --dns-option property in ecs task definition as the property is not supported"))
	}

	// dns-search
	if len(c.DnsSearch) > 0 {
		container.DnsSearchDomains = c.DnsSearch
	}

	// unsupported: domainname
	if len(c.Domainname) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --domainname property in ecs task definition as the property is not supported"))
	}

	// entrypoint
	if len(c.Entrypoint) > 0 {
		args, err := shellwords.Parse(c.Entrypoint)
		if err != nil {
			errs = multierror.Append(errs, fmt.Errorf("unable to parse --entrypoint flag to slice: %w", err))
		} else {
			container.EntryPoint = args
		}
	}

	// env
	if len(c.Env) > 0 {
		for _, env := range c.Env {
			parts := strings.SplitN(env, "=", 2)
			kv := ECSKeyValuePair{Name: parts[0]}
			if len(parts) == 2 {
				kv.Value = parts[1]
			}
			container.Environment = append(container.Environment, kv)
		}
	}

	// unsupported: env-file (ECS uses S3-based env files, different concept)
	if len(c.EnvFile) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --env-file property in ecs task definition as the property is not supported (ECS uses S3-based environment files)"))
	}

	// unsupported: expose
	if len(c.Expose) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --expose property in ecs task definition as the property is not supported"))
	}

	// gpus
	if len(c.Gpus) > 0 {
		req := ECSResourceRequirement{Type: "GPU"}
		if c.Gpus == "all" {
			req.Value = "1"
		} else {
			req.Value = c.Gpus
		}
		container.ResourceRequirements = append(container.ResourceRequirements, req)
	}

	// unsupported: group-add
	if len(c.GroupAdd) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --group-add property in ecs task definition as the property is not supported"))
	}

	// health check
	if len(c.HealthCmd) > 0 {
		if c.NoHealthcheck {
			warnings = multierror.Append(warnings, fmt.Errorf("ignoring --health-cmd as --no-healthcheck is specified"))
		} else {
			container.HealthCheck = &ECSHealthCheck{
				Command: []string{"CMD-SHELL", c.HealthCmd},
			}
		}
	}

	if c.HealthInterval != "0s" {
		if c.NoHealthcheck {
			warnings = multierror.Append(warnings, fmt.Errorf("ignoring --health-interval as --no-healthcheck is specified"))
		} else {
			seconds, err := durationToSeconds(c.HealthInterval)
			if err != nil {
				errs = multierror.Append(errs, fmt.Errorf("unable to parse --health-interval flag to duration: %w", err))
			} else {
				if container.HealthCheck == nil {
					container.HealthCheck = &ECSHealthCheck{}
				}
				container.HealthCheck.Interval = seconds
			}
		}
	}

	if c.HealthRetries != 0 {
		if c.NoHealthcheck {
			warnings = multierror.Append(warnings, fmt.Errorf("ignoring --health-retries as --no-healthcheck is specified"))
		} else {
			if container.HealthCheck == nil {
				container.HealthCheck = &ECSHealthCheck{}
			}
			container.HealthCheck.Retries = int(c.HealthRetries)
		}
	}

	if c.HealthStartPeriod != "0s" {
		if c.NoHealthcheck {
			warnings = multierror.Append(warnings, fmt.Errorf("ignoring --health-start-period as --no-healthcheck is specified"))
		} else {
			seconds, err := durationToSeconds(c.HealthStartPeriod)
			if err != nil {
				errs = multierror.Append(errs, fmt.Errorf("unable to parse --health-start-period flag to duration: %w", err))
			} else {
				if container.HealthCheck == nil {
					container.HealthCheck = &ECSHealthCheck{}
				}
				container.HealthCheck.StartPeriod = seconds
			}
		}
	}

	if c.HealthTimeout != "0s" {
		if c.NoHealthcheck {
			warnings = multierror.Append(warnings, fmt.Errorf("ignoring --health-timeout as --no-healthcheck is specified"))
		} else {
			seconds, err := durationToSeconds(c.HealthTimeout)
			if err != nil {
				errs = multierror.Append(errs, fmt.Errorf("unable to parse --health-timeout flag to duration: %w", err))
			} else {
				if container.HealthCheck == nil {
					container.HealthCheck = &ECSHealthCheck{}
				}
				container.HealthCheck.Timeout = seconds
			}
		}
	}

	// hostname
	container.Hostname = c.Hostname

	// init
	if c.Init {
		if container.LinuxParameters == nil {
			container.LinuxParameters = &ECSLinuxParameters{}
		}
		container.LinuxParameters.InitProcessEnabled = true
	}

	// interactive
	if c.Interactive {
		container.Interactive = true
	}

	// unsupported: ip
	if len(c.Ip) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --ip property in ecs task definition as the property is not supported"))
	}

	// unsupported: ip6
	if len(c.Ip6) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --ip6 property in ecs task definition as the property is not supported"))
	}

	// ipc -> task-level
	if len(c.Ipc) > 0 {
		taskDef.IpcMode = c.Ipc
	}

	// unsupported: isolation
	if len(c.Isolation) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --isolation property in ecs task definition as the property is not supported"))
	}

	// unsupported: kernel-memory
	if c.KernelMemory != 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --kernel-memory property in ecs task definition as the property is not supported"))
	}

	// labels
	if len(c.Label) > 0 {
		container.DockerLabels = map[string]string{}
		for _, label := range c.Label {
			parts := strings.SplitN(label, "=", 2)
			if len(parts) == 2 {
				container.DockerLabels[parts[0]] = parts[1]
			} else {
				container.DockerLabels[parts[0]] = ""
			}
		}
	}

	// unsupported: label-file
	if len(c.LabelFile) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --label-file property in ecs task definition as the property is not supported"))
	}

	// link
	if len(c.Link) > 0 {
		container.Links = c.Link
	}

	// unsupported: link-local-ip
	if len(c.LinkLocalIP) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --link-local-ip property in ecs task definition as the property is not supported"))
	}

	// log-driver / log-opt
	if len(c.LogDriver) > 0 {
		container.LogConfiguration = &ECSLogConfiguration{
			LogDriver: c.LogDriver,
		}
	}

	if len(c.LogOpt) > 0 {
		if container.LogConfiguration == nil {
			container.LogConfiguration = &ECSLogConfiguration{}
		}
		container.LogConfiguration.Options = map[string]string{}
		for _, opt := range c.LogOpt {
			parts := strings.SplitN(opt, "=", 2)
			if len(parts) == 2 {
				container.LogConfiguration.Options[parts[0]] = parts[1]
			} else {
				container.LogConfiguration.Options[parts[0]] = ""
			}
		}
	}

	// unsupported: mac-address
	if len(c.Mac) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --mac-address property in ecs task definition as the property is not supported"))
	}

	// memory -> container-level and task-level (in MiB)
	if c.Memory > 0 {
		mib := bytesToMiB(c.Memory)
		container.Memory = mib
		taskDef.Memory = strconv.Itoa(mib)
	}

	// memory-reservation -> container-level (in MiB)
	if c.MemoryReservation > 0 {
		container.MemoryReservation = bytesToMiB(c.MemoryReservation)
	}

	// memory-swap -> linuxParameters.maxSwap (in MiB)
	if c.MemorySwap > 0 {
		if container.LinuxParameters == nil {
			container.LinuxParameters = &ECSLinuxParameters{}
		}
		container.LinuxParameters.MaxSwap = bytesToMiB(c.MemorySwap)
	}

	// memory-swappiness -> linuxParameters.swappiness
	if c.MemorySwappiness > 0 {
		if container.LinuxParameters == nil {
			container.LinuxParameters = &ECSLinuxParameters{}
		}
		container.LinuxParameters.Swappiness = int(c.MemorySwappiness)
	}

	// mount
	if len(c.Mount) > 0 {
		for i, value := range c.Mount {
			data := map[string]string{}
			for _, part := range strings.Split(value, ",") {
				k, v := extractParts(part, "=")
				data[k] = v
			}

			mountType := data["type"]
			var source, target string
			for _, key := range []string{"src", "source"} {
				if v, ok := data[key]; ok {
					source = v
				}
			}
			for _, key := range []string{"dst", "destination", "target"} {
				if v, ok := data[key]; ok {
					target = v
				}
			}

			readOnly := false
			for _, key := range []string{"readonly", "ro"} {
				if v, ok := data[key]; ok {
					roMap := map[string]bool{
						"false": false,
						"true":  true,
						"0":     false,
						"1":     true,
					}
					readOnly = roMap[v]
				}
			}

			if mountType == "bind" || mountType == "volume" {
				volumeName := fmt.Sprintf("mount-%d", i)
				vol := ECSVolume{Name: volumeName}
				if mountType == "bind" && len(source) > 0 {
					vol.Host = &ECSHostVolumeProperties{SourcePath: source}
				}
				taskVolumes = append(taskVolumes, vol)

				container.MountPoints = append(container.MountPoints, ECSMountPoint{
					SourceVolume:  volumeName,
					ContainerPath: target,
					ReadOnly:      readOnly,
				})
			} else if mountType == "tmpfs" {
				if container.LinuxParameters == nil {
					container.LinuxParameters = &ECSLinuxParameters{}
				}

				tmpfs := ECSTmpfs{
					ContainerPath: target,
				}

				if sizeStr, ok := data["tmpfs-size"]; ok {
					sizeBytes, err := toSize(sizeStr)
					if err != nil {
						errs = multierror.Append(errs, fmt.Errorf("unable to parse --mount flag due to invalid tmpfs-size value: %w", err))
					} else {
						tmpfs.Size = int(sizeBytes / (1024 * 1024))
					}
				}

				container.LinuxParameters.Tmpfs = append(container.LinuxParameters.Tmpfs, tmpfs)
			}
		}
	}

	// network -> task-level networkMode
	if len(c.Network) > 0 {
		switch c.Network {
		case "host", "none", "bridge":
			taskDef.NetworkMode = c.Network
		default:
			taskDef.NetworkMode = "awsvpc"
			warnings = multierror.Append(warnings, fmt.Errorf("mapping --network %q to networkMode \"awsvpc\" in ecs task definition", c.Network))
		}
	}

	// unsupported: network-alias
	if len(c.NetworkAlias) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --network-alias property in ecs task definition as the property is not supported"))
	}

	// no-healthcheck: warn if set alongside health flags (already handled above)
	if c.NoHealthcheck {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --no-healthcheck property in ecs task definition as the property is not supported"))
	}

	// unsupported: oom-kill-disable
	if c.OomKillDisable {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --oom-kill-disable property in ecs task definition as the property is not supported"))
	}

	// unsupported: oom-score-adj
	if c.OomScore != 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --oom-score-adj property in ecs task definition as the property is not supported"))
	}

	// pid -> task-level
	if len(c.Pid) > 0 {
		taskDef.PidMode = c.Pid
	}

	// unsupported: pids-limit
	if c.PidsLimit != 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --pids-limit property in ecs task definition as the property is not supported"))
	}

	// platform -> task-level runtimePlatform
	if len(c.Platform) > 0 {
		taskDef.RuntimePlatform = parsePlatform(c.Platform)
	}

	// privileged
	if c.Privileged {
		container.Privileged = true
	}

	// publish -> portMappings
	if len(c.Publish) > 0 {
		for _, value := range c.Publish {
			parsed, err := types.ParsePortConfig(value)
			if err != nil {
				errs = multierror.Append(errs, fmt.Errorf("unable to parse --publish flag: %w", err))
			} else {
				for _, p := range parsed {
					pm := ECSPortMapping{
						ContainerPort: int(p.Target),
						Protocol:      p.Protocol,
					}
					if len(p.Published) > 0 {
						hostPort, pErr := strconv.Atoi(p.Published)
						if pErr != nil {
							errs = multierror.Append(errs, fmt.Errorf("unable to parse --publish host port: %w", pErr))
						} else {
							pm.HostPort = hostPort
						}
					}
					container.PortMappings = append(container.PortMappings, pm)
				}
			}
		}
	}

	// unsupported: publish-all
	if c.PublishAll {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --publish-all property in ecs task definition as the property is not supported"))
	}

	// unsupported: pull
	if c.Pull != "missing" {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --pull property in ecs task definition as the property is not supported"))
	}

	// read-only
	if c.ReadOnly {
		container.ReadonlyRootFilesystem = true
	}

	// unsupported: restart
	if c.Restart != "no" && len(c.Restart) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --restart property in ecs task definition as the property is not supported (use ECS service restart policy instead)"))
	}

	// unsupported: rm
	if c.Rm {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --rm property in ecs task definition as the property is not supported"))
	}

	// unsupported: runtime
	if len(c.Runtime) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --runtime property in ecs task definition as the property is not supported"))
	}

	// security-opt
	if len(c.SecurityOpt) > 0 {
		container.DockerSecurityOptions = c.SecurityOpt
	}

	// shm-size -> linuxParameters.sharedMemorySize (in MiB)
	if c.ShmSize != 0 {
		if container.LinuxParameters == nil {
			container.LinuxParameters = &ECSLinuxParameters{}
		}
		container.LinuxParameters.SharedMemorySize = bytesToMiB(int64(c.ShmSize))
	}

	// unsupported: sig-proxy
	if !c.SigProxy {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --sig-proxy property in ecs task definition as the property is not supported"))
	}

	// unsupported: stop-signal
	if len(c.StopSignal) > 0 && c.StopSignal != "SIGTERM" {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --stop-signal property in ecs task definition as the property is not supported"))
	}

	// stop-timeout
	if c.StopTimeout > 0 {
		container.StopTimeout = c.StopTimeout
	}

	// unsupported: storage-opt
	if len(c.StorageOpt) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --storage-opt property in ecs task definition as the property is not supported"))
	}

	// sysctl -> systemControls
	if len(c.Sysctl) > 0 {
		for ns, val := range c.Sysctl {
			container.SystemControls = append(container.SystemControls, ECSSystemControl{
				Namespace: ns,
				Value:     val,
			})
		}
	}

	// tmpfs
	if len(c.Tmpfs) > 0 {
		if container.LinuxParameters == nil {
			container.LinuxParameters = &ECSLinuxParameters{}
		}
		for _, value := range c.Tmpfs {
			parts := strings.SplitN(value, ":", 2)
			tmpfs := ECSTmpfs{
				ContainerPath: parts[0],
			}
			if len(parts) == 2 {
				opts := strings.Split(parts[1], ",")
				var mountOpts []string
				for _, opt := range opts {
					k, v := extractParts(opt, "=")
					if k == "size" {
						sizeBytes, err := toSize(v)
						if err != nil {
							errs = multierror.Append(errs, fmt.Errorf("unable to parse --tmpfs flag size: %w", err))
						} else {
							tmpfs.Size = int(sizeBytes / (1024 * 1024))
						}
					} else {
						mountOpts = append(mountOpts, opt)
					}
				}
				if len(mountOpts) > 0 {
					tmpfs.MountOptions = mountOpts
				}
			}
			container.LinuxParameters.Tmpfs = append(container.LinuxParameters.Tmpfs, tmpfs)
		}
	}

	// tty
	if c.Tty {
		container.PseudoTerminal = true
	}

	// ulimits
	if len(c.Ulimit) > 0 {
		for _, value := range c.Ulimit {
			name, limits := extractParts(value, "=")
			soft, hard := extractParts(limits, ":")
			if hard == "" {
				hard = soft
			}

			softInt, err := toInt(soft)
			if err != nil {
				errs = multierror.Append(errs, fmt.Errorf("unable to parse --ulimit flag value: %w", err))
				continue
			}
			hardInt, err := toInt(hard)
			if err != nil {
				errs = multierror.Append(errs, fmt.Errorf("unable to parse --ulimit flag value: %w", err))
				continue
			}

			container.Ulimits = append(container.Ulimits, ECSUlimit{
				Name:      name,
				SoftLimit: softInt,
				HardLimit: hardInt,
			})
		}
	}

	// user
	if len(c.User) > 0 {
		container.User = c.User
	}

	// unsupported: userns
	if len(c.Userns) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --userns property in ecs task definition as the property is not supported"))
	}

	// unsupported: uts
	if len(c.Uts) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --uts property in ecs task definition as the property is not supported"))
	}

	// volume
	if len(c.Volume) > 0 {
		for i, value := range c.Volume {
			parts := strings.SplitN(value, ":", 3)
			volumeName := fmt.Sprintf("volume-%d", i)
			readOnly := false

			if len(parts) == 1 {
				// anonymous volume: just a container path
				taskVolumes = append(taskVolumes, ECSVolume{Name: volumeName})
				container.MountPoints = append(container.MountPoints, ECSMountPoint{
					SourceVolume:  volumeName,
					ContainerPath: parts[0],
				})
			} else if len(parts) >= 2 {
				if len(parts) == 3 {
					if parts[2] == "ro" {
						readOnly = true
					} else if parts[2] != "rw" {
						errs = multierror.Append(errs, fmt.Errorf("unable to parse --volume flag as volume: invalid read mode %s", parts[2]))
						continue
					}
				}

				vol := ECSVolume{Name: volumeName}
				// if source looks like an absolute path, it's a bind mount
				if strings.HasPrefix(parts[0], "/") {
					vol.Host = &ECSHostVolumeProperties{SourcePath: parts[0]}
				}
				taskVolumes = append(taskVolumes, vol)

				container.MountPoints = append(container.MountPoints, ECSMountPoint{
					SourceVolume:  volumeName,
					ContainerPath: parts[1],
					ReadOnly:      readOnly,
				})
			}
		}
	}

	// unsupported: volume-driver
	if len(c.VolumeDriver) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --volume-driver property in ecs task definition as the property is not supported"))
	}

	// volumes-from
	if len(c.VolumesFrom) > 0 {
		for _, value := range c.VolumesFrom {
			parts := strings.SplitN(value, ":", 2)
			vf := ECSVolumeFrom{
				SourceContainer: parts[0],
			}
			if len(parts) == 2 && parts[1] == "ro" {
				vf.ReadOnly = true
			}
			container.VolumesFrom = append(container.VolumesFrom, vf)
		}
	}

	// workdir
	if len(c.Workdir) > 0 {
		container.WorkingDirectory = c.Workdir
	}

	// positional arguments: command and image
	if len(arguments["command"].ListValue()) > 0 {
		container.Command = arguments["command"].ListValue()
	}
	container.Image = arguments["image"].StringValue()

	// ECS-specific options
	taskDef.TaskRoleArn = ecsOpts.TaskRoleArn
	taskDef.ExecutionRoleArn = ecsOpts.ExecutionRoleArn
	if len(ecsOpts.RequiresCompatibilities) > 0 {
		taskDef.RequiresCompatibilities = ecsOpts.RequiresCompatibilities
	}

	// assemble
	taskDef.ContainerDefinitions = []ECSContainerDefinition{*container}
	if len(taskVolumes) > 0 {
		taskDef.Volumes = taskVolumes
	}

	return taskDef, warnings, errs
}

// MarshalECS marshals an ECS task definition to JSON
func MarshalECS(taskDef *ECSTaskDefinition) ([]byte, error) {
	return json.MarshalIndent(taskDef, "", "  ")
}

// MarshalECSCloudFormation marshals an ECS task definition as a CloudFormation YAML template
func MarshalECSCloudFormation(taskDef *ECSTaskDefinition) ([]byte, error) {
	template := CloudFormationTemplate{
		AWSTemplateFormatVersion: "2010-09-09",
		Resources: map[string]CloudFormationResource{
			"TaskDefinition": {
				Type:       "AWS::ECS::TaskDefinition",
				Properties: taskDef,
			},
		},
	}
	return yaml.Marshal(template)
}

// durationToSeconds parses a Go duration string and returns the value in seconds
func durationToSeconds(value string) (int, error) {
	d, err := time.ParseDuration(value)
	if err != nil {
		return 0, err
	}
	return int(d.Seconds()), nil
}

// bytesToMiB converts bytes to mebibytes
func bytesToMiB(bytes int64) int {
	return int(bytes / (1024 * 1024))
}

// parsePlatform parses a platform string (e.g., "linux/amd64") into an ECS runtime platform
func parsePlatform(platform string) *ECSRuntimePlatform {
	rp := &ECSRuntimePlatform{}
	parts := strings.SplitN(platform, "/", 2)
	if len(parts) >= 1 {
		switch strings.ToLower(parts[0]) {
		case "linux":
			rp.OperatingSystemFamily = "LINUX"
		case "windows":
			rp.OperatingSystemFamily = "WINDOWS_SERVER_2019_FULL"
		default:
			rp.OperatingSystemFamily = strings.ToUpper(parts[0])
		}
	}
	if len(parts) >= 2 {
		switch strings.ToLower(parts[1]) {
		case "amd64", "x86_64":
			rp.CpuArchitecture = "X86_64"
		case "arm64", "aarch64":
			rp.CpuArchitecture = "ARM64"
		default:
			rp.CpuArchitecture = strings.ToUpper(parts[1])
		}
	}
	return rp
}
