#!/bin/bash
set -euo pipefail

docker-purge --containers '.Created+60*60<now'

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

docker-purge --images $filter