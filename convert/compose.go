package convert

import (
	"docker-run-export/arguments"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/compose-spec/compose-go/types"
	"github.com/hashicorp/go-multierror"
	"github.com/josegonzalez/cli-skeleton/command"
	"github.com/mattn/go-shellwords"
	"github.com/pkg/errors"
	"gopkg.in/yaml.v2"
)

func ToCompose(projectName string, c *arguments.Args, arguments map[string]command.Argument) (*types.Project, *multierror.Error, *multierror.Error) {
	var warnings *multierror.Error
	var errs *multierror.Error
	project := &types.Project{
		Name: projectName,
	}

	service := &types.ServiceConfig{
		Name: "app",
	}

	service.ExtraHosts = map[string]string{}
	for _, hostMap := range c.AddHost {
		parts := strings.SplitN(hostMap, ":", 2)
		service.ExtraHosts[parts[0]] = parts[1]
	}

	if len(c.Attach) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --attach property in compose spec as the property is not valid in compose v3"))
	}

	if c.BlkioWeight != 0 {
		if service.BlkioConfig == nil {
			service.BlkioConfig = &types.BlkioConfig{}
		}

		service.BlkioConfig.Weight = uint16(c.BlkioWeight)
	}

	if len(c.BlkioWeightDevice) > 0 {
		if service.BlkioConfig == nil {
			service.BlkioConfig = &types.BlkioConfig{}
		}

		service.BlkioConfig.WeightDevice = []types.WeightDevice{}
		for _, weightDevice := range c.BlkioWeightDevice {
			parts := strings.SplitN(weightDevice, ":", 2)
			number, _ := strconv.ParseUint(parts[1], 10, 64)

			service.BlkioConfig.WeightDevice = append(service.BlkioConfig.WeightDevice, types.WeightDevice{
				Path:   parts[0],
				Weight: uint16(number),
			})
		}
	}

	if len(c.DeviceReadBps) > 0 {
		if service.BlkioConfig == nil {
			service.BlkioConfig = &types.BlkioConfig{}
		}

		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --device-read-bps property in compose spec as the rate must be validated and parsed"))
		service.BlkioConfig.DeviceReadBps = []types.ThrottleDevice{}
		// todo: parse parts[1] into a rate (bytes uint64) from string kb|mb|gb and set it
		// todo: validate that each input has a format
		// for _, deviceReadBp := range c.DeviceReadBps {
		// 	parts := strings.SplitN(deviceReadBp, ":", 2)
		// 	service.BlkioConfig.DeviceReadBps = append(service.BlkioConfig.DeviceReadBps, types.ThrottleDevice{
		// 		Path: parts[0],
		// 		Rate: parts[1],
		// 	})
		// }
	}

	if len(c.DeviceWriteBps) > 0 {
		if service.BlkioConfig == nil {
			service.BlkioConfig = &types.BlkioConfig{}
		}

		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --device-write-bps property in compose spec as the rate must be validated and parsed"))

		service.BlkioConfig.DeviceWriteBps = []types.ThrottleDevice{}
		// todo: parse parts[1] into a rate (bytes uint64) from string kb|mb|gb and set it
		// todo: validate that each input has a format
		// for _, deviceWriteBp := range c.DeviceWriteBps {
		// 	parts := strings.SplitN(deviceWriteBp, ":", 2)
		// 	service.BlkioConfig.DeviceWriteBps = append(service.BlkioConfig.DeviceWriteBps, types.ThrottleDevice{
		// 		Path: parts[0],
		// 		Rate: parts[1],
		// 	})
		// }
	}

	if len(c.DeviceReadIops) > 0 {
		if service.BlkioConfig == nil {
			service.BlkioConfig = &types.BlkioConfig{}
		}

		service.BlkioConfig.DeviceReadIOps = []types.ThrottleDevice{}
		for _, deviceReadIop := range c.DeviceReadIops {
			parts := strings.SplitN(deviceReadIop, ":", 2)
			number, _ := strconv.ParseUint(parts[1], 10, 64)

			service.BlkioConfig.DeviceReadIOps = append(service.BlkioConfig.DeviceReadIOps, types.ThrottleDevice{
				Path: parts[0],
				Rate: number,
			})
		}
	}

	if len(c.DeviceWriteIops) > 0 {
		if service.BlkioConfig == nil {
			service.BlkioConfig = &types.BlkioConfig{}
		}

		service.BlkioConfig.DeviceWriteIOps = []types.ThrottleDevice{}
		for _, deviceWriteIop := range c.DeviceWriteIops {
			parts := strings.SplitN(deviceWriteIop, ":", 2)
			number, _ := strconv.ParseUint(parts[1], 10, 64)

			service.BlkioConfig.DeviceWriteIOps = append(service.BlkioConfig.DeviceWriteIOps, types.ThrottleDevice{
				Path: parts[0],
				Rate: number,
			})
		}
	}

	service.CapAdd = c.CapAdd
	service.CapDrop = c.CapDrop

	if len(c.Cgroupns) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --cgroupns property in compose spec as the property is not valid in compose v3"))
	}

	service.CgroupParent = c.CgroupParent

	if len(c.Cidfile) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --cidfile property in compose spec as the property is not valid in compose v3"))
	}

	if c.CpuPeriod > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --cpu-period property in compose spec as the property is not valid in compose v3"))
	}

	if c.CpuQuota > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --cpu-quota property in compose spec as the property is not valid in compose v3"))
	}

	if c.CpuRtPeriod > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --cpu-rt-period property in compose spec as the property is not valid in compose v3"))
	}

	if c.CpuRtRuntime > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --cpu-rt-runtime property in compose spec as the property is not valid in compose v3"))
	}

	if c.Cpus > 0 || c.Memory > 0 {
		if service.Deploy == nil {
			service.Deploy = &types.DeployConfig{}
		}

		service.Deploy.Resources = types.Resources{
			Limits: &types.Resource{},
		}

		if c.Cpus > 0 {
			service.Deploy.Resources.Limits.NanoCPUs = fmt.Sprintf("%f", c.Cpus)
		}

		if c.Memory > 0 {
			service.Deploy.Resources.Limits.MemoryBytes = types.UnitBytes(c.Memory)
		}
	}

	if len(c.CpusetCpus) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --cpuset-cpus property in compose spec as the property is not valid in compose v3"))
	}

	if len(c.CpusetMems) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --cpuset-mems property in compose spec as the property is not valid in compose v3"))
	}

	if c.Detach {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --detach property in compose spec as the property is not valid in compose v3"))
	}

	if len(c.DetachKeys) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --detach-keys property in compose spec as the property is not valid in compose v3"))
	}

	if len(c.Device) > 0 {
		service.Devices = c.Device
	}

	if len(c.DeviceCgroupRule) > 0 {
		service.DeviceCgroupRules = c.DeviceCgroupRule
	}

	if !c.DisableContentTrust {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --disable-trust-content property in compose spec as the property is not valid in compose v3"))
	}

	service.DNS = c.Dns
	service.DNSOpts = c.DnsOption
	service.DNSSearch = c.DnsSearch
	service.DomainName = c.Domainname

	if len(c.Entrypoint) > 0 {
		args, err := shellwords.Parse(c.Entrypoint)
		if err != nil {
			errs = multierror.Append(errs, fmt.Errorf("unable to parse --entrypoint flag to slice: %w", err))
		} else {
			service.Entrypoint = args
		}
	}

	service.Environment = types.NewMappingWithEquals(c.Env)
	service.EnvFile = c.EnvFile
	service.Expose = c.Expose

	if len(c.Gpus) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --gpus property in compose spec as the property is not valid in compose v3"))
	}

	service.GroupAdd = c.GroupAdd
	if len(c.HealthCmd) > 0 {
		if c.NoHealthcheck {
			warnings = multierror.Append(warnings, fmt.Errorf("ignoring --health-cmd  as --no-healthcheck is specified"))
		} else {
			args, err := shellwords.Parse(c.HealthCmd)
			if err != nil {
				errs = multierror.Append(errs, fmt.Errorf("unable to parse --health-cmd flag to slice: %w", err))
			} else {
				if service.HealthCheck == nil {
					service.HealthCheck = &types.HealthCheckConfig{}
				}

				service.HealthCheck.Test = args
			}
		}
	}

	if c.HealthInterval != "0s" {
		if c.NoHealthcheck {
			warnings = multierror.Append(warnings, fmt.Errorf("ignoring --health-interval  as --no-healthcheck is specified"))
		} else {
			if service.HealthCheck == nil {
				service.HealthCheck = &types.HealthCheckConfig{}
			}

			val, err := transformStringToDuration(c.HealthInterval)
			if err != nil {
				errs = multierror.Append(errs, fmt.Errorf("unable to parse --health-timeout flag to duration: %w", err))
			} else {
				service.HealthCheck.Interval = DurationToPtr(val.(types.Duration))
			}
		}
	}

	if c.HealthRetries != 0 {
		if c.NoHealthcheck {
			warnings = multierror.Append(warnings, fmt.Errorf("ignoring --health-retries  as --no-healthcheck is specified"))
		} else {
			if service.HealthCheck == nil {
				service.HealthCheck = &types.HealthCheckConfig{}
			}

			service.HealthCheck.Retries = Uint64ToPtr(c.HealthRetries)
		}
	}

	if c.HealthStartPeriod != "0s" {
		if c.NoHealthcheck {
			warnings = multierror.Append(warnings, fmt.Errorf("ignoring --health-start-period  as --no-healthcheck is specified"))
		} else {
			if service.HealthCheck == nil {
				service.HealthCheck = &types.HealthCheckConfig{}
			}

			val, err := transformStringToDuration(c.HealthStartPeriod)
			if err != nil {
				errs = multierror.Append(errs, fmt.Errorf("unable to parse --health-timeout flag to duration: %w", err))
			} else {
				service.HealthCheck.StartPeriod = DurationToPtr(val.(types.Duration))
			}
		}
	}

	if c.HealthTimeout != "0s" {
		if c.NoHealthcheck {
			warnings = multierror.Append(warnings, fmt.Errorf("ignoring --health-timeout  as --no-healthcheck is specified"))
		} else {
			if service.HealthCheck == nil {
				service.HealthCheck = &types.HealthCheckConfig{}
			}

			val, err := transformStringToDuration(c.HealthTimeout)
			if err != nil {
				errs = multierror.Append(errs, fmt.Errorf("unable to parse --health-timeout flag to duration: %w", err))
			} else {
				service.HealthCheck.Timeout = DurationToPtr(val.(types.Duration))
			}
		}
	}

	service.Hostname = c.Hostname
	if c.Init {
		service.Init = &c.Init
	}

	if c.Interactive {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --interactive property in compose spec as the property is not valid in compose v3"))
	}

	if len(c.Ip) > 0 {
		if len(service.Networks) == 0 {
			service.Networks = map[string]*types.ServiceNetworkConfig{
				"default": {},
			}
		}

		service.Networks["default"].Ipv4Address = c.Ip
	}

	if len(c.Ip6) > 0 {
		if len(service.Networks) == 0 {
			service.Networks = map[string]*types.ServiceNetworkConfig{
				"default": {},
			}
		}

		service.Networks["default"].Ipv6Address = c.Ip6
	}

	service.Ipc = c.Ipc
	service.Isolation = c.Isolation

	if c.KernelMemory != 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --kernel-memory property in compose spec as the property is not valid in compose v3"))
	}

	if len(c.Label) > 0 {
		service.Labels = types.Labels{}
		for _, label := range c.Label {
			parts := strings.SplitN(label, "=", 2)
			if len(parts) == 2 {
				service.Labels[parts[0]] = parts[1]
			} else {
				service.Labels[parts[0]] = ""
			}
		}
	}

	if len(c.LabelFile) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --label-file property in compose spec as the property is not valid in compose v3"))
	}

	service.Links = c.Link

	if len(c.LinkLocalIP) > 0 {
		if len(service.Networks) == 0 {
			service.Networks = map[string]*types.ServiceNetworkConfig{
				"default": {},
			}
		}

		service.Networks["default"].LinkLocalIPs = c.LinkLocalIP
	}

	service.LogDriver = c.LogDriver
	if len(c.Label) > 0 {
		service.LogOpt = map[string]string{}
		for _, label := range c.LogOpt {
			parts := strings.SplitN(label, "=", 2)
			if len(parts) == 2 {
				service.LogOpt[parts[0]] = parts[1]
			} else {
				service.LogOpt[parts[0]] = ""
			}
		}
	}

	service.MacAddress = c.Mac
	service.MemReservation = types.UnitBytes(c.MemoryReservation)
	service.MemSwapLimit = types.UnitBytes(c.MemorySwap)
	service.MemSwappiness = types.UnitBytes(c.MemorySwappiness)

	if len(c.Mount) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --mount property in compose spec as the mounts must be validated and parsed"))
	}

	service.ContainerName = c.ContainerName

	if len(c.Network) > 0 {
		project.Networks = map[string]types.NetworkConfig{
			"default": {
				Name:     c.Network,
				External: types.External{External: true},
			},
		}
	}

	if len(c.NetworkAlias) > 0 {
		if len(service.Networks) == 0 {
			service.Networks = map[string]*types.ServiceNetworkConfig{
				"default": {},
			}
		}

		service.Networks["default"].Aliases = c.NetworkAlias
	}

	if c.NoHealthcheck {
		if service.HealthCheck == nil {
			service.HealthCheck = &types.HealthCheckConfig{}
		}

		service.HealthCheck.Disable = true
	}

	if c.OomKillDisable {
		service.OomKillDisable = c.OomKillDisable
	}

	if c.OomScore != 0 {
		service.OomScoreAdj = int64(c.OomScore)
	}

	if len(c.Pid) > 0 {
		service.Pid = c.Pid
	}

	if c.PidsLimit != 0 {
		service.PidsLimit = int64(c.PidsLimit)
	}

	if len(c.Platform) > 0 {
		service.Platform = c.Platform
	}

	if c.Privileged {
		service.Privileged = c.Privileged
	}

	if len(c.Publish) > 0 {
		for _, value := range c.Publish {
			parsed, err := types.ParsePortConfig(value)
			if err != nil {
				errs = multierror.Append(errs, fmt.Errorf("unable to parse --publish flag to slice: %w", err))
			} else {
				service.Ports = append(service.Ports, parsed...)
			}
		}
	}

	if c.PublishAll {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --publish-all property in compose spec as the property is not valid in compose v3"))
	}

	if c.Pull != "missing" {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --pull property in compose spec as images will always be pulled if missing"))
	}

	if c.ReadOnly {
		service.ReadOnly = c.ReadOnly
	}

	if c.Rm {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --rm property in compose spec as the property is not valid in compose v3"))
	}

	if len(c.Runtime) > 0 {
		service.Runtime = c.Runtime
	}

	if len(c.SecurityOpt) > 0 {
		service.SecurityOpt = c.SecurityOpt
	}

	if c.ShmSize != 0 {
		service.ShmSize = types.UnitBytes(c.ShmSize)
	}

	if !c.SigProxy {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --sig-proxy property in compose spec as the property is not valid in compose v3"))
	}

	if len(c.StopSignal) > 0 && c.StopSignal != "SIGTERM" {
		service.StopSignal = c.StopSignal
	}

	if c.StopTimeout > 0 {
		val, err := transformStringToDuration(c.StopTimeout)
		if err != nil {
			errs = multierror.Append(errs, fmt.Errorf("unable to parse --stop-timeout flag to duration: %w", err))
		} else {
			service.StopGracePeriod = DurationToPtr(val.(types.Duration))
		}
	}

	if len(c.StorageOpt) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --storage-opt property in compose spec as the property is not valid in compose v3"))
	}

	if len(c.Sysctl) > 0 {
		service.Sysctls = c.Sysctl
	}

	if len(c.Tmpfs) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --tmpfs property in compose spec as the property must be validated and parsed"))
	}

	if c.Tty {
		service.Tty = c.Tty
	}

	if len(c.Ulimit) > 0 {
		warnings = multierror.Append(warnings, fmt.Errorf("unable to set --ulimit property in compose spec as the property must be validated and parsed"))
	}

	if len(c.User) > 0 {
		service.User = c.User
	}

	if len(c.Userns) > 0 {
		service.UserNSMode = c.Userns
	}

	if len(c.Uts) > 0 {
		service.Uts = c.Uts
	}

	if len(c.Userns) > 0 {
		service.UserNSMode = c.Userns
	}

	if len(c.Userns) > 0 {
		service.UserNSMode = c.Userns
	}

	if len(c.Volume) > 0 {
		// todo: handle c:\\ style windows volumes
		for _, value := range c.Volume {
			parts := strings.SplitN(value, ":", 3)
			volume := types.ServiceVolumeConfig{
				Source: parts[0],
			}
			if len(parts) == 1 {
				volume.Target = parts[0]
			} else if len(parts) == 2 {
				volume.Source = parts[0]
				volume.Target = parts[1]
			} else if len(parts) == 3 {
				volume.Source = parts[0]
				volume.Target = parts[1]
				if parts[2] == "ro" {
					volume.ReadOnly = true
				} else if parts[2] == "rw" {
					volume.ReadOnly = false
				} else {
					errs = multierror.Append(errs, fmt.Errorf("unable to parse --volume flag as volume: invalid read mode %s", parts[2]))
				}
			}
		}
	}

	if len(c.VolumeDriver) > 0 {
		service.VolumeDriver = c.VolumeDriver
	}

	if len(c.VolumesFrom) > 0 {
		service.VolumesFrom = c.VolumesFrom
	}

	if len(c.Workdir) > 0 {
		service.WorkingDir = c.Workdir
	}

	if len(arguments["command"].ListValue()) > 0 {
		service.Command = arguments["command"].ListValue()
	}
	service.Image = arguments["image"].StringValue()

	project.Services = append(project.Services, *service)

	return project, warnings, errs
}

func MarshalCompose(project *types.Project, format string) ([]byte, error) {
	switch format {
	case "json":
		return json.MarshalIndent(project, "", "  ")
	case "yaml":
		return yaml.Marshal(project)
	default:
		return nil, fmt.Errorf("unsupported format %q", format)
	}
}

// Uint64ToPtr returns the pointer to an int
func Uint64ToPtr(i uint64) *uint64 {
	return &i
}

// DurationToPtr returns the pointer to an types.Duration
func DurationToPtr(i types.Duration) *types.Duration {
	return &i
}

func transformStringToDuration(value interface{}) (interface{}, error) {
	switch value := value.(type) {
	case string:
		d, err := time.ParseDuration(value)
		if err != nil {
			return value, err
		}
		return types.Duration(d), nil
	case types.Duration:
		return value, nil
	default:
		return value, errors.Errorf("invalid type %T for duration", value)
	}
}
