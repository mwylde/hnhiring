#!/bin/bash
set -e

if [ -n "$(git status --porcelain)" ]; then
  echo "Working directory is not clean... exiting"
  exit 1
fi

docker build . -t gcr.io/micahw-com/hnhiring_get_data:$(git rev-parse HEAD)
docker push gcr.io/micahw-com/hnhiring_get_data:$(git rev-parse HEAD)
