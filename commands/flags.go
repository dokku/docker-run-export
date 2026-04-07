package commands

import (
	"github.com/posener/complete"
	flag "github.com/spf13/pflag"
)

type GlobalFlagCommand struct {
	format                  string
	project                 string
	ecsTaskRoleArn          string
	ecsExecutionRoleArn     string
	ecsRequiresCompatibilities []string
}

func (c *GlobalFlagCommand) GlobalFlags(f *flag.FlagSet) {
	f.StringVar(&c.format, "dre-format", "compose", "format to export to")
	f.StringVar(&c.project, "dre-project", "", "project name to use")
	f.StringVar(&c.ecsTaskRoleArn, "dre-ecs-task-role-arn", "", "ECS task role ARN")
	f.StringVar(&c.ecsExecutionRoleArn, "dre-ecs-execution-role-arn", "", "ECS execution role ARN")
	f.StringArrayVar(&c.ecsRequiresCompatibilities, "dre-ecs-launch-type", []string{}, "ECS launch type compatibility (FARGATE, EC2)")
}

func (c *GlobalFlagCommand) AutocompleteGlobalFlags() complete.Flags {
	return complete.Flags{
		"--dre-format":                complete.PredictAnything,
		"--dre-project":               complete.PredictAnything,
		"--dre-ecs-task-role-arn":      complete.PredictAnything,
		"--dre-ecs-execution-role-arn": complete.PredictAnything,
		"--dre-ecs-launch-type":        complete.PredictAnything,
	}
}
