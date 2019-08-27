#!/bin/bash

set -ex

director_ip=10.0.0.21
opsman_pwd="pivotal\!123"
opsman_url="opsman.busch.local"
bosh_taskcheck_client=bosh_taskcheck_client
bosh_taskcheck_client_secret=somesecret

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
