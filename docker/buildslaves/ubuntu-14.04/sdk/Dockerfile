# Docker container for Ubuntu 14.04

# See https://github.com/ceejatec/naked-docker/ for details about the
# construction of the base image.

FROM ceejatec/naked-ubuntu:14.04
MAINTAINER build-team@couchbase.com

USER root

# Install SSH server
RUN apt-get update && \
    apt-get install -y openssh-server && \
    rm -f /var/cache/apt/archives/*.deb && \
    mkdir /var/run/sshd # update 2

# Create couchbase user with password-less sudo privs, and give
# ownership of /opt/couchbase
RUN useradd couchbase -G sudo -m -s /bin/bash && \
    mkdir -p /opt/couchbase && chown -R couchbase:couchbase /opt/couchbase && \
    echo 'couchbase:couchbase' | chpasswd && \
    sed -ri 's/ALL\) ALL/ALL) NOPASSWD:ALL/' /etc/sudoers

RUN apt-get update && \
    apt-get install -y build-essential git autoconf cmake libevent-dev g++-multilib

RUN apt-get update && apt-get install -y unzip zip tar wget curl python-software-properties && \
    rm -f /var/cache/apt/archives/*.deb

RUN apt-get update && apt-get install -y php-pear s3cmd && \
    rm -f /var/cache/apt/archives/*.deb

RUN apt-get update && \
    apt-get install -y python-pip python-dev libgpgme11-dev libffi-dev libssl-dev && \
    rm -f /var/cache/apt/archives/*.deb

# libcouchbase for "couchbase" python interface
RUN mkdir /tmp/deploy && \
    cd /tmp/deploy && \
    curl -LO http://packages.couchbase.com/releases/couchbase-release/couchbase-release-1.0-2-amd64.deb && \
    dpkg -i couchbase-release-1.0-2-amd64.deb && \
    apt-get update && \
    apt-get install -y libcouchbase-dev libcouchbase2-bin && \
    cd /tmp && \
    rm -rf deploy /var/cache/apt/archives/*.deb

# Many python deps for tools and testrunner (see CBQE-3656 for some details)
RUN pip install -U setuptools && pip install -U pip
RUN apt-get purge -y python-requests
RUN pip install awscli boto3 decorator ecdsa Fabric iniparse mercurial \
    enum paramiko pycurl pygpgme urlgrabber pycrypto \
    httplib2 futures gevent greenlet btrc couchbase

# Install third-party build dependencies. Note: software-properties-common
# is only required for add-apt-repository
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:webupd8team/java && apt-get update && \
    echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections && \
    echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections && \
    apt-get install -y oracle-java8-installer && \
    rm -f /var/cache/apt/archives/*.deb

RUN mkdir /tmp/deploy && \
    curl https://cmake.org/files/v2.8/cmake-2.8.12.2-Linux-i386.sh -o /tmp/deploy/cmake.sh && \
    (echo y ; echo n) | sh /tmp/deploy/cmake.sh --prefix=/usr/local && \
    cd /tmp && rm -rf /tmp/deploy

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get install -y ruby ruby-dev libz-dev && \
    rm -f /var/cache/apt/archives/*.deb

# Expose SSH daemon and run our builder startup script
EXPOSE 22
ADD .ssh /home/couchbase/.ssh
COPY build/couchbuilder_start.sh /usr/sbin/
COPY couchhook.sh /usr/sbin/
ENTRYPOINT [ "/usr/sbin/couchbuilder_start.sh" ]
CMD [ "default" ]
