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

oc get secret/router-ca -n openshift-ingress-operator -o=jsonpath='{ .data.tls\.crt }' | base64 -d > "${CURRENT_DIR}/mirror-docker-registry-ca.crt"
DOMAIN="$(oc get ingresses.config.openshift.io cluster -o=jsonpath='{ .spec.domain }')"
oc new-project mirror-docker-registry
REGISTRY_HOST=route-mirror-docker-registry.${DOMAIN}
oc process -f ${BASE_DIR}/mirror-registry.yaml -p=REGISTRY_HOST=${REGISTRY_HOST} | oc create -f -
oc create configmap registry-cas -n openshift-config --from-file=${REGISTRY_HOST}=${CURRENT_DIR}/mirror-docker-registry-ca.crt
oc patch image.config.openshift.io/cluster --patch '{"spec":{"additionalTrustedCA":{"name":"registry-cas"}}}' --type=merge

echo "REGISTRY_HOST=${REGISTRY_HOST}"
