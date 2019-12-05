#!/bin/bash

set -e

repos=$( (ls -d */) )
root_dir="$(pwd)"

for repo in ${repos[@]}; 
do
  echo -e "---\nWorking on repo: ${repo}..."

  pushd ${root_dir} >/dev/null
  cd ${repo}

  if [[ ! -d ".git" ]]; then 
    echo "${repo} is not a GIT repo, continuing..."
    continue
  fi

  if [[ "$(git branch | grep '*' | cut -d' ' -f2)" != "master" ]]; then
    echo "${repo} is not on the 'master' branch, skipping..."
    continue
  fi
  
  echo "  Pulling latest from ${repo}..."
  git pull

  popd >/dev/null
done

echo -e "\nDone..."
