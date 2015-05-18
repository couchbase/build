# Docker container for Ubuntu 12.04

# See https://github.com/ceejatec/naked-docker/ for details about the
# construction of the base image.

FROM ceejatec/ubuntu-1204-couchbase-build
MAINTAINER hari.kodungallur@couchbase.com

USER root

# install easy_install and paramiko
RUN apt-get install -y python-setuptools && \
    rm -f /var/cache/apt/archives/*.deb && \
    easy_install paramiko
