# NOTES

## OM BREW INSTALL

```bash
brew tap pivotal-cf/om https://github.com/pivotal-cf/om
brew install pivotal-cf/om/om
```

## Remember ssh key passwords
https://www.funtoo.org/Keychain

```bash
$ brew install keychain
$ eval `keychain --eval --agents ssh --inherit any cbusch`
```

## CONCOURSE

### login to the team

```
fly -t <team> login

# copy entire "Bearer ...." and paste for manual token
https://<ci.domain.com>/sky/token

fly -t <team> set-pipeline -p cf-mgmt-config -c pipeline.yml -l params.yml -v worker_tags=dev

# setting a --var takes precendence over -l with either of the formats

$ fly -t <team> sp -p app-mysql-backup -c foundation/app/mysql-pipeline.yml -l ./common.yml -l foundation/app/app-mysql-params.yml -v worker_tags=dev --var=retention_policy=5d

# CONCOURSE PIPELINES
fly -t <team> pipelines

# check if pipeline jobs or builds are running
fly -t <team> jobs -p cf-mgmt-config | sed 's/[[:space:]][[:space:]]*/,/g' | cut -d, -f3
fly -t <team> builds -p upgrade-redis | tr -s '[:blank:]' ',' | cut -f2 -d","

```

## CONNECT TO JUMPBOX FOR QUERYING ECS

```bash
$ ssh ubuntu@<jumpbox or opsman> -o PubkeyAuthentication=no

# install minio client
$ brew install minio/stable/mc

# set the host
$ mc config host add ecs <endpoint, i.e.: https://s3.amazonaws.com> <access_id> <access_key>
$ mc ls ecs
```

## BOSH 

### filtering out service instances

```bash
# BOSH list services types
bosh -e director deployments --json | jq -r '.Tables[].Rows[] | .team_s' | sort | uniq | sed '/^[[:space:]]*$/d'
bosh -e director deployments --json | jq -r '.Tables[].Rows[] | select(.team_s != "")'
bosh -e director deployments --json | jq -r '.Tables[].Rows[] | select(.team_s != "") | .team_s'
bosh -e director deployments --json | jq -r '.Tables[].Rows[] | select(.team_s != "") | .team_s' | sort | uniq
bosh -e director deployments --json | jq -r '.Tables[].Rows[] | select(.team_s != "") | .team_s + "\t " + .name' | sort

bosh -e director deployments --json | jq -r '.Tables[].Rows[] | select(.team_s|test("crunchy.")) | .name'
```


## GIT

```bash
# regular work
git add .
git commit -m "comments"
git pull
git push

# updating a commit that hasn't been pushed
git commit --amend --no-edit

git commit --amend -m "an updated commit message"
```


## UAAC

```bash

uaac client add CLIENT-NAME --authorized_grant_types client_credentials --authorities bosh.read --secret CLIENT-SECRET
```


## SSHPASS commands

```bash
brew install sshpass

sshpass -p password ssh -q -o StrictHostKeyChecking=no ubuntu@opsman.domain.com 'uaac target https://192.168.0.11:8443  --ca-cert /var/tempest/workspaces/default/root_ca_certificate'

sshpass -p password ssh -q -o StrictHostKeyChecking=no ubuntu@opsman.domain.com 'uaac token owner get login -s <secret> admin  --password <password>'

sshpass -p password ssh -q -o StrictHostKeyChecking=no ubuntu@opsman.domain.com 'uaac clients'

sshpass -p password ssh -q -o StrictHostKeyChecking=no ubuntu@opsman.domain.com 'if [[ $(uaac clients | grep -i taskcheck) ]]; then exit 1; else exit 0; fi'
```


## OM commands

