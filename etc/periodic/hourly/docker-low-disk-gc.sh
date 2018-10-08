#!/bin/bash
set -euo pipefail

source /etc/docker/docker-gc-filter

DOCKER_PRUNE_UNTIL=${DOCKER_PRUNE_UNTIL:-1h}
## -----------------------------------------------------------------
## Check disk, we only want to prune images/containers if we have to

if ! /usr/sbin/bk-check-disk-space.sh ; then
  echo "Cleaning up docker resources older than ${DOCKER_PRUNE_UNTIL}"

  if [ -z "$DOCKER_GC_FILTER" ]; then
    DOCKER_GC_FILTER=--filter "${DOCKER_GC_FILTER}"
  fi

  docker system prune --all --force --filter "until=${DOCKER_PRUNE_UNTIL}" ${DOCKER_GC_FILTER}

  if ! /usr/sbin/bk-check-disk-space.sh ; then
    echo "Disk health checks failed" >&2
    exit 1
  fi
fi