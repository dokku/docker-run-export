package commands

import (
	"docker-run-export/arguments"
	"docker-run-export/convert"
	"fmt"
	"os"

	"github.com/josegonzalez/cli-skeleton/command"
	"github.com/posener/complete"
	flag "github.com/spf13/pflag"
)

type ExportCommand struct {
	command.Meta
	GlobalFlagCommand
	arguments.Args
}

func (c *ExportCommand) Name() string {
	return "export"
}

func (c *ExportCommand) Synopsis() string {
	return "Command that exports a docker run command to a specified format"
}

func (c *ExportCommand) Help() string {
	return command.CommandHelp(c)
}

func (c *ExportCommand) Examples() map[string]string {
	appName := os.Getenv("CLI_APP_NAME")
	return map[string]string{
		"Exports to docker-compose": fmt.Sprintf("%s %s --format compose alpine:latest", appName, c.Name()),
	}
}

func (c *ExportCommand) Arguments() []command.Argument {
	args := []command.Argument{}
	args = append(args, command.Argument{
		Name:        "image",
		Description: "a docker image",
		Optional:    false,
		Type:        command.ArgumentString,
	})
	args = append(args, command.Argument{
		Name:        "command",
		Description: "command and arguments to run",
		Optional:    true,
		Type:        command.ArgumentList,
	})
	return args
}

func (c *ExportCommand) AutocompleteArgs() complete.Predictor {
	return complete.PredictNothing
}

func (c *ExportCommand) ParsedArguments(args []string) (map[string]command.Argument, error) {
	return command.ParseArguments(args, c.Arguments())
}