```bash
# GET STAGED CONFIG for a PRODUCT that's been deployed
om --env env.yml staged-config -p apmPostgres --include-placeholders > ./metrics/metrics-params.yml

## STAGED PRODUCTS
$ om --env env.yml staged-products

+--------------------------------+----------------+
|              NAME              |    VERSION     |
+--------------------------------+----------------+
| p-spring-cloud-services        | 2.0.6          |
| p-cloudcache                   | 1.5.2-build.9  |
| Pivotal_Single_Sign-On_Service | 1.8.0          |
| p-scheduler                    | 1.2.23         |
| crunchy-postgresql-10          | 05.1006.003    |
| p-healthwatch                  | 1.4.4-build.1  |
| apmPostgres                    | 1.6.0-build.41 |
| cf                             | 2.2.10         |
| credhub-service-broker         | 1.2.0          |
| pivotal-mysql                  | 2.4.4-build.2  |
| p-rabbitmq                     | 1.14.7         |
| p-bosh                         | 2.2-build.398  |
| p-redis                        | 1.14.4         |
+--------------------------------+----------------+
```

```bash
# get UAA Login and UAA Admin passwords for uaac-cli
# TODO: change -k to --env env/${env_file}
login_pwd=$(om -k curl -s -p /api/v0/deployed/director/credentials/uaa_login_client_credentials | jq -r .credential.value.password)
admin_pwd=$(om -k curl -s -p /api/v0/deployed/director/credentials/uaa_admin_user_credentials | jq -r .credential.value.password)

# run uaac commands from a distance
# TODO: change variable to CredHub / Params as necessary
# TODO: remove --skip-ssl-validation
sshpass -p ${OM_PASSWORD} ssh -q -o "StrictHostKeyChecking no" ubuntu@${opsman_url} \
<< EOF
uaac target https://${director_ip}:8443 --skip-ssl-validation
uaac token owner get login -s ${login_pwd} admin -p ${admin_pwd}
uaac client add ${bosh_taskcheck_client} --authorized_grant_types client_credentials --authorities bosh.read --secret "${bosh_taskcheck_client_secret}"
EOF
```

### GET VARIABLE PLACEHOLDERS FOR STAGED PRODUCT

```bash
$ om -e env.yml staged-config -r -p cf | awk -F'[(())]' '/\(\(/ {print $3}' | sort | uniq

cloud_controller_encrypt_key.secret
properties_credhub_hsm_provider_client_certificate.cert_pem
properties_credhub_hsm_provider_client_certificate.private_key_pem
properties_credhub_hsm_provider_partition_password.secret
properties_nfs_volume_driver_enable_ldap_service_account_password.secret
properties_smtp_credentials.identity
properties_smtp_credentials.password
uaa_service_provider_key_credentials.cert_pem
uaa_service_provider_key_credentials.private_key_pem
uaa_service_provider_key_password.secret
```

## General commands

#### Get variables from a yml file

```bash
awk -F'[(())]' '/\(\(/ {print $3}' mysql-pipeline.yml | sort | uniq

# get apps connected to services, skipping first 3 lines
cf services | awk '{if(NR>3)print $4}'
```

#### Get service instance IP

```bash
function getIPfromBOSH() {
  local SRV_GUID=$1
  local BOSH_CREDS=$(om --env env/"${ENV_FILE}" \
                    curl -s -p /api/v0/deployed/director/credentials/bosh_commandline_credentials | \
                    jq -r ".credential" | sed "s/ bosh //g")

  export SRV_IP=`sshpass -p ${SSH_PASSWORD} ssh -q -o StrictHostKeyChecking=no -M ${SSH_USERNAME}@${SSH_FQDN} \
  <<EOF
  ${BOSH_CREDS} bosh login
  ${BOSH_CREDS} bosh -d service-instance_${SRV_GUID} instances --json | jq -r '.Tables[].Rows[0].ips'
  EOF
  `
}

mysql_creds=$(cf curl v2/apps/$(cf app ${app_name} --guid)/env | \
                 jq -r ".\"system_env_json\".\"VCAP_SERVICES\".\"p.mysql\"[] | select(.name == \"${SERVICE_NAME}\") | .credentials")
local hostname=$(echo $mysql_creds | jq -r .hostname)
local dbname=$(echo $mysql_creds | jq -r .name)
local username=$(echo $mysql_creds | jq -r .username)
local password=$(echo $mysql_creds | jq -r .password)
local port=$(echo $mysql_creds | jq -r .port)
```

#### retrieve deployment IP is the hostname name is a BOSH DNS name, not an IP

```bash
# basic method:
#  if [[ ! $hostname =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
if [[ ! $hostname =~ ^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]; then 
  getIPfromBOSH "$(cf service ${SERVICE_NAME} --guid)"
  hostname=$(echo $SRV_IP | awk '{ print $NF }')
fi
```

