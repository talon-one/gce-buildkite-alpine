#!/bin/bash
set -e

INSTANCE_GROUP=$(buildkite-agent meta-data get instance-group)
ZONE=$(buildkite-agent meta-data get zone)

buildkite-agent artifact download disk.raw.tar.gz .

gcloud auth activate-service-account --key-file=$GCLOUD_CREDENTIAL_FILE

buildkite-agent artifact download disk.raw.tar.gz .

gcloud auth activate-service-account --key-file=$GCLOUD_CREDENTIAL_FILE

COMMIT=${BUILDKITE_COMMIT:0:7}

BUCKET_PATH="${BUCKET}/${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BRANCH}-${COMMIT}.tar.gz"

gsutil cp disk.raw.tar.gz gs://$BUCKET_PATH

set +e
gcloud compute --quiet --project=$PROJECT images delete buildkite-agent
set -e

gcloud compute --project=$PROJECT \
    images create buildkite-agent \
    --family=alpine \
    --description="$BUILDKITE_BRANCH $BUILDKITE_COMMIT on $BUILDKITE_REPO ($BUILDKITE_BUILD_URL)\nTo revert an image: delete buildkite-agent image and duplicate an old image using gcloud compute --project=XXX images create buildkite-agent --source-image=buildkite-agent-XXX" \
    --source-uri=https://storage.googleapis.com/$BUCKET_PATH

gsutil rm gs://$BUCKET_PATH



gcloud beta compute --quiet --project=$PROJECT instance-groups managed rolling-action replace $INSTANCE_GROUP --max-surge=20% --max-unavailable=20% --min-ready=60s --zone=$ZONE