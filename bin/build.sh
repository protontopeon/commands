#!/bin/bash

# Stop building later steps if an earlier step fails.
set -e

initialize() {
    CMDBIN_DIR="$(go env GOPATH)/src/github.com/oneiro-ndev/commands/bin"
    # shellcheck disable=SC1090
    source "$CMDBIN_DIR"/env.sh
}

build_chaos() {
    echo building chaos
    cd "$COMMANDS_DIR"

    go build ./"$CHAOS_CMD"
    go build ./"$CHAOSNODE_CMD"
}

build_ndau() {
    echo building ndau
    cd "$NDAU_DIR"
    # This was adapted from ndau/bin/build.sh.  We don't want to use any more of it than what we
    # have here since it uses different environment settings than our setup scripts do for a local
    # build.  e.g. We use separate TMHOME's for each of chaos and ndau.
    VERSION=$(git describe --long --tags)
    echo "  VERSION=$VERSION"
    VERSION_FILE=github.com/oneiro-ndev/ndau/pkg/version

    cd "$COMMANDS_DIR"
    go build -ldflags "-X $VERSION_FILE.version=$VERSION" ./"$NDAU_CMD"
    go build -ldflags "-X $VERSION_FILE.version=$VERSION" ./"$NDAUNODE_CMD"
    go build ./"$NDAUAPI_CMD"
}

build_chaos_genesis() {
    echo building chaos_genesis
    cd "$COMMANDS_DIR"

    go build ./"$GENERATE_CMD"
    go build ./"$GENESIS_CMD"
}

build_tm() {
    echo building tendermint
    cd "$TENDERMINT_DIR"
    go build ./"$TENDERMINT_CMD"
}

build_noms() {
    echo building noms
    cd "$NOMS_DIR"
    go build ./"$NOMS_CMD"
}

build_all() {
    initialize
    build_noms
    build_tm
    build_chaos
    build_ndau
    build_chaos_genesis
}

build_all
echo "done."