#### list of apps bound to a service type, but could be dangerous

```bash
export apps=( $(cf services | grep "p.mysql" | awk '{print $4}' | sed "s/,//g") )
# probably best to use service name
export apps=( $(cf services | grep "jigsaw-mysql" | awk '{print $4}' | sed "s/,//g") )
```

#### Get CF admin user and password for PAS from OM

```bash
local pas_username=$(om -e env/env.yml -k credentials --product-name cf --credential-reference=.uaa.admin_credentials -f=identity)
local pas_password=$(om -e env/env.yml -k credentials --product-name cf --credential-reference=.uaa.admin_credentials -f=password)
```

#### Remove '\n' from certificates coming out of a yml or credhub

```bash
bosh interpolate <(awk -v ORS='\\n' '1' <(printenv DIRECTOR_CONFIG | tr -d '\r')) > config/director.yml
bosh interpolate <(awk -v ORS='\\n' '1' <(echo -n "${OPSMAN_CONFIG}" | tr -d '\r') | sed -e 's/..$//') > config/opsman.yml
```

#### GENERATE A NEW Operations Manager CERTIFICATE

```bash
#  ...for *.busch.local and control-plane.busch.local
#  using the opsmgr CA.

om interpolate -c <(awk -v ORS='\\n' '1' <(om generate-certificate -d "*.busch.local,control-plane.busch.local" | tr -d '\r')) --path /certificate

Certificate Information:
Common Name: *.busch.local
Subject Alternative Names: *.busch.local, control-plane.busch.local
Organization: Pivotal
Country: US
Valid From: July 7, 2019
Valid To: July 7, 2021
Issuer: Pivotal
Serial Number: 467805f1f78b876f786e44a21f1025dc6bdae994
```

#### ter command

```bash
$ xyz=$([[ "$x" == "valid" ]] && echo "valid" || echo "invalid")
```

#### get PAS configuration files for p-automator runs

```bash
# use `om generate-config` instead
tile-config-generator generate --base-directory=PAS --include-errands --token=NRWrckqpyXxiwLJ2XBMf --product-slug=elastic-runtime --product-version=2.4.2 --product-glob="cf-*pivotal"
```

#### interpolate the configuration for the target environment

```bash
bosh int product.yml \
  -l product-default-vars.yml \
  -l resource-vars.yml \
  -l errand-vars.yml \
  -o ./features/cloud_controller_default_stack-cflinuxfs2.yml \
  -o ./features/route_integrity-mutual-tls-verify.yml \
  -o ./features/routing_tls_termination-router.yml \
  -o ./features/haproxy_forward_tls-disable.yml \
  -o ./features/system_blobstore-external.yml \
  -o ./resource/diego_brain_elb_names.yml \
  -o ./resource/router_elb_names.yml \
  -o ./network/3-az-configuration.yml \
  > pas.yml

# get just the values needed to be set
cat pas.yml | grep -oh "((.*))"
```

#### check connectivity

```bash
nc -v 10.1.0.180 443
Connection to 10.1.0.180 443 port [tcp/https] succeeded!
^C
```

#### test script with associative arrays

```bash
TILE=(
  PAS="v2.2.10"
  healthwatch="v1.4.4"
  metrics="v1.6.0"
)

for tile in "${TILE[@]}"
do:
  tile_name=$(echo $tile | awk -F= '{print $1}')
  tile_folder=$(echo $tile | awk -F= '{print $2}')
  echo $tile_name ' and ' $tile_folder
done
```


#### create BOSH / CREDHUB environment variable

Necessary to use the bosh and credhub CLI's

```bash
# sets BOSH_ and CREDHUB_ environment
$ eval "$(om -e env.yml bosh-env)"
```

#### UNSET CREDHUB_ and BOSH_ environment

```bash
for var in $(env | grep -E "^BOSH_|^CREDHUB_" | cut -d"=" -f1); do unset $var; done
```

#### show processes failing for a deployment

