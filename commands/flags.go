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
	f.StringVar(&c.format, "dre-format", "compose", "format to export to")
	f.StringVar(&c.project, "dre-project", "", "project name to use")
}

func (c *GlobalFlagCommand) AutocompleteGlobalFlags() complete.Flags {
	return complete.Flags{
		"--dre-format":  complete.PredictAnything,
		"--dre-project": complete.PredictAnything,
	}
}
