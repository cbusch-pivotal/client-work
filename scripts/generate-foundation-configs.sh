#!/bin/bash

set -e

if [[ -z $1 ]]; then
  echo "Please supply the foundation name"
  echo "Example: generate_configs.sh sandbox"
  exit 1
fi

foundation=${1}

export products=( $(om -e $HOME/env/${foundation}/env.yml staged-products -f json | jq -r '.[].name') )

mkdir -p $HOME/configs/$foundation

for prod in ${products[@]}; do
  if [[ ${prod} == "p-bosh" ]];then
    echo "Exporting the director configuration for ${foundation}"
    om -e $HOME/env/${foundation}/env.yml staged-director-config --no-redact > \
          $HOME/configs/${foundation}/director-${foundation}.yml
  else
    echo "Exporting product $prod for ${foundation}"
    om -e $HOME/env/${foundation}/env.yml staged-config -c -p $prod > \
          $HOME/configs/${foundation}/$prod-${foundation}.yml
  fi
done

