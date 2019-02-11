#!/bin/bash
set -e
set -x

buildkite-agent artifact download disk.raw.tar.gz .

gcloud auth activate-service-account --key-file=$GCLOUD_CREDENTIAL_FILE

buildkite-agent artifact download disk.raw.tar.gz .

gcloud auth activate-service-account --key-file=$GCLOUD_CREDENTIAL_FILE

BUCKET_PATH="${BUCKET}/${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BRANCH}-${BUILDKITE_COMMIT}.tar.gz"

gsutil cp disk.raw.tar.gz gs://$BUCKET_PATH
gcloud compute --project=$PROJECT \
    images create buildkite-agent-3-5-1-$BUILDKITE_BRANCH-$BUILDKITE_COMMIT \
    --family=alpine \
    --description="$BUILDKITE_BRANCH $BUILDKITE_COMMIT on $BUILDKITE_REPO ($BUILDKITE_BUILD_URL)" \
    --source-uri=https://storage.googleapis.com/$BUCKET_PATH

gsutil rm gs://$BUCKET_PATH