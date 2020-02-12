# Pivotal Helpers

**Table of Contents**

- [AWS WorkSpaces](#aws-workspaces)
    - [WorkSpace Tools](#workspace-tools)
- [Jumpbox](#jumpbox)
    - [Jumpbox Tools](#jumpbox-tools)
        - [Included io Ops Manager AMI](#included-io-ops-manager-ami)
        - [Additional Tools](#additional-tools)
    - [Using the Jumpbox](#using-the-jumpbox)
    - [Jumpbox Updates](#jumpbox-updates)
        - [Docker Installation](#docker-installation)
        - [EBS Resizing of the Jumpbox](#ebs-resizing-of-the-jumpbox)
            - [Increase EBS Volume](#increase-ebs-volume)
            - [Decrease EBS Volume](#decrease-ebs-volume)
    - [AWS CodeCommit](#aws-codecommit)
    - [BitBucket](#bitbucket)
    - [Control Plane](#control-plane)
        - [Operations Manager](#operations-manager)
    - [DEV](#dev)
        - [Apps Manager](#apps-manager)
    - [Sandbox](#sandbox)
        - [Apps Manager](#apps-manager-1)
- [Concourse](#concourse)
- [Credhub](#credhub)
- [Harbor](#harbor)
    - [Using a Self-Signed Certificate](#using-a-self-signed-certificate)
        - [CERTIFICATE](#certificate)
        - [PRIVATE_KEY](#private_key)
        - [CA-CERT](#ca-cert)
    - [Importing Images](#importing-images)
        - [Import some images](#import-some-images)
        - [Tag to import in Harbor](#tag-to-import-in-harbor)
        - [Log into Harbor](#log-into-harbor)
        - [Push to Harbor](#push-to-harbor)
- [PKS API Server](#pks-api-server)
    - [Target uaa to create a user account](#target-uaa-to-create-a-user-account)
    - [Create the uaa user](#create-the-uaa-user)
    - [Add user to appropriate uaa scopes](#add-user-to-appropriate-uaa-scopes)
    - [Create the cluster](#create-the-cluster)
    - [BOSH completion](#bosh-completion)
    - [Setup the ALB Ingress Controller](#setup-the-alb-ingress-controller)
- [CERTIFICATES AND DOMAINS](#certificates-and-domains)
    - [CONTROL PLANE](#control-plane)
    - [DEV](#dev-1)
    - [SANDBOX](#sandbox)
    - [OTHER ENVs](#other-envs)
- [Tips and Tricks](#tips-and-tricks)
    - [Add CA-CERT to VM](#add-ca-cert-to-vm)
    - [Change OM IP to DNS](#change-om-ip-to-dns)
- [Certificates for local Workspace Image](#certificates-for-local-workspace-image)
- [Cleaning up the domain change in PAS](#cleaning-up-the-domain-change-in-pas)
- [Setting up service key policies for AWS Service Broker Tile](#setting-up-service-key-policies-for-aws-service-broker-tile)

---

## AWS WorkSpaces

Primary access into the AWS Cloud environment. Once here all other work will be done with the provide jumpbox.

### WorkSpace Tools

- S3Brower for Windows
- Putty Portable for Windows
- Git Portable for Windows (GitBash)
- WinSCP
- Visual Studio Code for Windows

---

## Jumpbox

Connect to the jumpbox from your AWS WorkSpaces image to perform work on the Control Plane or Pivotal Platforms.

### Jumpbox Tools

Uses the Operations Manager AMI as the root image.

#### Included io Ops Manager AMI

- bbr v1.5.1
- jq v1.6
- bosh-cli v5.5.1
- uaac v4.0.0
- pks-cli v1.5.1
- pivnet v1.0.0
- credhub

#### Additional Tools

- terraform v0.11.14
- om v4.2.0+
- fly v4.2.4
- cf v6.46.0
- docker v19.03.4
- cf-mgmt and cf-mgmt-config v1.0.33
- aws-cli v1.16.198
- sshpass (not installed?)
- helm (not installed?)
- tiller (not installed?)
- kubectl v1.14.6
- kubeadmin (not installed?)
- tree v1.7.0
- sshpass 

### Using the Jumpbox

Use the Amazon WorkSpaces with **Putty** and **SSH** with *GitBash* shell. Either Putty or Git will both need installed.

Download the SSH key's for the jumpbox from the AWS `pivotal-credentials` bucket. 
- `PCF_Jumpbox.ppk`
- `jumpbox.pem`

The `jumpbox.ppk` SSH Key is necessary for auth in Putty or the `jumpbox.pem` for use with SSH, i.e. `ssh -i jumpbox.pem ubuntu@10.125.0.29`.

Once on the jumpbox, source the following files to get to the BOSH Director needed.

Control Plane BOSH Director, run the following:

```bash
$ source ./bosh-env-cp
$ bosh login
$ bosh deployments --column=name
$ bosh vms
```

...which contains

```bash
eval "$(om -e ~/env/controlplane/env.yml bosh-env -i ~/certs/controlplane-opsman-ssh.pem)"
```

DEV Foundation BOSH Director, run the following:

```bash
$ source ./bosh-env-dev
$ bosh login
```

...which contains

```bash
eval "$(om -e ~/env/dev/dev-ops.env bosh-env -i ~/certs/dev-opsman-ssh.pem)"
```

SANDBOX Foundation BOSH Director, run the following:

```bash
$ source ./bosh-env-sandbox
$ bosh login
```

...which contains

```bash
eval "$(om -e ~/env/sandbox/sandbox-ops.env bosh-env -i ~/certs/sandbox-opsman-dedicatedtenancy.pem)"
```

### Jumpbox Updates

#### Docker Installation

Ubuntu - docker.io is available from the Ubuntu repositories (as of Xenial).

```bash
# Install Docker
sudo apt install docker.io
sudo apt install docker-compose

# Start it
sudo systemctl start docker
```

OR Possibly...

```bash
$ sudo su
$ apt-get update
$ apt-get install apt-transport-https ca-certificates \
                  curl gnupg-agent software-properties-common
$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
       apt-key add -
$ apt-key fingerprint 0EBFCD88
$ lsb_release -cs
$ add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
$ apt-get update
$ apt-get install docker-ce docker-ce-cli containerd.io
$ systemctl start containerd.service
$ systemctl start docker.service
$ docker run hello-world
$ docker images
```

#### EBS Resizing of the Jumpbox

##### Increase EBS Volume

Instructions to increase the size of the jumpbox volume when running out of space.

https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/recognize-expanded-volume-linux.html 

1. Find the `PCF Terraform` instance in the AWS Console. 

2. In the details view, click on the **Root device** link to show the EBS details popup. 

3. In the popup, click on the **EBS ID** link to go to the EBS volume screen. 

4. Click on the volume and use the Actions -> Modify Volume to increase the disk size.

5. Once the volume size is increased, `ssh` to the jumpbox. Check out the blocks and disk free:

   ```bash
   $ lsblk
   $ df -h
   $ sudo file -s /dev/xvd*
   ```

6. Now expand the partition and resize:

   ```bash
   $ sudo growpart /dev/xvda 1
   $ lsblk
   $ df -h
   $ sudo resize2fs /dev/xvda1
   $ df -h
   ```

##### Decrease EBS Volume

https://cloudacademy.com/blog/amazon-ebs-shink-volume/

Essentially: 

1. Snapshot the original volume for backup

1. Create a new smaller volume

1. Attach it to the original instance

1. Copy contents of the original to smaller volume

1. Remove larger volume and use the smaller volume.

### AWS CodeCommit

Get setup to use CodeCommit on your AWS WorkSpace.

https://docs.aws.amazon.com/codecommit/latest/userguide/setting-up-ssh-unixes.html?icmpid=docs_acc_console_connect

1. Generate an SSH key to use.

2. In AWS, click on your use ID in the upper right of the screen and select **My Security Credentials**.

3. Select the **AWS CodeCommit credentials** tab.

4. Select **Update SSH public key** and provide the public key.

5. On your AWS WorkSpaces images, create a `config` file in the home directory `.ssh` directory. The value for **User** is the SSH key ID from the uploaded SSH public key. The **IdentifyFile** is the path and file name of the private key file generated in step 1. above.

```bash
$ vi ~/.ssh/config
Host git-codecommit.*.amazonaws.com
User <SSH KEY ID>
IdentityFile ~/.ssh/cbusch
```

6. Now clone the `pivotal-helpers` repo to the AWS WorkSpaces image to test the setup:

```bash
$ git clone ssh://git-codecommit.us-west-1.amazonaws.com/v1/repos/pivotal-helpers
```

### BitBucket

When using HTTPS tokens with git, the clone URL needs to have the username and token inserted into it.  This is the template: `git clone https://{username}:{access_token}@yourbitbucket.org/user/repo.git`

If you get an error about self-signed certs, you will need to add the root cert to your git config file.  That can be done with the following command: 
`git config --global http.sslCAInfo <path-to-cert>/ca-bundle.crt`
This also works with .cer files.  The cert file just needs to be in a Base-64 encoded X.509 format.

The problem with adding the above statement to your .gitconfig file is that you will no longer be able to pull from other git repos like GitHub.  So, the better solution is to go to your system .gitconfig file under `C:\Program Files\Git`.  It should include a pointer to which cert bundle it is checking.  The default is `C:\Program Files\Git\mingw64\ssl\certs\ca-bundle.crt`.  If you paste the contents of the Root cert into the end of this file, you should be able to pull git repos from BitBucket and GitHub.  You have to have admin rights to be able to do this since it is a change to the Program Files.

### Control Plane

Control Plane appears to be an OpsMan deploy with a bosh deploy of platform automation engine.

#### Operations Manager

Name: `control-plane-ops-manager`
Private DNS: `ip-10-150-16-13.us-west-1.compute.internal`
Private IP: `10.150.16.13`

```bash
# jumpbox
ubuntu@ip-10-125-0-29:~$ cat ~/env/cp/env.yml
---
target: https://10.150.16.13
username: admin
password: xxxxxxxxx
skip-ssl-validation: true
```

### DEV
Name: `dev-ops-manager-vm`
Private DNS: `ip-10-152-16-10.us-west-1.compute.internal`
Private IP: `10.152.16.10`

```bash
# jumpbox
ubuntu@ip-10-125-0-29:~$ cat ~/env/dev/dev-ops.env
target: https://10.152.16.10
username: admin
password: xxxxxxxxx
skip-ssl-validation: true
```

#### Apps Manager

https://apps.sys.dev.domain.com 
`admin` / `D6_LYO8IaFpkXFF6ivGCieXMUlQPDJ7_`

### Sandbox

```bash
# jumpbox
ubuntu@ip-10-125-0-29:~$ cat ~/env/sandbox/sandbox-ops.env
target: https://10.151.16.5
username: admin
password: xxxxxxxxx
skip-ssl-validation: true
```

#### Apps Manager

https://apps.sys.sandbox.domain.com
`admin` / `oE04dLDreJOP729U_mFEN_ubca-JZb1W`

---

## Concourse

https://concourse.control.domain.com 
`admin` / `PJotqYmmM8sgXz3TBkdGvVelxz05wp`

---

## Credhub

Once logged into the jumpbox, run: 

```bash
$ source ./concourse-credhub-login
```

The above file contains the following in order to get to the concourse credhub.

```bash
export CREDHUB_SERVER=https://credhub.control.domain.com
export CREDHUB_CLIENT=concourse_to_credhub
export CREDHUB_SECRET=urIOTEEn09lId0G9G24YkOo5WWVpf7
credhub login --skip-tls-validation
```

---

Google Chrome ERR_

```bash
sudo open /Applications/Google\ Chrome.app --args --ignore-certificate-errors
```

---


## Harbor

https://harbor.control.domain.com
`admin` / `8d46sJD7Gy7zcb`

### Using a Self-Signed Certificate

https://docs.docker.com/engine/security/certificates/


The certificate, key, and ca-cert are from the control plane self-generation of an SSL certificate for the Harbor tile.

On the jumpbox, a special directory is created for docker to recognize the self-signed cert and ca-cert. Follow these instructions:

1. Create a directory of the certificate, key, and ca files. It must be located here:

```bash
sudo mkdir -p /etc/docker/certs.d/harbor.control.domain.com
```

2. Create a certificate file with the contents of the certificate below (must be client.cert):

```bash
sudo vi /etc/docker/certs.d/harbor.control.domain.com/client.cert
```

3. Create a key file with the contents of the private key below (must be client.key):

```bash
sudo vi /etc/docker/certs.d/harbor.control.domain.com/client.key
```

4. Create a ca-cert file with the contents of the ca below (must be ca.crt):

```bash
sudo vi /etc/docker/certs.d/harbor.control.domain.com/ca.crt
```

Log into harbor from docker as below:

```bash
$ sudo docker login -u admin -p 8d46sJD7Gy7zcb harbor.control.domain.com
Self-signed Certificate and CA
```

#### CERTIFICATE

```bash
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
```

#### PRIVATE_KEY

```bash
-----BEGIN RSA PRIVATE KEY-----
...
-----END RSA PRIVATE KEY-----
```

#### CA-CERT

```bash
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
```

### Importing Images

#### Import some images

```bash
$ docker import alpine.tgz alpine:latest
$ docker import busybox.tgz busybox:latest
$ docker import jira-image.tgz jira:latest
$ docker import nginx.tgz nginx:latest
$ docker import tiller.tgz tiller:latest
$ docker import platform-automation-4.3.2.tgz platform-automation:4.3.2
```

#### Tag to import in Harbor

```bash
$ docker tag alpine:latest \
         harbor.control.domain.com/pks/alpine:latest
$ docker tag busybox:latest \
         harbor.control.domain.com/pks/busybox:latest
$ docker tag jira:latest \
         harbor.control.domain.com/pks/jira:latest
$ docker tag nginx:latest \
         harbor.control.domain.com/pks/nginx:latest
$ docker tag tiller:latest \
         harbor.control.domain.com/pks/tiller:latest
$ docker tag platform-automation:4.3.2 \
         harbor.control.domain.com/library/platform-automation:4.3.2
```

#### Log into Harbor

```bash
$ docker login -u admin harbor.control.domain.com --ca-cert $HOME/certs/ca-root.crt

Login Succeeded
```

#### Push to Harbor

```bash
docker push harbor.control.domain.com/pks/alpine:latest
docker push harbor.control.domain.com/pks/busybox:latest
docker push harbor.control.domain.com/pks/jira:latest
docker push harbor.control.domain.com/pks/nginx:latest
docker push harbor.control.domain.com/pks/tiller:latest
docker push harbor.control.domain.com/library/platform-automation:4.3.2

```

---

## PKS API Server

https://api.pks.dev.domain.com:8443 (This DNS entry is tied to an internal LB with a CNAME entry)
PKS API Server Cert 

### Target uaa to create a user account

```bash
$ uaac target https://api.pks.dev.domain.com:8443 --ca-cert pas-dev.pem --skip-ssl-validation
```

Use the PKS -> Credentials -> Pks Uaa Management Admin Client secret

```bash
$ uaac token client get admin -s <secret>
```

### Create the uaa user

```bash
$ uaac user add theUser --emails theUser@example.com -p password
```

### Add user to appropriate uaa scopes

Can access and create all clusters

```bash
$ uaac member add pks.clusters.admin theUser
```

Can access and create only clusters created

```bash
$ uaac member add pks.clusters.manage theUser
```

Login w/ account created (will prompt for password)

```bash
$ pks login -a api.pks.dev.domain.com -u theUser -k
```

### Create the cluster

The external hostname can be an ip address, but preferably something that a DNS entry attached to it! 

```bash
$ pks create-cluster test \
      --plan small \
      --external-hostname test-cluster.pks.dev.domain.com
```

Displays if the cluster creations succeeded or failed

```bash
$ watch pks cluster test 
$ pks get-credentials test
```

This config file defaults to a hidden `.kube` directory in the users home directory. Can port the directory or specifically the config file to other workstations and work from there.

```bash
$ kubectl config use-context test
```

`kubectl` completion is configured on the jumpbox within the `.bashrc` file. The command added is:

```bash
$ source <(kubectl completion bash)   # >
```

### BOSH completion

BOSH completion for zsh

```bash
# Linux
wget https://github.com/thomasmitchell/bosh-complete/releases/download/v1.2.0/bosh-complete-linux
mv bosh-complete-linux /usr/local/bin/bosh-complete

# MAC OS
wget https://github.com/thomasmitchell/bosh-complete/releases/download/v1.2.0/bosh-complete-darwin
mv bosh-complete-darwin /usr/local/bin/bosh-complete

# make executable
chmod +x /usr/local/bin/bosh-complete

# If using BASH, add to .bashrc
echo 'eval "$(/usr/local/bin/bosh-complete bash-source)"' >> $HOME/.bashrc

# If using ZSH, add to .zshrc
echo 'eval "$(/usr/local/bin/bosh-complete zsh-source)"' >> $HOME/.zshrc
```

### Setup the ALB Ingress Controller

(Kubernetes reference: https://kubernetes-sigs.github.io/aws-alb-ingress-controller/guide/controller/setup/)

The rbac-config file creates the service acct required to give the ingress controller cluster-wide access for future deployment services.
These services should be type `nodeport` or `loadbalancer`.  At the operator/developer/admin discretion rbac can be configured to specific namespace.
(Current state is full access to the cluster.)

```bash
$ kubectl create -f rbac-role.yaml
```

To deploy the ingress controller:

```bash
$ kubectl apply -f alb-ingress-controller.yaml
```

To confirm the deployment:

```bash
$ kubectl describe deployment/alb-ingress-controller -n kube-system
```

To confirm proper permissions you can check the logs.  (The `Administrators` group can be applied to the IAM user acct to provide permissions.)

```bash
$ kubectl logs deployment/alb-ingress-controller -n kube-system
```

---

## CERTIFICATES AND DOMAINS

### CONTROL PLANE

1. SSL Cert regenerated with the following:

```bash
Common Name: control.domain.com
SANs: *.control.domain.com
```

2. DNS entries

```bash
credhub.control.domain.com = credhub internal LB
concourse.control.domain.com = concourse internal LB
uaa.control.domain.com = uaa internal LB
harbor.control.domain.com = 10.150.16.10
```

### DEV

1. SSL Cert regenerated with the following:

```bash
Common Name: dev.domain.com
SANs: *.apps.dev.domain.com, *.sys.dev.domain.com, *.uaa.sys.dev.domain.com, *.login.sys.dev.domain.com, *.dev.domain.com
```

2. PAS Domains in OM PAS Tile -> Domain settings: 

```bash
APPS: apps.dev.domain.com
SYSTEM: sys.dev.domain.com
```

3. DNS entries

```bash
*.apps.dev.domain.com = dev web LB
*.sys.dev.domain.com = dev web LB
api.pks.dev.domain.com = dev-pks-api-lb-0c97667dae6244ec.elb.us-west-1.amazonaws.com
```

### SANDBOX

1. SSL Cert regenerated with the following:

```bash
Common Name: sandbox.domain.com
SANs: *.apps.sandbox.domain.com, *.sys.sandbox.domain.com, *.uaa.sys.sandbox.domain.com, *.login.sys.sandbox.domain.com, *.sandbox.domain.com
```

2. PAS Domains in OM PAS Tile -> Domain settings:

```bash
APPS: apps.sandbox.domain.com
SYSTEM: sys.sandbox.domain.com
```

3. DNS entries

```bash
*.apps.sandbox.domain.com = sandbox web LB
*.sys.sandbox.domain.com = sandbox web LB
```

### OTHER ENVs

1. SSL Cert regenerated with the following:

```bash
Common Name: <env>.domain.com
SANs: *.apps.<env>.domain.com, *.sys.<env>.domain.com, *.uaa.sys.<env>.domain.com, *.login.sys.<env>.domain.com, *.<env>.domain.com
```

2. PAS Domains in OM PAS Tile -> Domain settings:

```bash
APPS:   apps.<env>.domain.com
SYSTEM: sys.<env>.domain.com
```

3. DNS entries

```bash
*.apps.<env>.domain.com = environment web LB
*.sys.<env>.domain.com  = environment web LB
```

---

## Tips and Tricks

### Add CA-CERT to VM

```bash
$ echo ${OPSMAN_PWD}
$ sudo -S mv ~/*_cert.pem /etc/ssl/certs 

$ echo ${OPSMAN_PWD} 
$ sudo -S update-ca-certificates -v -f"
```

### Change OM IP to DNS

First, `ssh` to the opsman vm, list the current hostname config, change the hostname to the FQDN (DNS), check to make sure it changed, then finally reboot. Make sure to have the Ops Manager decryption passphrase available after the VM restarts.

```bash
$ sudo -u postgres psql -d tempest_production -c "SELECT id, hostname from uaa_configs"
 id |   hostname
----+--------------
  1 | 10.150.16.13
(1 row)

$ sudo -u postgres psql -d tempest_production -c "UPDATE uaa_configs set hostname='opsman.control.domain.com' where id=1"
UPDATE 1

$ sudo -u postgres psql -d tempest_production -c "SELECT id, hostname from uaa_configs"
 id |          hostname
----+----------------------------
  1 | opsman.control.domain.com
(1 row)

$ sudo shutdown -r now
```

---

## Certificates for local Workspace Image

To remedy the cert not showing up as trusted/Connection not secure. Follow the steps below:

1. Download the root-ca.pem from S3
2. Double-click the cert to install -> Select local machine -> Select `Place all certificates in the following store` and click browse to select the `Trusted Root Certification Authorities`

3. Open Firefox and navigate to about:config (click accept risk)
4. In the pane, search for `security.enterprise_roots.enabled` -> double click the entry to change the value to `true`
5. Close Firefox and reopen.

---

## Cleaning up the domain change in PAS

1. Recommend deleting all orphaned routes: `cf delete-orphaned-routes`

2. To delete the shared-domain run: `cf delete-shared-domain apps.pas.sandbox.domain.com`

---

## Setting up service key policies for AWS Service Broker Tile

Follow the directions to install AWS Service Broker Tile:  https://docs.pivotal.io/aws-services/installation.html#install

Setting up the "Resource" arn for each service key policy can be tricky since the docs are confusing in this regard.

Below is a working configuration for the PCFAppDeveloperPolicy-s3 policy.  Notice the format of the Resource arn and follow this format for each of the other policies.

```bash
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:GetBucketTagging",
                "s3:PutBucketTagging"
            ],
            "Resource": "arn:aws-us:s3:::*"
        }
    ]
}
```
