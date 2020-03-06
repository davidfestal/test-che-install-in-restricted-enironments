#!/bin/bash
#
# Copyright (c) 2019 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation

CURRENT_DIR=$(pwd)
BASE_DIR=$(cd "$(dirname "$0")"; pwd)
CSV=$1

mkdir -p ${BASE_DIR}/generated

echo "Getting the list of images from the CSV"

IMAGE_LIST=$(yq -r '.spec.install.spec.deployments[].spec.template.spec.containers[].env[] | select(.name | test("IMAGE_default_.*"; "g")) | .value' "${CSV}")
OPERATOR_IMAGE=$(yq -r '.spec.install.spec.deployments[].spec.template.spec.containers[].image' "${CSV}")

REGISTRY_LIST=$(yq -r '.spec.install.spec.deployments[].spec.template.spec.containers[].env[] | select(.name | test("IMAGE_default_.*_registry"; "g")) | .value' "${CSV}")
for registry in ${REGISTRY_LIST}
do
  extracted=$(${BASE_DIR}/dockerContainerExtract.sh ${registry} | tail -n 1)
  echo "extracting the docker images from registry: ${registry}"
  case ${registry} in
    *devfile*)
      DEVFILE_REGISTRY_IMAGES=$(cat ${extracted}/var/www/html/devfiles/external_images.txt) ;;
    *plugin*)
      PLUGIN_REGISTRY_IMAGES=$(cat ${extracted}/var/www/html/v3/external_images.txt) ;;
      
  esac    
  rm -Rf extracted
done

rm -Rf ${BASE_DIR}/generated/digests-mapping.txt 
touch ${BASE_DIR}/generated/digests-mapping.txt
for image in ${OPERATOR_IMAGE} ${IMAGE_LIST} ${DEVFILE_REGISTRY_IMAGES} ${PLUGIN_REGISTRY_IMAGES}
do
  case ${image} in
    *@sha256:*)
      withDigest="${image}";;
    *@)
      continue;;
    *)
      echo "Getting digest for image: ${image}"
      digest="$(skopeo inspect docker://${image} | jq -r '.Digest')"
      withoutTag="$(echo "${image}" | sed -e 's/^\(.*\):[^:]*$/\1/')"
      withDigest="${withoutTag}@${digest}";;
  esac
  dots="${withDigest//[^\.]}"
  separators="${withDigest//[^\/]}"
  if [ "${#separators}" == "1" ] && [ "${#dots}" == "0" ]; then
    echo "Adding the default 'docker.io/' prefix to produce canonical name for image: $image"
    withDigest="docker.io/${withDigest}"
  fi

  echo "${image}=${withDigest}" >> ${BASE_DIR}/generated/digests-mapping.txt
done
