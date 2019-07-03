package main

import (
	"fmt"

	cli "github.com/jawher/mow.cli"
	"github.com/oneiro-ndev/ndau/pkg/ndau"
	"github.com/oneiro-ndev/ndau/pkg/tool"
)

func getAccountCreditEAI(verbose *bool, keys *int, emitJSON, compact *bool) func(*cli.Cmd) {
	return func(cmd *cli.Cmd) {
		cmd.Spec = "NAME"

		var name = cmd.StringArg("NAME", "", "Name of account whose delegates' EAI should be calculated")

		cmd.Action = func() {
			conf := getConfig()
			acct, hasAcct := conf.Accounts[*name]
			if !hasAcct {
				orQuit(fmt.Errorf("No such account: %s", *name))
			}
			if acct.Validation == nil {
				orQuit(fmt.Errorf("Validation key for %s not set", *name))
			}

			if *verbose {
				fmt.Printf(
					"Calculating EAI for delegates to node %s\n",
					acct.Address.String(),
				)
			}

			tx := ndau.NewCreditEAI(
				acct.Address,
				sequence(conf, acct.Address),
				acct.ValidationPrivateK(*keys)...,
			)

			resp, err := tool.SendCommit(tmnode(conf.Node, emitJSON, compact), tx)
			finish(*verbose, resp, err, "compute-eai")
		}
	}
}
