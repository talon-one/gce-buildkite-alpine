#!/bin/bash
set -e
set -x

buildkite-agent artifact download disk.raw.tar.gz .

gcloud auth activate-service-account --key-file=$GCLOUD_CREDENTIAL_FILE

BUCKET_PATH="${BUCKET}/${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BRANCH}${BUILDKITE_BUILD_ID}.tar.gz"

gsutil cp disk.raw.tar.gz gs://$BUCKET_PATH
gcloud compute --project={$PROJECT} \
    images create buildkite-agent-3-5-1-$(date +"%F-%H-%m-%S") \
    --family=alpine \
    --source-uri=https://storage.googleapis.com/$BUCKET_PATH

gsutil rm gs://$BUCKET_PATH