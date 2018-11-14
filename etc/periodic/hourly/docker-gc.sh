#!/bin/bash
set -euo pipefail

docker-purge --force --all --containers '.Created+60*60<now'

filter=$(cat <<EOF
.Created+60*60<now
and (
        (
                (.RepoTags | contains(["clkao/postgres"]))
            or
                (.RepoTags | contains(["talon-one/docker-go-node"]))
            or
                (.RepoTags | contains(["alpine:latest"]))
            or
                (.RepoTags | contains(["selenium/standalone-firefox"]))
            or
                (.RepoTags | contains(["selenium/standalone-chrome"]))
            or
                (.RepoDigests | contains(["eu.gcr.io/talon-farm2/talon-one/e2e-runner"]))
        ) | not
    )
EOF
)

docker-purge --force --all --images "$filter"

docker-purge --force --all --networks '.Created+60*60<now'

logger -t docker-gc Cleaned Containers, Images and Networks