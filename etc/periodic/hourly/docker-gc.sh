#!/bin/bash
set -euo pipefail

source /etc/docker/docker-gc-filter

DOCKER_PRUNE_UNTIL=${DOCKER_PRUNE_UNTIL:-4h}

## ------------------------------------------
## Prune stuff that doesn't affect cache hits

if [ -z "$DOCKER_GC_FILTER" ]; then
    DOCKER_GC_FILTER=--filter "${DOCKER_GC_FILTER}"
fi

docker system prune --force --filter "until=${DOCKER_PRUNE_UNTIL}" ${DOCKER_GC_FILTER}