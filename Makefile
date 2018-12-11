###################################
# This Makefile builds several of the chaincode tools.

# Chaincode depends on the opcodes project, which uses a template system to generate
# sources for several things -- the documentation for chaincode as well as much of the
# implementation of both the VM and the assembler. This ensures that the various parts
# don't get out of sync with each other.
###################################

# define a few of the executables we're building
CHASM = cmd/chasm/chasm
CHAIN = cmd/chain/chain
CRANK = cmd/crank/crank
CHFMT = cmd/chfmt/chfmt
EXAMPLES = cmd/chasm/examples
OPCODES = cmd/opcodes/opcodes
OPCODESMD = cmd/opcodes/opcodes.md

# And identify the location of the chaincode packages
CHAINCODEPKG = ../chaincode/pkg

###################################
### Some conveniences

.PHONY: generate clean fuzz fuzzmillion benchmarks \
	test examples chaincodeall build chasm crank chfmt opcodes format

opcodes: $(OPCODES)

crank: $(CRANK)

chasm: $(CHASM)

chfmt: $(CHFMT)

###################################
### Utilities

default: build

setup:
	hash pigeon
	hash msgp
	hash stringer
	go get $(CHAINCODEPKG)/...

clean:
	rm -f $(OPCODES)
	rm -f $(CHASM)
	rm -f $(CRANK)
	rm -f $(CHFMT)
	# generated files
	rm -f cmd/chasm/chasm.go
	rm -f cmd/chfmt/chfmt.go

build: generate opcodes chasm crank chfmt

test: cmd/chasm/chasm.go $(CHAINCODEPKG)/vm/*.go $(CHAINCODEPKG)/chain/*.go chasm
	rm -f /tmp/cover*
	go test $(CHAINCODEPKG)/chain -v --race -timeout 10s -coverprofile=/tmp/coverchain
	go test ./cmd/chasm -v --race -timeout 10s -coverprofile=/tmp/coverchasm
	go test $(CHAINCODEPKG)/vm -v --race -timeout 10s -coverprofile=/tmp/covervm

chaincodeall: clean generate build test fuzz benchmarks format examples

###################################
### Opcodes

$(OPCODESMD): opcodes
	$(OPCODES) --opcodes $(OPCODESMD)

$(CHAINCODEPKG)/vm/opcodes.go: opcodes
	$(OPCODES) --defs $(CHAINCODEPKG)/vm/opcodes.go

$(CHAINCODEPKG)/vm/miniasmOpcodes.go: opcodes
	$(OPCODES) --miniasm $(CHAINCODEPKG)/vm/miniasmOpcodes.go

$(CHAINCODEPKG)/vm/extrabytes.go: opcodes
	$(OPCODES) --extra $(CHAINCODEPKG)/vm/extrabytes.go

$(CHAINCODEPKG)/vm/enabledopcodes.go: opcodes
	$(OPCODES) --enabled $(CHAINCODEPKG)/vm/enabledopcodes.go

cmd/chasm/chasm.peggo: opcodes
	$(OPCODES) --pigeon cmd/chasm/chasm.peggo

cmd/chasm/predefined.go: opcodes
	$(OPCODES) --consts cmd/chasm/predefined.go

$(OPCODES): cmd/opcodes/*.go
	cd cmd/opcodes && go build

###################################
### The vm itself and its tests

generate: $(OPCODESMD) $(CHAINCODEPKG)/vm/opcodes.go $(CHAINCODEPKG)/vm/miniasmOpcodes.go $(CHAINCODEPKG)/vm/opcode_string.go \
		$(CHAINCODEPKG)/vm/extrabytes.go $(CHAINCODEPKG)/vm/enabledopcodes.go \
		cmd/chasm/chasm.peggo cmd/chasm/predefined.go

$(CHAINCODEPKG)/vm/opcode_string.go: $(CHAINCODEPKG)/vm/opcodes.go
	go generate $(CHAINCODEPKG)/vm

fuzz: test
	FUZZ_RUNS=10000 go test --race -v -timeout 1m $(CHAINCODEPKG)/vm -run "TestFuzz*" -coverprofile=/tmp/coverfuzz

fuzzmillion: test
	FUZZ_RUNS=1000000 go test --race -v -timeout 2h $(CHAINCODEPKG)/vm -run "TestFuzz*" -coverprofile=/tmp/coverfuzz

benchmarks:
	cd $(CHAINCODEPKG)/vm && go test -bench=. -benchmem

###################################
### The chasm assembler

$(CHASM): cmd/chasm/chasm.go $(CHAINCODEPKG)/vm/opcodes.go cmd/chasm/*.go generate
	go build -o $(CHASM) ./cmd/chasm

cmd/chasm/chasm.go: cmd/chasm/chasm.peggo
	pigeon -o ./cmd/chasm/chasm.go ./cmd/chasm/chasm.peggo

examples: chasm
	$(CHASM) --output $(EXAMPLES)/quadratic.chbin --comment "Test of quadratic" $(EXAMPLES)/quadratic.chasm
	$(CHASM) --output $(EXAMPLES)/majority.chbin --comment "Test of majority" $(EXAMPLES)/majority.chasm
	$(CHASM) --output $(EXAMPLES)/onePlus1of3.chbin --comment "1+1of3" $(EXAMPLES)/onePlus1of3.chasm
	$(CHASM) --output $(EXAMPLES)/first.chbin --comment "the first key must be set" $(EXAMPLES)/first.chasm
	$(CHASM) --output $(EXAMPLES)/one.chbin --comment "unconditionally return numeric 1" $(EXAMPLES)/one.chasm
	$(CHASM) --output $(EXAMPLES)/zero.chbin --comment "returns numeric 0 in all cases" $(EXAMPLES)/zero.chasm
	$(CHASM) --output $(EXAMPLES)/rfe.chbin --comment "standard RFE rules" $(EXAMPLES)/rfe.chasm

###################################
### The chfmt formatter

format: chfmt
	$(CHFMT) -O $(EXAMPLES)/quadratic.chasm
	$(CHFMT) -O $(EXAMPLES)/majority.chasm
	$(CHFMT) -O $(EXAMPLES)/onePlus1of3.chasm
	$(CHFMT) -O $(EXAMPLES)/first.chasm
	$(CHFMT) -O $(EXAMPLES)/one.chasm
	$(CHFMT) -O $(EXAMPLES)/zero.chasm
	$(CHFMT) -O $(EXAMPLES)/rfe.chasm

cmd/chfmt/chfmt.go: cmd/chfmt/chfmt.peggo
	pigeon -o ./cmd/chfmt/chfmt.go ./cmd/chfmt/chfmt.peggo

$(CHFMT): cmd/chfmt/*.go cmd/chfmt/chfmt.go generate
	go build -o $(CHFMT) ./cmd/chfmt


###################################
### The crank debugger/runtime

$(CRANK): cmd/crank/*.go generate
	go build -o $(CRANK) ./cmd/crank
