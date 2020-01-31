#!/bin/bash
set -e
set -x

buildkite-agent artifact download disk.raw.tar.gz .

gcloud auth activate-service-account --key-file=$GCLOUD_CREDENTIAL_FILE

COMMIT=${BUILDKITE_COMMIT:0:7}

BUCKET_PATH="${BUCKET}/${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BRANCH}-${COMMIT}.tar.gz"

gsutil cp disk.raw.tar.gz gs://$BUCKET_PATH
gcloud compute --project=$PROJECT \
    images create buildkite-agent-3-19-0-${BUILDKITE_BRANCH}-${COMMIT} \
    --family=alpine \
    --description="$BUILDKITE_BRANCH $BUILDKITE_COMMIT on $BUILDKITE_REPO ($BUILDKITE_BUILD_URL)" \
    --source-uri=gs://$BUCKET_PATH

gsutil rm gs://$BUCKET_PATH