## Manual Test procedure for the Che installation on OpenShift 4.3 clusters in restricted environments

### Introduction

This procedure provides steps to easily test the compatibility of Che/CRW Operator
with the OpenShift 4.3 documentation about installation in restricted environments.

Source documentation used to build this procedure can be found at the following links:
- [About using digests and adding `relatedImage` field in CSV manifests](https://docs.openshift.com/container-platform/4.3/operators/operator_sdk/osdk-generating-csvs.html#olm-enabling-operator-for-restricted-network_osdk-generating-csvs)
- [About preparing the mirror docker registry](https://docs.openshift.com/container-platform/4.3/installing/install_config/installing-restricted-networks-preparations.html#installation-about-mirror-registry_installing-restricted-networks-preparations) 
- [About building the local catalog, mirroring images, and setting up the content source policy insid ethe cluster](https://docs.openshift.com/container-platform/4.3/operators/olm-restricted-networks.html#olm-understanding-operator-catalog-images_olm-restricted-networks)
- [More information about OpenShift 4.3 image registry repository mirroring](https://docs.openshift.com/container-platform/4.3/openshift_images/image-configuration.html#images-configuration-registry-mirror_image-configuration) 

### Specifics of this procedure

- This can be applied on **any OpenShift 4.3 cluster having at least 2 master nodes** (=> **not** CRC),
even if the cluster is not really disconnected
- The main goal is to check that, finally, all the CHE-relate docker images are **pulled from the mirror docker registry** instead of the initial external registry (quay.io, docker.io, ...)
- To make installation easier, the mirror docker registry is **deployed inside the cluster and made available through a route**. This allows the mirror docker registry being reachable even from a cluster that cannot reach any local machine.
This differs from the official documentation which requires installing the mirror docker registry on a bastion host that is both connected to the internet and reachable by the cluster. However this difference doesn't impact the tests we're doing here.
- Another difference is that the mirror docker registry deployed here **doesn't have any authentication** to make pulls from the cluster easy, without having to add credentials in the cluster. In real-life scenarios it would have some authentication. However this also doesn't impact the meaningfullness of these tests.

### Steps to apply


##### Prepare the package with digests and relatedImages

- Download the last 4.3.1 oc command line tool from https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-4.3/

- Replace tags with digests in the CSV by using:

```bash
skopeo inspect docker://quay.io/eclipse/che-operator:7.9.0 | jq '.Digest'
etc ...
```

- Add `relatedImages` fields in the CSV:

```bash
skopeo inspect docker://quay.io/eclipse/che-plugin-registry:7.9.0 | jq '.Digest'
etc ...
```

- This will mainly produce content similar to what is already prepared in the [`eclipse-che-preview-openshift/deploy/olm-catalog/eclipse-che-preview-openshift` folder](./eclipse-che-preview-openshift/deploy/olm-catalog/eclipse-che-preview-openshift) of this GitHub repository.

##### Push the OLM package to a Quay.io application

- Setup your `AUTH_TOKEN` to Connect to Quay (after providing your `quay.io` user name and password as environment variables).

```bash
AUTH_TOKEN=$(curl -sH "Content-Type: application/json" -XPOST https://quay.io/cnr/api/v1/users/login -d '                                     
{                  
    "user": {
        "username": "'"${QUAY_USERNAME}"'",
        "password": "'"${QUAY_PASSWORD}"'"
    }
}' | jq -r '.token')
```

- Define your Quay organization you want to push the OLM package to as a Quay application (change `dfestal-tests` to the chosen organization):

```bash
export MY_QUAY_ORG=dfestal-tests
```

- Push the catalog to your Quay application:

```bash
operator-courier push eclipse-che-preview-openshift/deploy/olm-catalog/eclipse-che-preview-openshift ${MY_QUAY_ORG} eclipse-che-preview-openshift 9.9.$(date +%s) "$AUTH_TOKEN"
```

##### Deploy the mirror docker registry on the cluster

- Start a cluster on cluster bot for example, download the provided kubeconfig as the `.kubeconfig` file

```bash
export KUBECONFIG=.kubeconfig
```

- Deploy the docker v2 mirror registry to the new cluster. It will create the registry in the fixed `mirror-docker-registry` namespace

```bash
./deploy-registry.sh
export REGISTRY_HOST="route-mirror-docker-registry.$(oc get ingresses.config.openshift.io cluster -o=jsonpath='{ .spec.domain }')"
```

- Add the certificates of the mirror docker registry to the trusted certificates of the local machine (warning: instructions for RHEL / Centos here)
 
```bash
sudo cp mirror-docker-registry-ca.crt /etc/pki/ca-trust/source/anchors
sudo update-ca-trust
```

- Restart the docker deamon and test the login to the new mirror registry (any user / password is OK, since the registry has not authentication)

```bash
sudo systemctl restart docker.service
docker login $REGISTRY_HOST 
```

##### Mirror the OLM package Quay.io application to the cluster

- Disable the default OperatorSources in the Cluster. Nothing should appear in the OperatorHub catalog anymore:

```bash
oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'
```

- Build the local catalog from your Quay.io application and push it to the mirror docker registry:

```bash
oc adm catalog build --appregistry-endpoint https://quay.io/cnr --appregistry-org ${MY_QUAY_ORG} --to=${REGISTRY_HOST}/catalog/eclipse-che-preview-openshift:v1
```

- Mirror the docker images referenced by your local catalog to your mirror docker registry.

```bash
oc adm catalog mirror --manifests-only=true ${REGISTRY_HOST}/catalog/eclipse-che-preview-openshift:v1 ${REGISTRY_HOST}
oc image mirror --max-per-registry=1 --filename=eclipse-che-preview-openshift-manifests/mapping.txt
```

- Apply the `ImageContentSourcePolicy` generated in the `eclipse-che-preview-openshift-manifests` folder by the previous step:

```bash
oc apply -f ./eclipse-che-preview-openshift-manifests/
```

- Wait for the end of the configuration update and restart of all cluster nodes, until all 2 `MachineConfigPool`s (master and workers) are fully updated.

##### Install the local catalog source, subscribe and  test

- Deploy the local catalog matadata and operator group to prepare operator installation. This will create a fixed `test-restricted-che-install` namespace and propose the operator inside it
 
```bash
./deploy-catalog.sh
```

- Go into the `test-restricted-che-install` namespace

- In the OperatorHub, you shoud now see the Eclipse Che operator available for installation 

- Install it as usual.

- While it is installing, In the logs of the `mirror-docker-registry` POD (in the `mirror-docker-registry` namespace) you should already see that the Che operator image is automatically pulled from the internal registry.

- Add at least a real user besides `kubeadmin` (via adding a `htpasswd` identity provider and logging at least once as a regular user)

- Create `CheCluster` custom resource to start the installation

- In the logs of the `mirror-docker-registry` POD (in the `mirror-docker-registry` namespace), look how, during the installation, the Che images are automatically pulled from the internal registry.
