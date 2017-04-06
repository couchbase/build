#!/bin/sh

cd `dirname $0`

# jenkins-slave (currently hosted on mega2)
docker-compose \
  -f /home/couchbase/ceej/asterix-opt/test-support/app/docker-compose.yml \
  build jenkins-slave
docker-compose \
  -f /home/couchbase/ceej/asterix-opt/test-support/app/docker-compose.yml \
  up -d --force-recreate jenkins-slave

# For reference only: Starting the Jenkins master
#docker run --detach=true --publish=8081:8080 --publish=50000:50000 \
#  --name analytics-jenkins \
#  --restart=unless-stopped \
#  --volume=/home/couchbase/analytics_jenkins:/var/jenkins_home \
#  --volume=/etc/timezone:/etc/timezone:ro \
#  --volume=/etc/localtime:/etc/localtime:ro \
#  jenkins:1.642.1

echo "All done!"

