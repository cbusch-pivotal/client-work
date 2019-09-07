#!/bin/bash
set -eu

function update_ca_certificates {
  certificates="${1:-}"
  certificate_path="/usr/local/share/ca-certificates/cert"

  awk -v path="${certificate_path}" 'split_after==1 {n++;split_after=0}
    /-----END CERTIFICATE-----/ {split_after=1}
    {if(length($0) > 0) print > path n ".crt"}' \
    <(echo "${certificates}")
  update-ca-certificates
}
