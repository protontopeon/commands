package main

import (
	"bytes"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"strings"

	cli "github.com/jawher/mow.cli"
	"github.com/oneiro-ndev/json2msgp"
	"github.com/pkg/errors"
)

func inOpt(hyphens bool, name, option string) string {
	var h string
	if hyphens {
		h = "--"
	}
	return fmt.Sprintf(
		"%s%s-%s",
		h,
		strings.ToLower(name),
		option,
	)
}

func getInputSpec(name string) string {
	return fmt.Sprintf(
		"[%s|%s|%s] (%s | %s=<PATH>)",
		inOpt(true, name, "base64"),
		inOpt(true, name, "json"),
		inOpt(true, name, "hex"),
		strings.ToUpper(name),
		inOpt(true, name, "file"),
	)
}

func getInputClosure(cmd *cli.Cmd, name string, verbose *bool) func() []byte {
	var (
		base64In  = cmd.BoolOpt(inOpt(false, name, "base64"), false, "if set, interpret input as base64-encoded")
		jsonIn    = cmd.BoolOpt(inOpt(false, name, "json"), false, "if set, interpret input as JSON and convert to MSGP format")
		hexIn     = cmd.BoolOpt(inOpt(false, name, "hex"), false, "if set, interpret input as hex-encoded")
		input     = cmd.StringArg(strings.ToUpper(name), "", fmt.Sprintf("%s input", name))
		inputFile = cmd.StringOpt(inOpt(false, name, "file"), "", "read input from this file instead of the CLI")
	)

	return func() []byte {
		var reader io.Reader
		switch {
		case input != nil && len(*input) > 0:
			if *verbose {
				fmt.Println(name, "input from cli")
			}
			reader = bytes.NewBufferString(*input)
		case inputFile != nil && len(*inputFile) > 0:
			if *verbose {
				fmt.Println(name, "input from", *inputFile)
			}
			file, err := os.Open(*inputFile)
			orQuit(err)
			defer file.Close()
			reader = file
		default:
			orQuit(errors.New("no input provided"))
		}

		data, err := ioutil.ReadAll(reader)
		orQuit(err)

		switch {
		case base64In != nil && *base64In:
			if *verbose {
				fmt.Println(name, "input is b64")
			}
			out, err := base64.StdEncoding.DecodeString(string(data))
			orQuit(err)
			if *verbose {
				fmt.Printf("%s input is %d bytes long\n", name, len(out))
			}
			return out
		case hexIn != nil && *hexIn:
			if *verbose {
				fmt.Println(name, "input is hex")
			}
			out, err := hex.DecodeString(string(data))
			orQuit(err)
			if *verbose {
				fmt.Printf("%s input is %d bytes long\n", name, len(out))
			}
			return out
		case jsonIn != nil && *jsonIn:
			if *verbose {
				fmt.Println(name, "input is json -> msgp")
			}
			inbuf := bytes.NewBuffer(data)
			outbuf := &bytes.Buffer{}
			err = json2msgp.ConvertStream(inbuf, outbuf)
			orQuit(err)
			out := outbuf.Bytes()
			if *verbose {
				fmt.Printf("%s input is %d bytes long\n", name, len(out))
			}
			return out
		default:
			if *verbose {
				fmt.Println(name, "input is a string literal")
				fmt.Printf("%s input is %d bytes long\n", name, len(data))
			}
			return data
		}
	}
}

// getKeySpec returns a portion of the specification string,
// specifying key setting options
func getKeySpec() string {
	return getInputSpec("key")
}

// getKeyClosure sets the appropriate options for a command to get the key
// using a variety of argument styles.
func getKeyClosure(cmd *cli.Cmd, verbose *bool) func() []byte {
	return getInputClosure(cmd, "key", verbose)
}

// getValueSpec returns a portion of the specification string,
// specifying value setting options
func getValueSpec() string {
	return getInputSpec("value")
}

// getValueClosure sets the appropriate options for a command to get the value
// using a variety of argument styles.
func getValueClosure(cmd *cli.Cmd, verbose *bool) func() []byte {
	return getInputClosure(cmd, "value", verbose)
}