func (c *ExportCommand) FlagSet() *flag.FlagSet {
	f := c.Meta.FlagSet(c.Name(), command.FlagSetClient)

	f.BoolVar(&c.DisableContentTrust, "disable-content-trust", true, "Skip image verification")
	f.BoolVar(&c.Init, "init", false, "Run an init inside the container that forwards signals and reaps processes")
	f.BoolVar(&c.NoHealthcheck, "no-healthcheck", false, "Disable any container-specified HEALTHCHECK")
	f.BoolVar(&c.OomKillDisable, "oom-kill-disable", false, "Disable OOM Killer")
	f.BoolVar(&c.Privileged, "privileged", false, "Give extended privileges to this container")
	f.BoolVar(&c.ReadOnly, "read-only", false, "Mount the container's root filesystem as read only")
	f.BoolVar(&c.Rm, "rm", false, "Automatically remove the container when it exits")
	f.BoolVar(&c.SigProxy, "sig-proxy", true, "Proxy received signals to the process")
	f.BoolVarP(&c.Detach, "detach", "d", false, "Run container in background and print container ID")
	f.BoolVarP(&c.Interactive, "interactive", "i", false, "Keep STDIN open even if not attached")
	f.BoolVarP(&c.PublishAll, "publish-all", "P", false, "Publish all exposed ports to random ports")
	f.BoolVarP(&c.Tty, "tty", "t", false, "Allocate a pseudo-TTY")
	f.Float32Var(&c.Cpus, "cpus", 0, "Number of CPUs")
	f.IntVar(&c.BlkioWeight, "blkio-weight", 0, "Block IO (relative weight), between 10 and 1000, or 0 to disable (default 0)")
	f.IntVar(&c.CpuPeriod, "cpu-period", 0, "Limit CPU CFS (Completely Fair Scheduler) period")
	f.IntVar(&c.CpuQuota, "cpu-quota", 0, "Limit CPU CFS (Completely Fair Scheduler) quota")
	f.IntVar(&c.CpuRtPeriod, "cpu-rt-period", 0, "Limit CPU real-time period in microseconds")
	f.IntVar(&c.CpuRtRuntime, "cpu-rt-runtime", 0, "Limit CPU real-time runtime in microseconds")
	f.Uint64Var(&c.HealthRetries, "health-retries", 0, "Consecutive failures needed to report unhealthy")
	f.IntVar(&c.KernelMemory, "kernel-memory", 0, "Kernel memory limit")
	f.Int64Var(&c.MemoryReservation, "memory-reservation", 0, "Memory soft limit")
	f.Int64Var(&c.MemorySwap, "memory-swap", 0, "Swap limit equal to memory plus swap: '-1' to enable unlimited swap")
	f.Int64Var(&c.MemorySwappiness, "memory-swappiness", 0, "Tune container memory swappiness (0 to 100) (default -1)")
	f.IntVar(&c.OomScore, "oom-score-adj", 0, "Tune host's OOM preferences (-1000 to 1000)")
	f.IntVar(&c.PidsLimit, "pids-limit", 0, "Tune container pids limit (set -1 for unlimited)")
	f.IntVar(&c.ShmSize, "shm-size", 0, "Size of /dev/shm")
	f.IntVar(&c.StopTimeout, "stop-timeout", 0, "Timeout (in seconds) to stop a container")
	f.IntVarP(&c.CpuShares, "cpu-shares", "c", 0, "CPU shares (relative weight)")
	f.Int64VarP(&c.Memory, "memory", "m", 0, "Memory limit")
	f.StringArrayVar(&c.AddHost, "add-host", []string{}, "Add a custom host-to-IP mapping (host:ip)")
	f.StringArrayVar(&c.BlkioWeightDevice, "blkio-weight-device", []string{}, "Block IO weight (relative device weight) (default [])")
	f.StringArrayVar(&c.CapAdd, "cap-add", []string{}, "Add Linux capabilities")
	f.StringArrayVar(&c.CapDrop, "cap-drop", []string{}, "Drop Linux capabilities")
	f.StringArrayVar(&c.Device, "device", []string{}, "Add a host device to the container")
	f.StringArrayVar(&c.DeviceCgroupRule, "device-cgroup-rule", []string{}, "Add a rule to the cgroup allowed devices list")
	f.StringArrayVar(&c.DeviceReadBps, "device-read-bps", []string{}, "Limit read rate (bytes per second) from a device (default [])")
	f.StringArrayVar(&c.DeviceReadIops, "device-read-iops", []string{}, "Limit read rate (IO per second) from a device (default [])")
	f.StringArrayVar(&c.DeviceWriteBps, "device-write-bps", []string{}, "Limit write rate (bytes per second) to a device (default [])")
	f.StringArrayVar(&c.DeviceWriteIops, "device-write-iops", []string{}, "Limit write rate (IO per second) to a device (default [])")
	f.StringArrayVar(&c.Dns, "dns", []string{}, "Set custom DNS servers")
	f.StringArrayVar(&c.DnsOption, "dns-option", []string{}, "Set DNS options")
	f.StringArrayVar(&c.DnsSearch, "dns-search", []string{}, "Set custom DNS search domains")
	f.StringArrayVar(&c.EnvFile, "env-file", []string{}, "Read in a file of environment variables")
	f.StringArrayVar(&c.Expose, "expose", []string{}, "Expose a port or a range of ports")
	f.StringArrayVar(&c.GroupAdd, "group-add", []string{}, "Add additional groups to join")
	f.StringArrayVar(&c.LabelFile, "label-file", []string{}, "Read in a line delimited file of labels")
	f.StringArrayVar(&c.Link, "link", []string{}, "Add link to another container")
	f.StringArrayVar(&c.LinkLocalIP, "link-local-ip", []string{}, "Container IPv4/IPv6 link-local addresses")
	f.StringArrayVar(&c.LogOpt, "log-opt", []string{}, "Log driver options")
	f.StringArrayVar(&c.NetworkAlias, "network-alias", []string{}, "Add network-scoped alias for the container")
	f.StringArrayVar(&c.SecurityOpt, "security-opt", []string{}, "Security Options")
	f.StringArrayVar(&c.StorageOpt, "storage-opt", []string{}, "Storage driver options for the container")
	f.StringArrayVar(&c.Tmpfs, "tmpfs", []string{}, "Mount a tmpfs directory")
	f.StringArrayVar(&c.Ulimit, "ulimit", []string{}, "Ulimit options (default [])")
	f.StringArrayVar(&c.VolumesFrom, "volumes-from", []string{}, "Mount volumes from the specified container(s)")
	f.StringArrayVarP(&c.Attach, "attach", "a", []string{}, "Attach to STDIN, STDOUT or STDERR")
	f.StringArrayVarP(&c.Env, "env", "e", []string{}, "Set environment variables")
	f.StringArrayVarP(&c.Label, "label", "l", []string{}, "Set meta data on a container")
	f.StringArrayVarP(&c.Publish, "publish", "p", []string{}, "Publish a container's port(s) to the host")
	f.StringArrayVarP(&c.Volume, "volume", "v", []string{}, "Bind mount a volume")
	f.StringToStringVar(&c.Sysctl, "sysctl", map[string]string{}, "Sysctl options")
	f.StringVar(&c.Cgroupns, "cgroupns", "", "Cgroup namespace to use (host|private)\n'host':    Run the container in the Docker host's cgroup namespace\n'private': Run the container in its own private cgroup namespace\n'':        Use the cgroup namespace as configured by the default-cgroupns-mode option on the daemon (default)")
	f.StringVar(&c.CgroupParent, "cgroup-parent", "", "Optional parent cgroup for the container")
	f.StringVar(&c.Cidfile, "cidfile", "", "Write the container ID to the file")
	f.StringVar(&c.CpusetCpus, "cpuset-cpus", "", "CPUs in which to allow execution (0-3, 0,1)")
	f.StringVar(&c.CpusetMems, "cpuset-mems", "", "MEMs in which to allow execution (0-3, 0,1)")
	f.StringVar(&c.DetachKeys, "detach-keys", "", "Override the key sequence for detaching a container")
	f.StringVar(&c.Domainname, "domainname", "", "Container NIS domain name")
	f.StringVar(&c.Entrypoint, "entrypoint", "", "Overwrite the default ENTRYPOINT of the image")
	f.StringVar(&c.Gpus, "string", "", "GPU devices to add to the container ('all' to pass all GPUs)")
	f.StringVar(&c.HealthCmd, "health-cmd", "", "Command to run to check health")
	f.StringVar(&c.HealthInterval, "health-interval", "0s", "Time between running the check (ms|s|m|h)")
	f.StringVar(&c.HealthStartPeriod, "health-start-period", "0s", "Start period for the container to initialize before starting health-retries countdown (ms|s|m|h)")
	f.StringVar(&c.HealthTimeout, "health-timeout", "0s", "Maximum time to allow one check to run (ms|s|m|h)")
	f.StringVar(&c.Ip, "ip", "", "IPv4 address (e.g., 172.30.100.104)")
	f.StringVar(&c.Ip6, "ip6", "", "IPv6 address (e.g., 2001:db8::33)")
	f.StringVar(&c.Ipc, "ipc", "", "IPC mode to use")
	f.StringVar(&c.Isolation, "isolation", "", "Container isolation technology")
	f.StringVar(&c.LogDriver, "log-driver", "", "Logging driver for the container")
	f.StringVar(&c.Mac, "mac-address", "", "Container MAC address (e.g., 92:d0:c6:0a:29:33)")
	f.StringVar(&c.Mount, "mount", "", "Attach a filesystem mount to the container")
	f.StringVar(&c.ContainerName, "name", "", "Assign a name to the container")
	f.StringVar(&c.Network, "network", "", "Connect a container to a network")
	f.StringVar(&c.Pid, "pid", "", "PID namespace to use")
	f.StringVar(&c.Platform, "platform", "", "Set platform if server is multi-platform capable")
	f.StringVar(&c.Pull, "pull", "missing", "Pull image before running ('always'|'missing'|'never')")
	f.StringVar(&c.Restart, "restart", "no", "Restart policy to apply when a container exits")
	f.StringVar(&c.Runtime, "runtime", "", "Runtime to use for this container")
	f.StringVar(&c.StopSignal, "stop-signal", "SIGTERM", "Signal to stop a container")
	f.StringVar(&c.Userns, "userns", "", "User namespace to use")
	f.StringVar(&c.Uts, "uts", "", "UTS namespace to use")
	f.StringVar(&c.VolumeDriver, "volume-driver", "", "Optional volume driver for the container")
	f.StringVarP(&c.Hostname, "hostname", "h", "", "Container host name")
	f.StringVarP(&c.User, "user", "u", "", "Username or UID (format: <name|uid>[:<group|gid>])")
	f.StringVarP(&c.Workdir, "workdir", "w", "", "Working directory inside the container")

	c.GlobalFlags(f)
	return f
}

