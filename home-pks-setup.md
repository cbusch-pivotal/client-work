# SETUP ENVIRONMENT

- [Jumpbox Setup](#jumpbox-setup)
    - [Update app manager](#update-app-manager)
    - [Install Docker](#install-docker)
    - [Install Brew and update PATH](#install-brew-and-update-path)
        - [Update brew and install packages](#update-brew-and-install-packages)
    - [Add lab configuration to minio](#add-lab-configuration-to-minio)
    - [Setup bosh-env](#setup-bosh-env)
- [Deploy Pivotal Platform](#deploy-pivotal-platform)
- [Setup Harbor](#setup-harbor)
    - [Setup for Docker](#setup-for-docker)
    - [Setup Harbor with images pulled to local](#setup-harbor-with-images-pulled-to-local)
- [Setup for PKS](#setup-for-pks)
    - [Download the PKS CLI](#download-the-pks-cli)
    - [Create a pksadmin user](#create-a-pksadmin-user)
    - [Log into PKS](#log-into-pks)
    - [Create a tools cluster](#create-a-tools-cluster)
    - [Check on the creation process](#check-on-the-creation-process)
    - [Create DNS record](#create-dns-record)
    - [Get cluster credentials](#get-cluster-credentials)
    - [Check kubectl access](#check-kubectl-access)
- [Setup for Concourse Helm Deploy](#setup-for-concourse-helm-deploy)
    - [Download and unpack the concourse helm deploy](#download-and-unpack-the-concourse-helm-deploy)
    - [Load images into jumpbox docker](#load-images-into-jumpbox-docker)
    - [Setup target registry](#setup-target-registry)
    - [Capture release numbers from image files](#capture-release-numbers-from-image-files)
    - [Tag images with registry and release numbers](#tag-images-with-registry-and-release-numbers)
    - [Push images to harbor](#push-images-to-harbor)
    - [Setup tools cluster for tiller](#setup-tools-cluster-for-tiller)
    - [Setup secret for registry](#setup-secret-for-registry)
    - [Use helm v2.14.3 in extracted concourse-5.5.7-helm.tgz](#use-helm-v2143-in-extracted-concourse-557-helmtgz)
    - [Produce the tiller.yml template to deploy tiller](#produce-the-tilleryml-template-to-deploy-tiller)
    - [Edit the new tiller.yml](#edit-the-new-tilleryml)
    - [Copy harbor certs to cluster workers](#copy-harbor-certs-to-cluster-workers)
    - [Create the tiller deployment](#create-the-tiller-deployment)
- [Create cluster for Concourse](#create-cluster-for-concourse)
    - [Create the cluster](#create-the-cluster)
    - [Get new credentials and set context for kubectl](#get-new-credentials-and-set-context-for-kubectl)
    - [Deploy tiller config, secret and storage class to new cluster](#deploy-tiller-config-secret-and-storage-class-to-new-cluster)
    - [Generate tiller-concourse.yml](#generate-tiller-concourseyml)
    - [Add `imagePullSecrets` as above](#add-imagepullsecrets-as-above)
    - [Deploy tiller](#deploy-tiller)
    - [Taint the nodes](#taint-the-nodes)
- [Deploy Concourse-helm](#deploy-concourse-helm)

---

## Jumpbox Setup

Deploy `ops-manager-xxx.ova` to vSphere environment.

### Update app manager

`sudo apt udpate`

### Install Docker

```bash
sudo apt install docker.io
sudo apt install docker-compose
sudo systemctl start docker
```

### Install Brew and update PATH

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install.sh)"

PATH='/home/linuxbrew/.linuxbrew/bin:$PATH'
```

#### Update brew and install packages

```bash
brew update
brew install go go-md2man
brew install minio/stable/mc
```

### Add lab configuration to minio

```bash
mc config host add lab http://<lab IP>:9000 RZ...GM ItnwG...0cWedvyTTw --api "s3v4"
```

### Setup bosh-env

`echo "eval \"$(om -e $HOME/envs/env.yml bosh-env)\"" > $HOME/bosh-env`

---

## Deploy Pivotal Platform

1. Deploy a second ops-manager for running PKS, Harbor, etc.
1. Configure BOSH Director for vSphere and Apply.
1. Import Harbor and configure
1. Import PKS and configure
1. Apply changes

---

## Setup Harbor

Work from jumpbox.

### Setup for Docker

Use harbor self-signed certs. Get harbor certs from:

```bash
om -e env.yml staged-config -c -p harbor-containter-registry > harbor.yml

LOCAL_CERTS=$HOME/certs/harbor.busch.local
mkdir -p $LOCAL_CERTS

# paste harbor.yml certificate
vi $LOCAL_CERTS/client.cert
# paste harbor.yml private
vi $LOCAL_CERTS/client.key
# paste harbor.yml ca
vi $LOCAL_CERTS/ca.crt
```

Create the certs:

```bash
DOCKER_CERTS=/etc/docker/certs.d/harbor.busch.local
mkdir -p $DOCKER_CERTS
sudo cp $LOCAL_CERTS/client.cert $DOCKER_CERTS
sudo cp $LOCAL_CERTS/client.key  $DOCKER_CERTS
sudo cp $LOCAL_CERTS/ca.crt      $DOCKER_CERTS
```

### Setup Harbor with images pulled to local

```bash
docker login -u admin harbor.busch.local

# import images to local Docker
docker pull busybox:latest
docker pull alpine:latest
docker pull nginx:latest
# download from Pivotal Platform Automation first
docker import platform-automation-image-4.3.2.tgz platform-automation:4.3.2

# tag images for Harbor
docker tag platform-automation:4.3.2 harbor.busch.local/library/platform-automation:4.3.2
docker tag nginx:latest harbor.busch.local/library/nginx:latest
docker tag alpine:latest harbor.busch.local/library/alpine:latest
docker tag busybox:latest harbor.busch.local/library/busybox:latest

# push images to Harbor
docker push harbor.busch.local/library/platform-automation:4.3.2
docker push harbor.busch.local/library/nginx:latest
docker push harbor.busch.local/library/busybox:latest
docker push harbor.busch.local/library/alpine:latest
```

---

## Setup for PKS

### Download the PKS CLI

```bash
pivnet download-product-files -p pivotal-container-service -r 1.6.1 -g pks-linux-amd64-*
chmod +x pks-linux-amd64-1.6.1-build.20
sudo mv pks-linux-amd64-1.6.1-build.20 /usr/local/bin/pks
```

### Create a pksadmin user

```bash
# use pivotal platform root ca from opsman
uaac target https://api.pks.busch.local:8443 --ca-cert certs/pivotal-root-ca.cer
uaac token client get admin -s <secret from Pks Uaa Management Admin Client>
uaac user add pksadmin --emails pksadmin@busch.local -p boomer1962
uaac member add pks.clusters.admin pksadmin
uaac member add pks.clusters.manage pksadmin
```

### Log into PKS

```bash
pks login -a api.pks.busch.local -u pksadmin --ca-cert $HOME/certs/pivotal-root-ca.cer

Password: **********
API Endpoint: api.pks.busch.local
User: pksadmin
Login successful.
```

### Create a tools cluster

```bash
pks create-cluster tools --external-hostname tools.pks.busch.local --plan small
```

### Check on the creation process

```bash
watch pks cluster tools
```

### Create DNS record

Once the master is created and assigned an IP, create an A Record to `tools.pks.busch.local=10.0.1.x`

### Get cluster credentials

When cluster is created, use below to access the cluster

```bash
pks get-credentials tools
pks clusters

# check the .kubectl config for cluster context
cat $HOME/.kube/config | less
```

### Check kubectl access

```bash
# kubectl config use-context <cluster-name>
kubectl config use-context tools
```

---

## Setup for Concourse Helm Deploy

### Download and unpack the concourse helm deploy

```bash
# get this from network.pivotal.io -> concourse helm download
pivnet download-product-files --product-slug='p-concourse' --release-version='5.5.7 Helm Deployment' --product-file-id=562058
mkdir concourse-helm
tar xf concourse-5.5.7-helm.tgz -C concourse-helm/
cd concourse-helm/
```

### Load images into jumpbox docker

```bash
docker load -i ./images/concourse.tar
docker load -i ./images/postgres.tar
docker load -i ./images/helm.tar
docker images
```

### Setup target registry

```bash
export INTERNAL_REGISTRY=harbor.busch.local
export PROJECT=concourse
```

### Capture release numbers from image files

```bash
cat ./images/concourse.tar.name | cut -d ':' -f 2
5.5.7-ubuntu
cat ./images/helm.tar.name | cut -d ':' -f 2
2.14.3
cat ./images/postgres.tar.name | cut -d ':' -f 2
0.0.1
```

### Tag images with registry and release numbers

```bash
docker tag concourse/concourse:5.5.7-ubuntu $INTERNAL_REGISTRY/$PROJECT/concourse:5.5.7-ubuntu
docker tag concourse/helm:2.14.3 $INTERNAL_REGISTRY/$PROJECT/helm:2.14.3
docker tag concourse/postgres:0.0.1 $INTERNAL_REGISTRY/$PROJECT/postgres:0.0.1
docker images
```

### Push images to harbor

NOTE: create the "concourse" project first

```bash
docker push $INTERNAL_REGISTRY/$PROJECT/concourse:5.5.7-ubuntu
docker push $INTERNAL_REGISTRY/$PROJECT/helm:2.14.3
docker push $INTERNAL_REGISTRY/$PROJECT/postgres:0.0.1
```

### Setup tools cluster for tiller

```yaml
cat > tiller-config.yml << EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
imagePullSecrets:
  - name: "regcred"
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
EOF
```

```bash
kubectl create -f tiller-config.yml
serviceaccount/tiller created
clusterrolebinding.rbac.authorization.k8s.io/tiller created
```

```yaml
cat > storage-class.yml << EOF
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: concourse-storage-class
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/vsphere-volume
parameters:
  datastore: datastore1
EOF
```

```bash
$ kubectl create -f storage-class.yml
storageclass.storage.k8s.io/concourse-storage-class created
```

### Setup secret for registry

```bash
kubectl create secret docker-registry regcred \
        --docker-server=$INTERNAL_REGISTRY \
        --docker-username=admin \
        --docker-password=<password> \
        --namespace=kube-system
secret/regcred created
```

### Use helm v2.14.3 in extracted concourse-5.5.7-helm.tgz

```bash
# while in the concourse-helm directory
sudo cp ./helm-cli/linux/helm /usr/local/bin
```

### Produce the tiller.yml template to deploy tiller

```bash
helm init --tiller-image $INTERNAL_REGISTRY/$PROJECT/helm:2.14.3 --service-account tiller --dry-run --debug > tiller.yml
```

### Edit the new tiller.yml

Add the following at spec.template.spec, above `automountServiceAccountToken: true`:

```yaml
vi tiller.yml
---
spec:
  ...
  template:
    ...
    spec:
      imagePullSecrets:
        - name: "regcred"
```

### Copy harbor certs to cluster workers

BEFORE the cluster workers can access Harbor with a self-signed certificate, all three certs created earlier for Docker, `ca.crt`, `client.cert`, and `client.key`, must be copied to all workers in the cluster in a new directory "/etc/docker/certs.d/harbor.busch.local/". Remember to `sudo su -`, first.

### Create the tiller deployment

```bash
kubectl apply -f tiller.yml

# once deployed, test it
helm version
Client: &version.Version{SemVer:"v2.14.3", GitCommit:"0e7f3b6637f7af8fcfddb3d2941fcc7cbebb0085", GitTreeState:"clean"}
Server: &version.Version{SemVer:"v2.14.3", GitCommit:"0e7f3b6637f7af8fcfddb3d2941fcc7cbebb0085", GitTreeState:"clean"}
```

---

## Create cluster for Concourse

### Create the cluster

```bash
$ pks create-cluster concourse --external-hostname concourse.pks.busch.local --plan small

PKS Version:              1.6.1-build.6
Name:                     concourse
K8s Version:              1.15.5
Plan Name:                small
UUID:                     4e068f35-dbec-4f92-a98f-1e7ee47e341c
Last Action:              CREATE
Last Action State:        in progress
Last Action Description:  Creating cluster
Kubernetes Master Host:   concourse.pks.busch.local
Kubernetes Master Port:   8443
Worker Nodes:             3
Kubernetes Master IP(s):  In Progress
Network Profile Name:

Use 'pks cluster concourse' to monitor the state of your cluster
```

### Get new credentials and set context for kubectl

```bash
$ pks get-credentials concourse
```

### Deploy tiller config, secret and storage class to new cluster

```bash
cd concourse-helm/

# create storage class and rbac as done above in kube-system
kubectl create -f storage-class.yml
kubectl create -f tiller-config.yml

# create regcred secret
$ kubectl create secret docker-registry regcred \
          --docker-server=$INTERNAL_REGISTRY \
          --docker-username=admin \
          --docker-password=boomer1962 \
          --namespace=kube-system
```

### Generate tiller-concourse.yml

```bash
helm init --tiller-image $INTERNAL_REGISTRY/$PROJECT/helm:2.14.3 --service-account tiller --dry-run --debug > tiller-concourse.yml
```

### Add `imagePullSecrets` as above

```yaml
$ vi tiller-concourse.yml
---
spec:
  ...
  template:
  ...
    spec:
      imagePullSecrets:
        - name: "regcred"
```

### Deploy tiller

```bash
kubectl apply -f tiller-concourse.yml

### Check status
kubectl get deployments.extensions,svc -n kube-system | grep -i tiller

# once deployed, test connectivity
helm version
Client: &version.Version{SemVer:"v2.14.3", GitCommit:"0e7f3b6637f7af8fcfddb3d2941fcc7cbebb0085", GitTreeState:"clean"}
Server: &version.Version{SemVer:"v2.14.3", GitCommit:"0e7f3b6637f7af8fcfddb3d2941fcc7cbebb0085", GitTreeState:"clean"}
```

### Taint the nodes

Taint the nodes so that pod tolerations put containers on separate nodes

```bash
kubectl taint node a0649a37-da72-4290-af3a-4c5756395159 clusternode=worker:NoSchedule
node/a0649a37-da72-4290-af3a-4c5756395159 tainted

kubectl taint node 79e2a6a7-557b-4ab8-8f28-fee086a530ce clusternode=worker:NoSchedule
node/79e2a6a7-557b-4ab8-8f28-fee086a530ce tainted

kubectl taint node 0b5c3a6a-393f-4c89-bbe3-93472f4ef75f clusternode=web:NoSchedule
node/0b5c3a6a-393f-4c89-bbe3-93472f4ef75f tainted
```

---

## Deploy Concourse-helm

# tolerate the web node
  tolerations:
  - key: "clusternode"
    operator: "Equal"
    value: "web"
    effect: "NoSchedule"

# tolerate the worker node
  tolerations:
  - key: "clusternode"
    operator: "Equal"
    value: "worker"
    effect: "NoSchedule"

# BEFORE the workers/master can access Harbor, all three certs created earlier for Docker,
#  "ca.crt", "client.cert", and "client.key", must be put on all masters and workers in the cluster
#  in the new directory "/etc/docker/certs.d/harbor.busch.local/" as "sudo su -".

sudo su -
mkdir .ssh
vi .ssh/cbusch
# paste cbusch private key or whatever used for VM's
chmod 600 .ssh/cbusch
mkdir -p /etc/docker/certs.d/harbor.busch.local
cd /etc/docker/certs.d/harbor.busch.local
scp -i $HOME/.ssh/cbusch ubuntu@jumpbox.busch.local:./certs/harbor.busch.local/* .


