#!/bin/bash

# Halt on any error.
set -e

# Load our environment variables.
CMDBIN_DIR="$(go env GOPATH)/src/github.com/oneiro-ndev/commands/bin"
# shellcheck disable=SC1090
source "$CMDBIN_DIR"/env.sh

# Process command line arguments.
node_count="$1"
if [ -z "$node_count" ]; then
    echo "Usage: ./setup.sh node_count"
    exit 1
fi
if [[ ! "$node_count" =~ ^[0-9]+$ ]]; then
    echo Node count must be a positive integer
    exit 1
fi
if [ "$node_count" -lt 1 ] || [ "$node_count" -gt "$MAX_NODE_COUNT" ]; then
    echo Node count must be in [1, "$MAX_NODE_COUNT"]
    exit 1
fi

# Initialize global config for the localnet we're setting up.
echo SETUP: Initializing a "$node_count"-node localnet...
# Recreate the localnet dir which contains the root data dir.
rm -rf "$LOCALNET_DIR"
mkdir -p "$ROOT_DATA_DIR"
echo "$node_count" > "$NODE_COUNT_FILE"

# Get the correct version of noms source.
mkdir -p "$ATTICLABS_DIR"
cd "$ATTICLABS_DIR"
if [ -d "noms" ]; then
    cd noms
    ORIGIN_URL=$(git config --get remote.origin.url)
    if [ "$ORIGIN_URL" == "$NOMS_REPO" ]; then
        echo SETUP: Updating noms...
        git checkout master
        git pull origin master
    else
        echo SETUP: Replacing unsupported noms repo...
        cd ..
        rm -rf noms
        git clone "$NOMS_REPO"
    fi
else
    echo SETUP: Cloning noms...
    git clone "$NOMS_REPO"
fi

# Get the correct version of tendermint source.
echo SETUP: Getting dep...
go get -u github.com/golang/dep/...
mkdir -p "$TM_DIR"
cd "$TM_DIR"
if [ -d "tendermint" ]; then
    echo SETUP: Updating tendermint...
    cd tendermint
    git checkout -- Gopkg.lock
    # Simulate the same state as the else case for consistency.
    git checkout master
    git pull origin master
else
    echo SETUP: Cloning tendermint...
    git clone "$TENDERMINT_REPO"
    cd tendermint
fi
echo SETUP: Checking out tendermint "$TENDERMINT_VER"...
git checkout "$TENDERMINT_VER"
echo SETUP: Ensuring tendermint dependencies...
"$GO_DIR"/bin/dep ensure

# Get the ndev repos.
update_repo() {
    repo="$1"
    cd "$NDEV_DIR"
    if [ -d "$repo" ]; then
        echo SETUP: Updating "$repo"...
        cd "$repo"
        git pull origin "$("$CMDBIN_DIR"/branch.sh)"
    else
        echo SETUP: Cloning "$repo"...
        git clone git@github.com:oneiro-ndev/"$repo".git
    fi
}

mkdir -p "$NDEV_DIR"
update_repo commands
update_repo chaos
update_repo ndau
update_repo chaos_genesis

cd "$NDEV_DIR"/commands
echo "SETUP: Running commands' dep ensure..."
"$GO_DIR"/bin/dep ensure

# Build everything.
echo SETUP: Building...
"$CMDBIN_DIR"/build.sh

# Test everything.
echo SETUP: Testing...
"$CMDBIN_DIR"/test.sh

# Configure everything.
echo SETUP: Configuring...
"$CMDBIN_DIR"/conf.sh

echo SETUP: Setup complete
