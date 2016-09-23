# Docker container for Ubuntu 14.04

# See https://github.com/ceejatec/naked-docker/ for details about the
# construction of the base image.

FROM ceejatec/naked-ubuntu:14.04
MAINTAINER hari.kodungallur@couchbase.com

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

# JDK for Jenkins.
RUN apt-get update && \
    apt-get install -y openjdk-7-jre-headless && \
    rm -f /var/cache/apt/archives/*.deb

RUN apt-get update && \
    apt-get install -y build-essential git autoconf cmake libevent-dev g++-multilib

RUN apt-get update && apt-get install -y unzip zip tar wget curl python-software-properties && \
    rm -f /var/cache/apt/archives/*.deb

RUN apt-get update && apt-get install -y php-pear s3cmd && \
    rm -f /var/cache/apt/archives/*.deb

RUN apt-get update && \
    apt-get install -y python-pip python-dev

RUN pip install awscli
RUN pip install boto3


# Install third-party build dependencies. Note: software-properties-common
# is only required for add-apt-repository
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:webupd8team/java && apt-get update && \
    echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections && \
    echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections && \
    apt-get install -y oracle-java7-installer && \
    rm -f /var/cache/apt/archives/*.deb

RUN mkdir /tmp/deploy && \
    curl https://cmake.org/files/v2.8/cmake-2.8.12.2-Linux-i386.sh -o /tmp/deploy/cmake.sh && \
    (echo y ; echo n) | sh /tmp/deploy/cmake.sh --prefix=/usr/local && \
    cd /tmp && rm -rf /tmp/deploy

ENV DEBIAN_FRONTEND noninteractive


#paramiko for testrunner
RUN apt-get update && \
    apt-get install -y python-paramiko

# Expose SSH daemon and run our builder startup script
EXPOSE 22
ADD .ssh /home/couchbase/.ssh
COPY build/couchbuilder_start.sh /usr/sbin/
ENTRYPOINT [ "/usr/sbin/couchbuilder_start.sh" ]
CMD [ "default" ]
