# Docker container for Ubuntu 12.04

# See https://github.com/ceejatec/naked-docker/ for details about the
# construction of the base image.

FROM ceejatec/naked-ubuntu:12.04
MAINTAINER ceej@couchbase.com

USER root

# Install SSH server
RUN apt-get update && \
    apt-get install -y apt openssh-server && \
    rm -f /var/cache/apt/archives/*.deb && \
    mkdir /var/run/sshd # comment

# Create couchbase user with password-less sudo privs, and give
# ownership of /opt/couchbase
RUN useradd couchbase -G sudo -m -s /bin/bash && \
    mkdir -p /opt/couchbase && chown -R couchbase:couchbase /opt/couchbase && \
    echo 'couchbase:couchbase' | chpasswd && \
    sed -ri 's/ALL\) ALL/ALL) NOPASSWD:ALL/' /etc/sudoers

# Install Couchbase build dependencies
RUN apt-get install -y ccache git-core tar libssl-dev rubygems rake ncurses-dev python-dev devscripts debhelper ed man curl libc6-i386 && \
    rm -f /var/cache/apt/archives/*.deb

# Install updated C++11 compiler.
# Note: python-software-properties required for `add-apt-repository`.
RUN apt-get install --yes python-software-properties && \
    add-apt-repository --yes ppa:ubuntu-toolchain-r/test && \
    apt-get update && \
    apt-get install --yes g++-4.9 && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.9 50 \
                        --slave /usr/bin/g++ g++ /usr/bin/g++-4.9 \
                        --slave /usr/bin/gcov gcov /usr/bin/gcov-4.9 && \
    apt-get clean

# Enable ccache.
RUN echo 'PATH="/usr/lib/ccache:$PATH"' >> /home/couchbase/.profile

# CMake, Go and Repo.
RUN mkdir /tmp/deploy && \
    curl http://www.cmake.org/files/v2.8/cmake-2.8.12.2-Linux-i386.sh -o /tmp/deploy/cmake.sh && \
    (echo y ; echo n) | sh /tmp/deploy/cmake.sh --prefix=/usr/local && \
    curl https://storage.googleapis.com/golang/go1.4.2.linux-amd64.tar.gz -o /tmp/deploy/go.tar.gz && \
    cd /usr/local && tar xzf /tmp/deploy/go.tar.gz && \
    cd bin && for file in /usr/local/go/bin/*; do ln -s $file; done && \
    curl https://storage.googleapis.com/git-repo-downloads/repo -o /usr/local/bin/repo && \
    chmod a+x /usr/local/bin/repo && \
    cd /tmp && rm -rf /tmp/deploy && \
    ccache --clear

# Install third-party build dependencies. Note: python-software-properties
# is only required for add-apt-repository; add-apt-repository is only
# required to get python2.6; and python2.6 is only required for gyp, which
# is part of the v8 build. python2.6 is also required for our compiling of
# pysqlite and pysnappy, and for that we even need python2.6-dev.
RUN apt-get install -y python-software-properties && \
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
    cd /tmp && rm -rf /tmp/deploy && \
    ccache --clear

# JDK for Jenkins.
RUN apt-get install -y openjdk-7-jre-headless && \
    rm -f /var/cache/apt/archives/*.deb

# Valgrind needed for leak checking as part of unit tests. Note: It requires
# libc debug symbols (libc6-dbg) to ensure it can locate the address of strlen().
RUN mkdir /tmp/deploy && \
    cd /tmp/deploy && curl -L -O http://valgrind.org/downloads/valgrind-3.10.1.tar.bz2 && \
    tar -xjf valgrind-3.10.1.tar.bz2 && cd valgrind-3.10.1 && \
    ./configure --prefix=/usr/local && make && make install && \
    cd /tmp && rm -fr /tmp/deploy && \
    ccache --clear && \
    apt-get install -y libc6-dbg && \
    rm -f /var/cache/apt/archives/*.deb

# Code coverage requires gcovr to convert from gcov to XML files consumable by
# Jenkins.
RUN apt-get install -y python-pip && \
    pip install gcovr

# Expose SSH daemon and run our builder startup script
EXPOSE 22
ADD .ssh /home/couchbase/.ssh
COPY build/couchbuilder_start.sh /usr/sbin/
ENTRYPOINT [ "/usr/sbin/couchbuilder_start.sh" ]
