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
REGISTRY_HOST=route-mirror-docker-registry.${DOMAIN}
CHE_NAMESPACE="test-restricted-che-install"
oc new-project "test-restricted-che-install"
oc process -f ${BASE_DIR}/catalog.yaml -p=REGISTRY_HOST=${REGISTRY_HOST} -p=CHE_NAMESPACE=${CHE_NAMESPACE} | oc create -f -
