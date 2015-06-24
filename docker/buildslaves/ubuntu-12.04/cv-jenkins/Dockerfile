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

# Install Clang 3.5 (current stable) - needed for building with ThreadSanitizer.
# (Note: This doesn't change the default compiler; users must explicitly
# select clang-3.5 / clang++-3.5).
RUN wget -O - http://llvm.org/apt/llvm-snapshot.gpg.key | sudo apt-key add - && \
    echo "deb http://llvm.org/apt/precise/ llvm-toolchain-precise-3.5 main" > /etc/apt/sources.list.d/llvm.list && \
    apt-get update && \
    apt-get install --assume-yes clang-3.5 && \
    rm -fr /var/cache/apt/archives/*.deb
