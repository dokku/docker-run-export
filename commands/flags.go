package commands

import (
	"github.com/posener/complete"
	flag "github.com/spf13/pflag"
)

type GlobalFlagCommand struct {
	format  string
	project string
}

func (c *GlobalFlagCommand) GlobalFlags(f *flag.FlagSet) {
	f.StringVar(&c.format, "format", "compose", "format to export to")
	f.StringVar(&c.project, "project", "", "project name to use")
}

func (c *GlobalFlagCommand) AutocompleteGlobalFlags() complete.Flags {
	return complete.Flags{
		"--format":  complete.PredictAnything,
		"--project": complete.PredictAnything,
	}
}
