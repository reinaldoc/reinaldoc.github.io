#!/bin/bash

echo 'Stoping running containers...'
IDs=$(docker ps -q)
if [ ! -z "${IDs}" ]; then
    docker stop ${IDs}
fi

echo 'Removing containers...'
IDs=$(docker ps -qa)
if [ ! -z "${IDs}" ]; then
  docker rm ${IDs}
fi

echo 'Removing images...'
IDs=$(docker images -qa)
if [ ! -z "${IDs}" ]; then
   docker image rm --force ${IDs} 2>/dev/null
fi
