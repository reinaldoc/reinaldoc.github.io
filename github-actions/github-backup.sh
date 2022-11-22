#!/bin/bash

function require_envs() {
    for var in $@; do
      test -z ${!var} && { echo \$$var is required ; exit 1 ; }
    done
}

case "$1" in
  daily)
    BUCKET=github-backup-daily
  ;;
  weekly)
    BUCKET=github-backup-weekly
  ;;
  monthly)
    BUCKET=github-backup-monthly
  ;;
  *)
    echo "Unknown option '${1}'."
    echo "Use: $0 [ daily | weekly | monthly ]"
    exit 1
  ;;
esac

GITHUB_ORG_NAME=XXXXXXX
KEY_FP=XXXXXXXX
require_envs GITHUB_ORG_NAME CURL_USER_AND_TOKEN

# GPG public key required
gpg --list-keys ${KEY_FP} >/dev/null
test ${?} -ne 0 && { echo "Public key not found"; exit 1; }

# List repositories from Github API
repos_lines=""
i=1
while true; do
    len=${#repos_lines}
    repos_lines+=$(curl -s -u ${CURL_USER_AND_TOKEN} "https://api.github.com/orgs/${GITHUB_ORG_NAME}/repos?per_page=100&page=${i}" | jq -r '.[].clone_url' | grep -E '^https://')
    if [ ${len} -eq ${#repos_lines} ]; then
      break
    fi
    repos_lines+=$'\n'
    let i++
    test ${i} -gt 10 && { echo "Internal error. Failed load repositories from github"; exit 1; }
    sleep 0.2
done

# Convert string to array
readarray -t repos <<< $repos_lines

# Require at least 20 repositories
test ${#repos[@]} -lt 20 && { echo "Internal error. Error listing github repositories" ; exit 1; }

output=$(date +%Y-%m-%d)
mkdir ./${output} ./temp

# Clone, compress, encrypt and push to Cloud Storage
for repo_url in ${repos[@]}; do
  repo_name=$(basename $repo_url | sed -re 's/\.git$//')
  echo "Processing repository '${GITHUB_ORG_NAME}/${repo_name}'..."

  git clone $(echo ${repo_url} | sed -re "s%https://%https://$CURL_USER_AND_TOKEN@%") ./temp/${repo_name}
  test ${?} -ne 0 && { echo "Failed clone repo '${repo_url}'"; exit 1; }

  tar czf ./temp/${repo_name}.tar.gz -C ./temp ./${repo_name}

  gpg --encrypt --trust-model always --armor -r ${KEY_FP} ./temp/${repo_name}.tar.gz

  mv ./temp/${repo_name}.tar.gz.asc ./${output}/${repo_name}.tar.gz.enc

  gcloud storage cp ${output}/${repo_name}.tar.gz.enc gs://${BUCKET}/${output}/
done
