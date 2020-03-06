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

mkdir -p ${BASE_DIR}/generated
rm -Rf ${BASE_DIR}/generated/eclipse-che-preview-openshift/
cp -R ${BASE_DIR}/eclipse-che-preview-openshift/deploy/olm-catalog/eclipse-che-preview-openshift ${BASE_DIR}/generated

${BASE_DIR}/buildDigestMap.sh ${BASE_DIR}/generated/eclipse-che-preview-openshift/7.9.0/eclipse-che-preview-openshift.v7.9.0.clusterserviceversion.yaml

names=" "
count=1
RELATED_IMAGES='. * { spec : { relatedImages: [ '
for mapping in $(cat ${BASE_DIR}/generated/digests-mapping.txt)
do
  source=$(echo "${mapping}" | sed -e 's/\(.*\)=.*/\1/')
  dest=$(echo "${mapping}" | sed -e 's/.*=\(.*\)/\1/')
  sed -i -e "s;${source};${dest};" ${BASE_DIR}/generated/eclipse-che-preview-openshift/7.9.0/eclipse-che-preview-openshift.v7.9.0.clusterserviceversion.yaml
  name=$(echo "${dest}" | sed -e 's;.*/\([^\/][^\/]*\)@.*;\1;')
  nameWithSpaces=" ${name} "
  if [[ "${names}" == *${nameWithSpaces}* ]]; then
    name="${name}-${count}"
    count=$(($count+1))
  fi
  if [ "${names}" != " " ]; then
    RELATED_IMAGES="${RELATED_IMAGES},"
  fi
  RELATED_IMAGES="${RELATED_IMAGES} { name: \"${name}\", image: \"${dest}\"}"
  names="${names} ${name} "
done
RELATED_IMAGES="${RELATED_IMAGES} ] } }"
yq -y "$RELATED_IMAGES" generated/eclipse-che-preview-openshift/7.9.0/eclipse-che-preview-openshift.v7.9.0.clusterserviceversion.yaml > generated/eclipse-che-preview-openshift/7.9.0/eclipse-che-preview-openshift.v7.9.0.clusterserviceversion.yaml.new
mv generated/eclipse-che-preview-openshift/7.9.0/eclipse-che-preview-openshift.v7.9.0.clusterserviceversion.yaml generated/eclipse-che-preview-openshift/7.9.0/eclipse-che-preview-openshift.v7.9.0.clusterserviceversion.yaml.old
mv generated/eclipse-che-preview-openshift/7.9.0/eclipse-che-preview-openshift.v7.9.0.clusterserviceversion.yaml.new generated/eclipse-che-preview-openshift/7.9.0/eclipse-che-preview-openshift.v7.9.0.clusterserviceversion.yaml
rm generated/eclipse-che-preview-openshift/7.9.0/eclipse-che-preview-openshift.v7.9.0.clusterserviceversion.yaml.old