```bash
#  bosh -d crunchy-postgresql-10-e5a979bde06d629fb317 instances --ps --column="Process State" | grep -Ev "running|-"

for i in `bosh --tty deployments --json | jq -r '.Tables[].Rows[] | .name'`; do echo "Deployment Name: " $i; DEPLOYMENT=$i;  bosh --tty -d $DEPLOYMENT instances --ps --json | jq -r '.Tables[].Rows[] | select((.process_state != "running") and .process_state != "") | "\(.instance) \(.process) \(.process_state)"'; echo; done

# pasteable line showing breaks
for i in `bosh --tty deployments --json | jq -r '.Tables[].Rows[] | .name'`; do\
  echo "Deployment Name: " $i;\
  DEPLOYMENT=$i;\
  bosh --tty -d $DEPLOYMENT instances --ps --json |\
    jq -r '.Tables[].Rows[] | select((.process_state != "running") and .process_state != "") | "\(.instance) \(.process) \(.process_state)"';\
  echo;\
done
```

#### Parse JSON for memory usage over 50%

```bash
$ bosh instances --vitals --json > instances.json

$ cat instances.json | .Tables[].Rows[] | select(.memory_usage != "") | select((.memory_usage | split("%") | .[0] | tonumber) >= 50) | "Instance: " + .instance + ", Memory: " + .memory_usage + ", CPU: " + .cpu_sys

# Monit Process
$ for i in bosh --tty deployments --json | jq -r '.Tables[].Rows[] | .name'; do echo -e "\033[1;32mDeployment Name: \033[0m" i; DEPLOYMENT=i;DEPLOYMENT=i; bosh --tty -d $DEPLOYMENT,instances --ps --json

# Memory
$ for i in bosh --tty deployments --json | jq -r '.Tables[].Rows[] | .name'; do echo -e "\033[1;32mDeployment Name: \033[0m" i; DEPLOYMENT=i;DEPLOYMENT=i; bosh --tty -d $DEPLOYMENT,instances --vitals --json

# Ephemeral Disk Usage
$ for i in bosh --tty deployments --json | jq -r '.Tables[].Rows[] | .name'; do echo -e "\033[1;32mDeployment Name: \033[0m" i; DEPLOYMENT=i;DEPLOYMENT=i; bosh --tty -d $DEPLOYMENT,instances --vitals --json

# Persistent Disk Usage
$ for i in bosh --tty deployments --json | jq -r '.Tables[].Rows[] | .name'; do echo -e "\033[1;32mDeployment Name: \033[0m" i; DEPLOYMENT=i;DEPLOYMENT=i; bosh --tty -d $DEPLOYMENT,instances --vitals --json
```

#### Service instance UUID

```bash
$ cf curl /v2/service_instances/$(cf service rab --guid)/service_bindings | jq -r '.resources[].entity.app_guid'
599cb13e-1345-4f9c-b638-af8ebe28b34e
df1ad060-2fb6-40df-8e39-3694aa70832a
```

#### Apps on a foundation

```bash
$ cf curl /v2/apps
{
   "total_results": 2,
   "total_pages": 1,
   "prev_url": null,
   "next_url": null,
   "resources": [
      {
         "metadata": {
            "guid": "599cb13e-1345-4f9c-b638-af8ebe28b34e",
            "url": "/v2/apps/599cb13e-1345-4f9c-b638-af8ebe28b34e",
            "created_at": "2018-10-19T15:46:23Z",
            "updated_at": "2019-03-04T14:43:16Z"
         },
         "entity": {
            "name": "attendees",
            "production": false,

$ cf curl /v2/apps | jq -r '.resources[] | select(.metadata.guid == "599cb13e-1345-4f9c-b638-af8ebe28b34e") | .entity.name'
attendees
```

#### Tunnel through app ssh session to get crunchy data

- must have pq_dump install locally
- create service key to access

