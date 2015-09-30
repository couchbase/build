#!/bin/bash

echo "These steps may display errors; that's OK"
docker ps -q -a | xargs docker rm
docker images -q --filter "dangling=true" | xargs docker rmi

