params:
  ENV_FILE: env.yml
  # - Filepath of the env config YAML
  # - The path is relative to root of the `env` input
  CA:
  # - Local CA for signing Ops-Manager dcertificates
  FOUNDATION_NAME:
  # - name of foundation
  OPSMAN_URL:
  # - opsmanager url
  CREDHUB_SERVER:
  CREDHUB_CA_CERT:
  CREDHUB_CLIENT:
  CREDHUB_SECRET:
  # - CREDHUB_xxx variables
  # - must be set in calling task to target and log into credhub
  CREDHUB_BOSH_UAA_CLIENT:
  # - name of bosh taskcheck client for credhub and bosh uaa
  CREDHUB_ACTION:
  # - action of either 'create' or 'delete'
  # - anything other than 'delete' checks and creates if not found in credhub
  BOSH_UAA_GRANTS:
  BOSH_UAA_AUTHORITIES:
  # - BOSH_UAA_xxx variables
  # - comma-separated list of client grants and authorities
  BOSH_UAA_ACTION:
  # - action is either 'create'; 'update'; 'delete'
  # - if uaa client exists, it forces update otherwise adds

    set -eux

    function credhub_create ()
    {
      #---------
      # CREDHUB
      #---------
      echo "Target and login to credhub..."
      credhub api
      credhub login
      echo "---------------------------"

      if [[ ${CREDHUB_ACTION} = "delete" ]]; then
        echo "Deleting the credhub ${CREDHUB_BOSH_UAA_CLIENT} user..."
        credhub delete -n "${CREDHUB_BOSH_UAA_CLIENT}" 2> /dev/nul
      else
        echo "Checking if ${CREDHUB_BOSH_UAA_CLIENT} user exists in credhub..."
        CREDHUB_FIND_RESULT="$(credhub find -n ${CREDHUB_BOSH_UAA_CLIENT})"

        if [[ -z "${CREDHUB_FIND_RESULT}" ]]; then
          echo "Client ${CREDHUB_BOSH_UAA_CLIENT} doesn't exist in credhub...creating..."
          # add and generate password for user
          credhub generate -t user -n /concourse/${FOUNDATION_NAME}/${CREDHUB_BOSH_UAA_CLIENT} --username ${CREDHUB_BOSH_UAA_CLIENT}
        fi
        # get the CREDHUB client secret
        export CREDHUB_BOSH_UAA_CLIENT_SECRET="$(credhub get -n /concourse/${FOUNDATION_NAME}/${CREDHUB_BOSH_UAA_CLIENT} --key password)"
      fi
    }

    function bosh_uaa_create ()
    {
      #----------
      # BOSH UAA 
      #----------
      uaac target https://${BOSH_DIRECTOR_IP}:8443 --ca-cert /var/tempest/workspaces/default/root_ca_certificate
      uaac token owner get login -s ${UAA_LOGIN_SECRET} admin -p ${UAA_ADMIN_USER_PASSWORD}

      if [[ ${BOSH_UAA_ACTION} = "delete" ]]; then
        echo "Deleting bosh uaa client ${CREDHUB_BOSH_UAA_CLIENT}..."
        uaac client delete "${CREDHUB_BOSH_UAA_CLIENT}" 2> /dev/nul
      else # must be add or update
        CLIENT_EXISTS="$(uaac clients | grep ${CREDHUB_BOSH_UAA_CLIENT})"
        if [[ "${CLIENT_EXISTS}" ]]; then UAAC_ACTION=update; else UAAC_ACTION=add; fi

        # add or update the client with grants/authorities
        echo "${UAAC_ACTION} the bosh uaa client ${CREDHUB_BOSH_UAA_CLIENT}..."
        uaac client "${UAAC_ACTION}" "${CREDHUB_BOSH_UAA_CLIENT}" \
              --authorized_grant_types "{BOSH_UAA_GRANTS}" \
              --authorities "${BOSH_UAA_AUTHORITIES}" \
              --secret "${CREDHUB_BOSH_UAA_CLIENT_SECRET}"
      fi
    }

    echo "Getting BOSH director IP from OpsMan..."
    export BOSH_DIRECTOR_IP=$(om --env env/env.yml curl --path=/api/v0/deployed/products/${BOSH_DIRECTOR_ID}/static_ips | jq -r .[0].ips[0])

    echo "Getting BOSH UAA creds from OpsMan..."
    export UAA_LOGIN_SECRET=$(om --env env/"${ENV_FILE}" \
        curl -s -p /api/v0/deployed/director/credentials/uaa_login_client_credentials | jq -r .credential.value.password)
    export UAA_ADMIN_USER_PASSWORD=$(om --env env/"${ENV_FILE}" \
        curl -s -p /api/v0/deployed/director/credentials/uaa_admin_user_credentials | jq -r .credential.value.password)

    # run uaac commands from a distance
    echo "---------------------------"
    echo "Running remote to OpsMan to target BOSH UAA and create new bosh uaa client..."
    echo "---------------------------"
