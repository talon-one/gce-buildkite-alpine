#!/bin/bash
set -euo pipefail



DOCKER_PRUNE_UNTIL=${DOCKER_PRUNE_UNTIL:-1h}
## -----------------------------------------------------------------
## Check disk, we only want to prune images/containers if we have to

if ! /usr/sbin/bk-check-disk-space.sh ; then
  echo "Cleaning up docker resources older than ${DOCKER_PRUNE_UNTIL}"

  source /etc/docker/docker-gc-filter

  if [ -n "$DOCKER_GC_FILTER" ]; then
      FILTER=""
      IFS=';' read -ra ADDR <<< "$DOCKER_GC_FILTER"
      for i in "${ADDR[@]}"; do
    echo $i
          FILTER="$FILTER --filter $i"
      done
  fi

  docker system prune --all --force --filter "until=${DOCKER_PRUNE_UNTIL}" $FILTER

  if ! /usr/sbin/bk-check-disk-space.sh ; then
    echo "Disk health checks failed" >&2
    exit 1
  fi
fi