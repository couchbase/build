# Docker container for Ubuntu 10.04

# See https://github.com/ceejatec/naked-docker/ for details about the
# construction of the base image.

FROM ceejatec/naked-ubuntu:10.04
MAINTAINER ceej@couchbase.com

USER root

# Install SSH server
RUN apt-get install -y openssh-server; mkdir /var/run/sshd

# Create user to login, and give access to /opt/couchbase
RUN useradd buildbot -G sudo -m -s /bin/bash; \
    mkdir -p /opt/couchbase; chown -R buildbot:buildbot /opt/couchbase
ADD .ssh /home/buildbot/.ssh
RUN chown -R buildbot:buildbot /home/buildbot/.ssh; chmod 700 /home/buildbot/.ssh

# Expose and start SSH daemon
EXPOSE 22
CMD [ "/usr/sbin/sshd", "-D" ]

# Install Couchbase build dependencies
RUN apt-get install -y g++ git-core tar libssl-dev rubygems rake ncurses-dev python-dev devscripts debhelper ed man curl libc6-i386
RUN mkdir /tmp/deploy; \
    curl http://www.cmake.org/files/v2.8/cmake-2.8.12.2-Linux-i386.sh -o /tmp/deploy/cmake.sh; \
    (echo y; echo n) | sh /tmp/deploy/cmake.sh --prefix=/usr/local; \
    rm -rf /tmp/deploy

# Install third-party build dependencies
RUN apt-get install -y m4
RUN mkdir /tmp/deploy; \
    curl -L http://ftpmirror.gnu.org/autoconf/autoconf-2.69.tar.gz -o /tmp/deploy/autoconf-2.69.tar.gz; \
    cd /tmp/deploy; tar -xzf autoconf-2.69.tar.gz; \
    cd autoconf-2.69 && ./configure --prefix=/usr/local && make && make install; \
    curl -L http://ftpmirror.gnu.org/automake/automake-1.11.1.tar.gz -o /tmp/deploy/automake-1.11.1.tar.gz; \
    cd /tmp/deploy; tar -xzf automake-1.11.1.tar.gz; \
    cd automake-1.11.1 && ./configure --prefix=/usr/local && make && make install; \
    curl -L http://ftpmirror.gnu.org/libtool/libtool-2.4.2.tar.gz -o /tmp/deploy/libtool-2.4.2.tar.gz; \
    cd /tmp/deploy; tar -xzf libtool-2.4.2.tar.gz; \
    cd libtool-2.4.2 && ./configure --prefix=/usr/local && make && make install; \
    rm -rf /tmp/deploy
