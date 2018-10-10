#!/bin/bash
set -euo pipefail

source /etc/docker/docker-gc-filter

DOCKER_PRUNE_UNTIL=${DOCKER_PRUNE_UNTIL:-4h}

## ------------------------------------------
## Prune stuff that doesn't affect cache hits

if [ -n "$DOCKER_GC_FILTER" ]; then
    FILTER=""
    IFS=';' read -ra ADDR <<< "$DOCKER_GC_FILTER"
    for i in "${ADDR[@]}"; do
	echo $i
        FILTER="$FILTER --filter $i"
    done
fi

docker system prune --force --filter "until=${DOCKER_PRUNE_UNTIL}" ${FILTER}