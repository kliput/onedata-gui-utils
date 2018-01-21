#!/bin/bash

IMG_NAME=$1
IMG_VERSION=$2
NEW_VERSION=$3

docker pull docker.onedata.org/${IMG_NAME}:${IMG_VERSION}
docker tag docker.onedata.org/${IMG_NAME}:${IMG_VERSION} docker.onedata.org/${IMG_NAME}:${NEW_VERSION}
docker tag docker.onedata.org/${IMG_NAME}:${IMG_VERSION} onedata/${IMG_NAME}:${NEW_VERSION}
docker push docker.onedata.org/${IMG_NAME}:${NEW_VERSION}
docker push onedata/${IMG_NAME}:${NEW_VERSION}
