#!/bin/bash
# hub.sh - A script to get github public repos, build container image and push to a registry.
# Writed by: Reinaldo de Carvalho <reinaldoc@gmail.com>

GITHUB_REPOS="https://api.github.com/users/wearewebera/repos"
REGISTRY="index.docker.io"
REPOSITORY_PREFIX="webera"
DEPENDENCIES="curl jq"

function dependencies() {
    which ls >/dev/null 2>&1
    test ${?} -eq 127 && { echo "Command 'which' not found. Exiting..." ; exit ; }

    for dep in ${DEPENDENCIES}; do
        test -x "$(which ${dep} 2>/dev/null)" || { echo "Command '${dep}' not found. Exiting..." ; exit; }
    done
}

function registry_logged_in() {
    timeout -s SIGKILL --foreground 30s bash -c 'docker login >/dev/null 2>&1'
    test "${?}" -eq 0 || { echo "Not logged in Registry: ${REGISTRY}."; echo "Please run 'docker login' successfully." ; exit; }
}

function github_repos() {
    if [ -f ../github_repos.mock ] ; then
      cat ../github_repos.mock
    else
      curl -s ${GITHUB_REPOS} | jq '.[]|.html_url' | tr -d \"
    fi
}

function image_build_and_push() {
    echo "Build: ${1}"
    git clone "${1}"
    IMAGE_DIR=$(basename "${1}")
    cd ${IMAGE_DIR}
    if [ -f Dockerfile ] ; then
        test -f cloudbuild.yaml || { echo "cloudbuild.yaml not found in ${1}. Aborting..."; return ;}
        IMAGE_NAME=$(grep _IMAGE_NAME: cloudbuild.yaml | cut -f2 -d: | tr -d ' ')
        SHORT_SHA=$(git log --format="%H" -n 1 | cut -c1-7)
        TAG=$(date -u +${SHORT_SHA}-%Y%m%dT%H%M)
        docker build -t ${REPOSITORY_PREFIX}/${IMAGE_NAME}:${TAG} -t ${REPOSITORY_PREFIX}/${IMAGE_NAME}:latest .
        docker push ${REPOSITORY_PREFIX}/${IMAGE_NAME}:${TAG}
        docker push ${REPOSITORY_PREFIX}/${IMAGE_NAME}:latest
    else
        echo "Dockerfile not found in ${1}"
    fi
    cd ..
}

function manage_workdir() {
  case "${1}" in
     create)
       mkdir -p hub-workdir
       cd hub-workdir
     ;;
     delete)
       cd ..
       rm -rf hub-workdir
     ;;
     *)
       echo "Error using internal function @manage_workdir"
     ;;
 esac

}

function main () {

    dependencies
    registry_logged_in
    manage_workdir create

    for repo in $(github_repos); do
        image_build_and_push "${repo}"
    done

    manage_workdir delete
}

main
