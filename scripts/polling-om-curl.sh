 function polling_om_curl () {
    local env_file="${1}"
    local uri_path="${2}"
    local payload="${3}"
    local method="${4:-POST}"
    local poll_attempts="${5:-120}"
    local poll_interval="${6:-3}"

    local counter=0

    method=$(echo "${method}" | tr '[:lower:]' '[:upper:]')
    if [[ "${method}" != "POST" && "${method}" != "PUT" ]] ; then
        echo "ERROR: Function only supports PUT and POST methods"
        return 1
    fi
    
    result=$(om --env "${env_file}" curl \
                --silent \
                --path "${uri_path}" \
                --request "${method}" \
                --data "${payload}" 2>&1 | jq -S .)
    retcode=$?
    
    if [[ $retcode == 0 ]]; then
        guid=$(echo "${result}" | jq -r '.[].guid')
        if [[ ${method} == 'POST' ]] ; then
            uri_path="${uri_path}/${guid}"
        fi
        while [[ $counter -lt "${poll_attempts}" ]]; do
            counter=$((counter+1))
            saved=$(om --env "${env_file}" curl --silent --path "${uri_path}" | jq -S .)
            # temporary hack - master blaster has an old version of `om` that puts nulls
            # in place of empty strings
            saved=$(echo "${saved}" | sed -e 's/null/""/g')
            
            if [[ "${saved}" == "${result}" ]] ; then
                echo ${result}
                return 0
            fi

            echo "INFO: ${method} to ${uri_path} has not completed. Rechecking in ${poll_interval}s."
            sleep "${poll_interval}"
        done

        echo "ERROR: Unable to confirm ${method} completion in ${poll_attempts} attempts."
        return 1
    else
        echo -e "ERROR:\n${result}"
        return $retcode
    fi
}