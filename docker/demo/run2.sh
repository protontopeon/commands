#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
cd "$SCRIPT_DIR" || exit 1

IP=$(./get_ip.sh)

SNAPSHOT=$(./get_snapshot.sh)

../bin/runcontainer.sh \
    localnet-2 26662 26672 3032 \
    "$IP:26660:26670,$IP:26661:26671" \
    $SNAPSHOT \
    ../../bin/ndau-snapshots/node-identity-2.tgz