```bash
#!/bin/bash

set -eux

service_name=$1
app_name=$(cf services | grep ${service_name} | awk '{print $4}')
if [[ ${app_name} == "" ]]; then
  # not bound to an app
  exit 1
fi

service_key="mykey"

cf create-service-key ${service_name} ${service_key}
DB_CREDS=$(cf service-key ${service_name} ${service_key} | sed '1,2d' | jq .)

TunnelPort=63308
Host=`echo ${DB_CREDS} | jq -r ".db_host"`
Port=`echo ${DB_CREDS} | jq -r ".db_port"`
DBName=`echo ${DB_CREDS} | jq -r ".db_name"`
User=`echo ${DB_CREDS} | jq -r ".username"`
Password=`echo ${DB_CREDS} | jq -r ".password"`

# open another terminal session to create the tunnel
#ttab -wt 'tunnel' "cf ssh -L ${TunnelPort}:${Host}:${Port} ${service_name}; exit"
cf ssh -L ${TunnelPort}:${Host}:${Port} ${service_name} &
ssh-pid=$!

while ! lsof -i:${TunnelPort} | grep -i LISTEN; do sleep 1; done

dumpFormat='c'
dumpFile='dump_file'

export PGHOST="localhost" && \
export PGPORT=${TunnelPort} && \
export PGUSER=${User} && \
export PGPASSWORD=${Password} && \
pg_dump --no-password \
        --dbname=${DBName} \
        --data-only \
        --format=${dumpFormat} \
        --exclude-table-data="schema_version" \
        --file=${dumpFile}

kill -9 ${ssh-pid}

# Add cf-mgmt user
uaac target uaa.system.domain.com --skip-ssl-validation
uaac token client get admin -s
uaac client add cf-mgmt --name cf-mgmt --secret password --authorized_grant_types client_credentials,refresh_token --authorities cloud_controller.admin,scim.read,scim.write
```

#### Logging into the bosh director and removing psql locks in the internal database

https://medium.com/@nnilesh7756/pks-pas-how-to-access-bosh-director-postgres-internal-database-4b042b62d142

```bash
# use OM -> Director -> VM Credentials (https://control-plane.busch.local/api/v0/deployed/director/credentials/vm_credentials)
$ ssh vcap@<director-IP>

$ sudo -i
vcap password: xxx

$ monit stop all

$ monit start postgres

$ /var/vcap/packages/postgres-9.4/bin/psql -U vcap bosh -h 127.0.0.1 

select * from locks;

delete from locks where id=????

Ctrl-D

$ monit start all
```

#### Let's Encrypt generated certs and credhub

```bash
sudo certbot --manual certonly --preferred-challenges dns-01 \
             --server https://acme-v02.api.letsencrypt.org/directory \
             --agree-tos \
             --domains '*.pcf.domain.com,*.apps.pcf.domain.com,*.sys.pcf.domain.com,*.uaa.sys.pcf.domain.com,*.login.sys.pcf.domain.com' \
             --email admin@domain.com

sudo openssl rsa -in /etc/letsencrypt/live/pcf.domain.com/privkey.pem -out ./privkey.key

credhub set -t certificate -n /concourse/letsencrypt \
            -p "$( cat privkey.key )" \
            -c "$( sudo cat /etc/letsencrypt/live/pcf.domain.com/cert.pem )" \
            -r "$( sudo cat /etc/letsencrypt/live/pcf.domain.com/chain.pem )"
```

#### OPERATIONS MANAGER generated certs and credhub

```bash
export domains="*.dev1.pcfapps.net, *.sys.dev1.pcfapps.net, *.apps.dev1.pcfapps.net, *.uaa.sys.dev1.pcfapps.net, *.login.sys.dev1.pcfapps.net"

# get OM ca cert
om -e config/env-dev1.yml certificate-authorities -f json | jq -r '.[] | select(.active==true) | .cert_pem' > ca-cert.pem

# OM generates certificate - split cert and private key into files
om -e config/env-dev1.yml generate-certificate -d "$domains" > dev1.cert
bosh int <( cat dev1.cert ) --path /certificate > dev1-certificate
bosh int <( cat dev1.cert ) --path /key > dev1-key

# add to Credhub
credhub set -n /concourse/dev1/wildcard_cert -t certificate 
            -c <( cat dev1-certificate ) 
            -p <( cat dev1-key ) 
            -r <( cat ca-cert.pem )

# validate what's added to Credhub
openssl x509 -in <( credhub get -n /concourse/dev1/wildcard_cert -k certificate ) -text -noout
openssl x509 -in <( credhub get -n /concourse/dev1/wildcard_cert -k ca ) -text -noout
```