func (c *ExportCommand) AutocompleteFlags() complete.Flags {
	return command.MergeAutocompleteFlags(
		c.Meta.AutocompleteFlags(command.FlagSetClient),
		c.AutocompleteGlobalFlags(),
		complete.Flags{
			"--add-host":              complete.PredictAnything,
			"--attach":                complete.PredictAnything,
			"--blkio-weight-device":   complete.PredictAnything,
			"--blkio-weight":          complete.PredictAnything,
			"--cap-add":               complete.PredictAnything,
			"--cap-drop":              complete.PredictAnything,
			"--cgroup-parent":         complete.PredictAnything,
			"--cgroupns":              complete.PredictAnything,
			"--cidfile":               complete.PredictAnything,
			"--cpu-period":            complete.PredictAnything,
			"--cpu-quota":             complete.PredictAnything,
			"--cpu-rt-period":         complete.PredictAnything,
			"--cpu-rt-runtime":        complete.PredictAnything,
			"--cpu-shares":            complete.PredictAnything,
			"--cpus":                  complete.PredictAnything,
			"--cpuset-cpus":           complete.PredictAnything,
			"--cpuset-mems":           complete.PredictAnything,
			"--detach-keys":           complete.PredictAnything,
			"--detach":                complete.PredictNothing,
			"--device-cgroup-rule":    complete.PredictAnything,
			"--device-read-bps":       complete.PredictAnything,
			"--device-readIops":       complete.PredictAnything,
			"--device-write-bps":      complete.PredictAnything,
			"--device-write-iops":     complete.PredictAnything,
			"--device":                complete.PredictAnything,
			"--disable-content-trust": complete.PredictNothing,
			"--dns-option":            complete.PredictAnything,
			"--dns-search":            complete.PredictAnything,
			"--dns":                   complete.PredictAnything,
			"--domainname":            complete.PredictAnything,
			"--entrypoint":            complete.PredictAnything,
			"--env-file":              complete.PredictAnything,
			"--env":                   complete.PredictAnything,
			"--expose":                complete.PredictAnything,
			"--gpus":                  complete.PredictAnything,
			"--group-add":             complete.PredictAnything,
			"--health-cmd":            complete.PredictAnything,
			"--health-retries":        complete.PredictAnything,
			"--health-start-period":   complete.PredictAnything,
			"--health-timeout":        complete.PredictAnything,
			"--health-tnterval":       complete.PredictAnything,
			"--hostname":              complete.PredictAnything,
			"--init":                  complete.PredictNothing,
			"--interactive":           complete.PredictNothing,
			"--ip":                    complete.PredictAnything,
			"--ip6":                   complete.PredictAnything,
			"--ipc":                   complete.PredictAnything,
			"--isolation":             complete.PredictAnything,
			"--kernel-memory":         complete.PredictAnything,
			"--label-file":            complete.PredictAnything,
			"--label":                 complete.PredictAnything,
			"--link-local-ip":         complete.PredictAnything,
			"--link":                  complete.PredictAnything,
			"--log-driver":            complete.PredictAnything,
			"--log-opt":               complete.PredictAnything,
			"--mac":                   complete.PredictAnything,
			"--memory-reservation":    complete.PredictAnything,
			"--memory-swap":           complete.PredictAnything,
			"--memory-swappiness":     complete.PredictAnything,
			"--memory":                complete.PredictAnything,
			"--mount":                 complete.PredictAnything,
			"--name":                  complete.PredictAnything,
			"--network-alias":         complete.PredictAnything,
			"--network":               complete.PredictAnything,
			"--no-healthcheck":        complete.PredictNothing,
			"--oom-kill-disable":      complete.PredictNothing,
			"--oom-score":             complete.PredictAnything,
			"--pid":                   complete.PredictAnything,
			"--pidslimit":             complete.PredictAnything,
			"--platform":              complete.PredictAnything,
			"--privileged":            complete.PredictNothing,
			"--publish-all":           complete.PredictNothing,
			"--publish":               complete.PredictAnything,
			"--pull":                  complete.PredictAnything,
			"--read-only":             complete.PredictNothing,
			"--restart":               complete.PredictAnything,
			"--rm":                    complete.PredictNothing,
			"--runtime":               complete.PredictAnything,
			"--security-opt":          complete.PredictAnything,
			"--shm-size":              complete.PredictAnything,
			"--sig-proxy":             complete.PredictNothing,
			"--stop-signal":           complete.PredictAnything,
			"--stop-timeout":          complete.PredictAnything,
			"--storage-opt":           complete.PredictAnything,
			"--sysctl":                complete.PredictAnything,
			"--tmpfs":                 complete.PredictAnything,
			"--tty":                   complete.PredictNothing,
			"--ulimit":                complete.PredictAnything,
			"--user":                  complete.PredictAnything,
			"--userns":                complete.PredictAnything,
			"--uts":                   complete.PredictAnything,
			"--volume-driver":         complete.PredictAnything,
			"--volume":                complete.PredictAnything,
			"--volumes-from":          complete.PredictAnything,
			"--workdir":               complete.PredictAnything,
		},
	)
}

func (c *ExportCommand) Run(args []string) int {
	flags := c.FlagSet()
	flags.Usage = func() { c.Ui.Output(c.Help()) }
	if err := flags.Parse(args); err != nil {
		c.Ui.Error(err.Error())
		c.Ui.Error(command.CommandErrorText(c))
		return 1
	}

	arguments, err := c.ParsedArguments(flags.Args())
	if err != nil {
		c.Ui.Error(err.Error())
		c.Ui.Error(command.CommandErrorText(c))
		return 1
	}

	project, warnings, errs := convert.ToCompose(c.project, &c.Args, arguments)
	if warnings != nil {
		for _, warning := range warnings.Errors {
			c.Ui.Error(warning.Error())
		}
	}
	if errs != nil {
		for _, err := range errs.Errors {
			c.Ui.Error(err.Error())
		}
		return 1
	}

	out, err := convert.MarshalCompose(project, "yaml")
	if err != nil {
		c.Ui.Error(err.Error())
		return 1
	}

	println("---")
	println(string(out))

	return 0
}
