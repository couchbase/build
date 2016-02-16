#!/bin/bash

echo @@@@@@@@@@@@@@@@@@@@@@
echo @ Restarting servers
echo @@@@@@@@@@@@@@@@@@@@@@
docker start mobile-jenkins cv-jenkins server-jenkins images-nginx
sleep 5

echo @@@@@@@@@@@@@@@@@@@@@@
echo @ Recreating slaves
echo @@@@@@@@@@@@@@@@@@@@@@
./restart_all_builddockers.sh
./restart_cv_builders.sh
./restart_mobile.sh

