#!/bin/bash
set -e

if [[ ! $1 ]]; then
  echo "Usage: $0 CONTAINER"
  echo "Usage: $0 quay.io/crw/operator-metadata:latest"
  exit
fi

PODMAN=docker # or user docker

container="$1"
tmpcontainer="$(echo $container | tr "/:" "--")-$(date +%s)"
unpackdir="/tmp/${tmpcontainer}"

# get remote image
${PODMAN} pull $container

# create local container
${PODMAN} rm -f "${tmpcontainer}" 2> /dev/null || true
# use sh for regular containers or ls for scratch containers
${PODMAN} create --name="${tmpcontainer}" $container sh || ${PODMAN} create --name="${tmpcontainer}" $container ls

# export and unpack
${PODMAN} export "${tmpcontainer}" > /tmp/${tmpcontainer}.tar
rm -fr "$unpackdir"; mkdir -p "$unpackdir"
tar xf /tmp/${tmpcontainer}.tar -C "$unpackdir"

# cleanup
${PODMAN} rm -f "${tmpcontainer}"
rm -fr  /tmp/${tmpcontainer}.tar

echo "$unpackdir"