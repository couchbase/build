# Docker container for Ubuntu 10.04

# See https://github.com/ceejatec/naked-docker/ for details about the
# construction of the base image.

FROM ceejatec/ubuntu-1004-couchbase-builddocker:latest
MAINTAINER ceej@couchbase.com

# Re-install buildbot_slave as repo slave
RUN rm -rf /home/buildbot/buildbot_slave && \
    mkdir /home/buildbot/buildbot_slave && \
    buildslave create-slave /home/buildbot/buildbot_slave 10.1.1.210:9999 ubuntu-x64-1004-repo-builder ubuntu-x64-1004-repo-builder && \
    echo "Couchbase Build Team <build-team@couchbase.com>" > /home/buildbot/buildbot_slave/info/admin && \
    echo "Ubuntu 10.04 x86_64 Couchbase Build Slave running in Docker" > /home/buildbot/buildbot_slave/info/host && \
    chown -R buildbot:buildbot /home/buildbot/buildbot_slave
