package commands

import (
	"github.com/posener/complete"
	flag "github.com/spf13/pflag"
)

type GlobalFlagCommand struct {
	format                     string
	project                    string
	ecsTaskRoleArn             string
	ecsExecutionRoleArn        string
	ecsRequiresCompatibilities []string
	nomadDatacenters           []string
	nomadRegion                string
	nomadNamespace             string
	nomadType                  string
	nomadCount                 int
}

func (c *GlobalFlagCommand) GlobalFlags(f *flag.FlagSet) {
	f.StringVar(&c.format, "dre-format", "compose", "format to export to")
	f.StringVar(&c.project, "dre-project", "", "project name to use")
	f.StringVar(&c.ecsTaskRoleArn, "dre-ecs-task-role-arn", "", "ECS task role ARN")
	f.StringVar(&c.ecsExecutionRoleArn, "dre-ecs-execution-role-arn", "", "ECS execution role ARN")
	f.StringArrayVar(&c.ecsRequiresCompatibilities, "dre-ecs-launch-type", []string{}, "ECS launch type compatibility (FARGATE, EC2)")
	f.StringArrayVar(&c.nomadDatacenters, "dre-nomad-datacenter", []string{"dc1"}, "Nomad datacenter(s)")
	f.StringVar(&c.nomadRegion, "dre-nomad-region", "", "Nomad region")
	f.StringVar(&c.nomadNamespace, "dre-nomad-namespace", "", "Nomad namespace")
	f.StringVar(&c.nomadType, "dre-nomad-type", "service", "Nomad job type (service, batch, system)")
	f.IntVar(&c.nomadCount, "dre-nomad-count", 1, "Number of task group instances")
}

func (c *GlobalFlagCommand) AutocompleteGlobalFlags() complete.Flags {
	return complete.Flags{
		"--dre-format":                 complete.PredictAnything,
		"--dre-project":                complete.PredictAnything,
		"--dre-ecs-task-role-arn":      complete.PredictAnything,
		"--dre-ecs-execution-role-arn": complete.PredictAnything,
		"--dre-ecs-launch-type":        complete.PredictAnything,
		"--dre-nomad-datacenter":       complete.PredictAnything,
		"--dre-nomad-region":           complete.PredictAnything,
		"--dre-nomad-namespace":        complete.PredictAnything,
		"--dre-nomad-type":             complete.PredictAnything,
		"--dre-nomad-count":            complete.PredictAnything,
	}
}
