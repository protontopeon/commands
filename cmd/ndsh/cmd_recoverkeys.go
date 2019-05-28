package main

import (
	"fmt"
	"strings"

	"github.com/alexflint/go-arg"
	"github.com/oneiro-ndev/ndaumath/pkg/signature"
	"github.com/pkg/errors"
)

func kpf(kp string) func(int, int) string {
	return func(acct, key int) string {
		return fmt.Sprintf(kp, acct, key)
	}
}

var keyPatterns = []func(acctidx, keyidx int) string{
	kpf("/44'/20036'/2000/%d/%d"),
	kpf("/44'/20036'/100/%d/44'/20036'/2000/%d"),
	kpf("/44'/20036'/100/10000/%d/%d"),
	kpf("/44'/20036'/100/10000'/%d'/%d"),
	func(acct, key int) string {
		return fmt.Sprintf("/44'/20036'/100/%d/44'/20036'/100/10000/%d/%d", acct, acct, key)
	},
}

// RecoverKeys recovers the keys of an account
type RecoverKeys struct{}

var _ Command = (*RecoverKeys)(nil)

// Name implements Command
func (RecoverKeys) Name() string { return "recover-keys" }

type recoverkeysargs struct {
	Account     string `arg:"positional" help:"recover keys for this account"`
	Persistence int    `help:"number of non-keys to discover before deciding there are no more in a particular derivation style"`
}

func (recoverkeysargs) Description() string {
	return strings.TrimSpace(`
Recover validation keys for an account.

This discovers the private validation keys associated with this account, if
possible.

There are several circumstances in which private keys are impossible to derive
from the public keys. For example, if the account's ownership keys are not HD,
or the keys were not derived from the account's root key, or the derivation
path is unexpected, then the keys cannot be automatically derived. However,
this should be able to recover private keys for most ndau accounts for which
the root key is known.
	`)
}

// Run implements Command
func (RecoverKeys) Run(argvs []string, sh *Shell) (err error) {
	args := recoverkeysargs{
		Persistence: 50,
	}

	err = ParseInto(argvs, &args)
	if err != nil {
		if err == arg.ErrHelp || err == arg.ErrVersion {
			err = nil
		}
		return
	}

	var acct *Account
	acct, err = sh.accts.Get(args.Account)
	if err != nil {
		return
	}

	if len(acct.Data.ValidationKeys) == 0 {
		return errors.New("no validation keys are set")
	}
	if acct.root == nil {
		return errors.New("root key is not known")
	}
	if acct.Path == "" {
		return errors.New("account path is not known")
	}

	var acctidx uint
	_, err = fmt.Sscanf(acct.Path, defaultPathFmt, &acctidx)
	if err != nil {
		return errors.Wrap(err, "getting account idx from path")
	}

	remaining := make(map[*signature.PublicKey]struct{})
	for _, public := range acct.Data.ValidationKeys {
		remaining[&public] = struct{}{}
	}
	if sh.Verbose {
		sh.Write("existing validation keys on blockchain:")
		for rem := range remaining {
			sh.Write("  %s", rem)
		}
	}

	found := 0
	defer func(found *int) {
		sh.Write("found %d private keys", *found)
	}(&found)

	for _, pattern := range keyPatterns {
		keyidx := 0
		for failures := 0; failures < args.Persistence; {
			pvt := deriveKey(
				sh,
				&failures,
				pattern,
				acctidx, &keyidx,
				acct,
				remaining,
			)
			if pvt != nil {
				acct.PrivateValidationKeys = append(
					acct.PrivateValidationKeys,
					*pvt,
				)
				if keyidx > acct.highKeyidx {
					acct.highKeyidx = keyidx
				}
				found++
			}
			if len(remaining) == 0 {
				return
			}
		}
	}

	return
}

// we just broke this function out in order to use defer
func deriveKey(
	sh *Shell,
	failures *int,
	pattern func(int, int) string,
	acctidx uint, keyidx *int,
	acct *Account,
	remaining map[*signature.PublicKey]struct{},
) *signature.PrivateKey {
	var succeeded bool
	defer func() {
		*keyidx++
		if !succeeded {
			*failures++
		}
	}()

	keypath := pattern(int(acctidx), *keyidx)
	if sh.Verbose {
		sh.Write("deriving key from pattern %s...", keypath)
	}
	k, err := acct.root.DeriveFrom("/", keypath)
	if err != nil {
		sh.Write("%s: %s", keypath, err)
		return nil
	}

	pvt, err := k.SPrivKey()
	if err != nil {
		sh.Write("%s: %s", "getting signature-style key from key", err)
		return nil
	}
	if sh.Verbose {
		sh.Write("  %s", pvt)
	}

	for pub := range remaining {
		if signature.Match(*pub, *pvt) {
			succeeded = true
			delete(remaining, pub)
			if sh.Verbose {
				sh.Write("  matches %s; %d pubkeys remaining", pub, len(remaining))
			}
			return pvt
		}
	}
	return nil
}
