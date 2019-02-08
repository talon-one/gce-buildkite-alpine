#!/bin/bash
set -e

BUCKET_PATH="${BUCKET}/${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BRANCH}${BUILDKITE_BUILD_ID}.tar.gz"

gsutil cp disk.raw.tar.gz gs://$BUCKET_PATH
gcloud compute --project={$PROJECT} \
    images delete buildkite-3.5.1

gcloud compute --project={$PROJECT} \
    images create buildkite-3.5.1 \
    --family=alpine \
    --source-uri=https://$BUCKET_PATH