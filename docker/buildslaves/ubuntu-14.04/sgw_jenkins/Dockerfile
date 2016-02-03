# Docker container for Ubuntu 14.04

# See https://github.com/ceejatec/naked-docker/ for details about the
# construction of the base image.

FROM ceejatec/naked-ubuntu:14.04
MAINTAINER michael.kwok@couchbase.com

USER root

# Install SSH server
RUN apt-get update && \
    apt-get install -y openssh-server && \
    rm -f /var/cache/apt/archives/*.deb && \
    mkdir /var/run/sshd # update

# Create couchbase user with password-less sudo privs, and give
# ownership of /opt/couchbase
RUN useradd couchbase -G sudo -m -s /bin/bash && \
    mkdir -p /opt/couchbase && chown -R couchbase:couchbase /opt/couchbase && \
    echo 'couchbase:couchbase' | chpasswd && \
    sed -ri 's/ALL\) ALL/ALL) NOPASSWD:ALL/' /etc/sudoers

RUN apt-get update

# Install Couchbase build dependencies
RUN apt-get update && apt-get install -y ccache g++ git-core tar libssl-dev ruby rake ncurses-dev python-dev devscripts debhelper ed man curl libc6-i386 && \
    rm -f /var/cache/apt/archives/*.deb
RUN ln -s /usr/bin/nodejs /usr/bin/node
RUN ln -s /usr/bin/nodejs /usr/sbin/node
RUN ln -s /usr/bin/nodejs /usr/local/bin/node
RUN echo 'PATH="/usr/lib/ccache:$PATH"' >> /home/couchbase/.profile
#RUN mkdir /tmp/deploy && \
#    curl http://www.cmake.org/files/v2.8/cmake-2.8.12.2-Linux-i386.sh -o /tmp/deploy/cmake.sh && \
#    (echo y ; echo n) | sh /tmp/deploy/cmake.sh --prefix=/usr/local && \
RUN curl https://storage.googleapis.com/git-repo-downloads/repo -o /usr/local/bin/repo && \
    chmod a+x /usr/local/bin/repo && \
    cd /tmp && rm -rf /tmp/deploy

# golang
RUN mkdir -p /usr/local/go/1.4.1 && cd /usr/local/go/1.4.1 && \
    curl https://storage.googleapis.com/golang/go1.4.1.linux-amd64.tar.gz -o go.tar.gz && \
    tar xzf go.tar.gz && \
    mkdir /usr/local/go/1.5.2 && cd /usr/local/go/1.5.2 && \
    curl https://storage.googleapis.com/golang/go1.5.2.linux-amd64.tar.gz -o go.tar.gz && \
    tar xzf go.tar.gz && \
    mkdir /usr/local/go/1.5.3 && cd /usr/local/go/1.5.3 && \
    curl https://storage.googleapis.com/golang/go1.5.3.linux-amd64.tar.gz -o go.tar.gz && \
    tar xzf go.tar.gz

# Install third-party build dependencies. Note: software-properties-common
# is only required for add-apt-repository; add-apt-repository is only
# required to get python2.6; and python2.6 is only required for gyp, which
# is part of the v8 build. python2.6 is also required for our compiling of
# pysqlite and pysnappy, and for that we even need python2.6-dev.
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:fkrull/deadsnakes && \
    apt-get update && \
    apt-get install -y m4 python2.6 python2.6-dev && \
    rm -f /var/cache/apt/archives/*.deb
RUN mkdir /tmp/deploy && \
    curl -L http://ftpmirror.gnu.org/autoconf/autoconf-2.69.tar.gz -o /tmp/deploy/autoconf-2.69.tar.gz && \
    cd /tmp/deploy && tar -xzf autoconf-2.69.tar.gz && \
    cd autoconf-2.69 && ./configure --prefix=/usr/local && make && make install && \
    curl -L http://ftpmirror.gnu.org/automake/automake-1.14.tar.gz -o /tmp/deploy/automake-1.14.tar.gz && \
    cd /tmp/deploy && tar -xzf automake-1.14.tar.gz && \
    cd automake-1.14 && ./configure --prefix=/usr/local && make && make install && \
    curl -L http://ftpmirror.gnu.org/libtool/libtool-2.4.2.tar.gz -o /tmp/deploy/libtool-2.4.2.tar.gz && \
    cd /tmp/deploy && tar -xzf libtool-2.4.2.tar.gz && \
    cd libtool-2.4.2 && ./configure --prefix=/usr/local && make && make install && \
    cd /tmp && rm -rf /tmp/deploy

# JDK for Jenkins.
RUN apt-get install -y openjdk-7-jre-headless && \
    rm -f /var/cache/apt/archives/*.deb

# Force UTF-8 support, since it seems to fail to update properly at times
RUN locale-gen en_US en_US.UTF-8 hu_HU hu_HU.UTF-8 && dpkg-reconfigure locales

# Expose SSH daemon and run our builder startup script
EXPOSE 22
ADD .ssh /home/couchbase/.ssh
COPY build/couchbuilder_start.sh /usr/sbin/
ENTRYPOINT [ "/usr/sbin/couchbuilder_start.sh" ]
CMD [ "default" ]

