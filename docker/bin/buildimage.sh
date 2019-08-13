#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"

COMMANDS_BRANCH="$1"
if [ -z "$COMMANDS_BRANCH" ]; then
    COMMANDS_BRANCH=$(git symbolic-ref --short HEAD 2> /dev/null)
    if [ -z "$COMMANDS_BRANCH" ]; then
        echo "No commands branch specified"
        exit 1
    fi
fi
echo "Using commands branch/tag: $COMMANDS_BRANCH"

DOCKER_DIR="$SCRIPT_DIR/.."
IMAGE_DIR="$DOCKER_DIR/image"
COMMANDS_DIR="$DOCKER_DIR/.."
SSH_PRIVATE_KEY_FILE="$COMMANDS_DIR"/machine_user_key
if [ ! -e "$SSH_PRIVATE_KEY_FILE" ]; then
    # This file can be gotten from Oneiro's 1password account and placed in the docker directory.
    echo "Cannot find $SSH_PRIVATE_KEY_FILE needed for cloning private oneiro-ndev repositories"
    exit 1
fi
SSH_PRIVATE_KEY=$(cat "$SSH_PRIVATE_KEY_FILE")

NDAU_IMAGE_NAME=ndauimage
if [ -n "$(docker container ls -a -q -f ancestor=$NDAU_IMAGE_NAME)" ]; then
    echo "-------"
    echo "WARNING: containers exist based on an old $NDAU_IMAGE_NAME; they should be removed"
    echo "-------"
fi

# update shas for cache-busting when appropriate
curl -s https://api.github.com/repos/oneiro-ndev/noms/git/refs/heads/master |\
    jq -r .object.sha > "$IMAGE_DIR/noms_sha"
git rev-parse HEAD > "$IMAGE_DIR/commands_sha"
if [ -n "$(git status --porcelain)" ]; then
    echo "WARN: uncommitted changes"
    echo "docker image contains only committed work ($(git rev-parse --short HEAD))"
fi

# update dependencies for cache-busting when appropriate
cp "$COMMANDS_DIR"/Gopkg.* "$IMAGE_DIR"/

echo Silencing warning about Transparent Huge Pages when redis-server runs...
docker run --rm -it --privileged --pid=host debian nsenter -t 1 -m -u -n -i \
       sh -c 'echo never > /sys/kernel/mm/transparent_hugepage/enabled'
docker run --rm -it --privileged --pid=host debian nsenter -t 1 -m -u -n -i \
       sh -c 'echo never > /sys/kernel/mm/transparent_hugepage/defrag'

echo "Building $NDAU_IMAGE_NAME..."
docker build \
       --build-arg SSH_PRIVATE_KEY="$SSH_PRIVATE_KEY" \
       --build-arg COMMANDS_BRANCH="$COMMANDS_BRANCH" \
       "$IMAGE_DIR" \
       --tag="$NDAU_IMAGE_NAME:$(git rev-parse --short HEAD)" \
       --tag="$NDAU_IMAGE_NAME:latest"
echo "done"
