## Manual Test procedure for the Che installation on OpenShift 4.3 clusters in restricted environments

- Download the last 4.3.1 oc command line tool from https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-4.3/

- Replace tags with digests in the CSV by using:

```
skopeo inspect docker://quay.io/eclipse/che-operator:7.9.0 | jq '.Digest'
etc ...
```

- Add `relatedImages` fields in the CSV:

```
skopeo inspect docker://quay.io/eclipse/che-plugin-registry:7.9.0 | jq '.Digest'
etc ...
```

- Setup the `AUTH_TOKEN` to Connect to Quay

```
AUTH_TOKEN=$(curl -sH "Content-Type: application/json" -XPOST https://quay.io/cnr/api/v1/users/login -d '                                     
{                  
    "user": {
        "username": "'"${QUAY_USERNAME}"'",
        "password": "'"${QUAY_PASSWORD}"'"
    }
}' | jq -r '.token')
```

- Define your Quay organization you want to push the OLM package to as a Quay application:

export MY_QUAY_ORG=dfestal-tests

- Push the catalog to your Quay application:

```
operator-courier push eclipse-che-preview-openshift/deploy/olm-catalog/eclipse-che-preview-openshift ${MY_QUAY_ORG} eclipse-che-preview-openshift 9.9.$(date +%s) "$AUTH_TOKEN"
```

- Start a cluster on cluster bot for example, download the provided kubeconfig as the `.kubeconfig` file

```
export KUBECONFIG=.kubeconfig
```

- Deploy the deocker v2 mirror registry to the new cluster

```
./deploy-registry.sh
export REGISTRY_HOST="route-mirror-docker-registry.$(oc get ingresses.config.openshift.io cluster -o=jsonpath='{ .spec.domain }')"
```

- Add the certificates of the mirror docker registry to the local trusted certificates (warning: instructions for RHEL / Centos here)
 
```
sudo cp mirror-docker-registry-ca.crt /etc/pki/ca-trust/source/anchors
sudo update-ca-trust
```

- Restart the docker deamon and test the login to the new mirror registry

```
sudo systemctl restart docker.service
docker login $REGISTRY_HOST 
```

- Disable the default OperatorSources by adding disableAllDefaultSources:

```
oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'
```

- Build the local catalog from teh Quay.io application and push it to the mirror docker registry

```
oc adm catalog build --appregistry-endpoint https://quay.io/cnr --appregistry-org ${MY_QUAY_ORG} --to=${REGISTRY_HOST}/catalog/eclipse-che-preview-openshift:v1
```

- Mirror the docker images referenced by your local catalog to your mirror docker registry.

```
oc adm catalog mirror --manifests-only=true ${REGISTRY_HOST}/catalog/eclipse-che-preview-openshift:v1 ${REGISTRY_HOST}
oc image mirror --max-per-registry=1 --filename=eclipse-che-preview-openshift-manifests/mapping.txt
```

- Apply the ImageContentSourcePolicy generated in the `eclipse-che-preview-openshift-manifests` folder by the previous step 

```
oc apply -f ./eclipse-che-preview-openshift-manifests/
```

- Wait for the end of the configuration update of all nodes, until all 2 MachineConfigPools (master and workers) are fully updated

- Deploy the local catalog and operator group to prepare operator installation
 
```
./deploy-catalog.sh
```

- Add at least a real user besides kubeadmin (via adding a htpasswd identity provider and logging at least once as a regular user)

- Go into the `test-restricted-che-install` namespace
- Create CheCluster custom resource to start the installation
- In the logs of the `mirror-docker-registry` POD (in the `mirror-docker-registry` namespace), hook how, during the installation, the Che images are automatically pulled from the internal registry.

