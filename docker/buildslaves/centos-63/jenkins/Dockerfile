# Docker container for Centos 6.3

# See https://github.com/ceejatec/naked-docker/ for details about the
# construction of the base image.

FROM ceejatec/naked-centos:6.3
MAINTAINER ceej@couchbase.com

USER root
RUN yum install -y openssh-server sudo && yum clean packages

# Set up for SSH daemon
RUN sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config && \
    sed -ri 's/#UsePAM no/UsePAM no/g' /etc/ssh/sshd_config && \
    /etc/init.d/sshd start

# Create buildbot user with password-less sudo privs, and give
# ownership of /opt/couchbase
RUN groupadd -g1000 buildbot && \
    useradd buildbot -g buildbot -u1000 -G wheel -m -s /bin/bash && \
    mkdir /opt/couchbase && chown -R buildbot:buildbot /opt/couchbase && \
    echo 'buildbot:buildbot' | chpasswd && \
    echo '%wheel ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/wheel_group && \
    echo 'Defaults:%wheel !requiretty' >> /etc/sudoers.d/wheel_group && \
    chmod 440 /etc/sudoers.d/wheel_group
ADD .ssh /home/buildbot/.ssh
RUN chown -R buildbot:buildbot /home/buildbot/.ssh && \
    chmod 700 /home/buildbot/.ssh && \
    chmod 600 /home/buildbot/.ssh/*

# Expose and start SSH daemon
EXPOSE 22
CMD [ "/usr/sbin/sshd", "-D" ]

# Install Couchbase build dependencies.
# Note: redhat-lsb currently required for "cbdeps" third-party build
# mechanism, but we hope to remove that requirement as it brings in a
# LOT of unnecessary packages on Centos.
RUN yum install -y gcc-c++ make tar openssl-devel ruby rubygems rubygem-rake tar glibc.i686 \
    ncurses-devel ed which man unzip python-devel rpm-build openssh-clients redhat-lsb && \
    yum clean packages
RUN mkdir /tmp/deploy && \
    curl http://www.cmake.org/files/v2.8/cmake-2.8.12.2-Linux-i386.sh -o /tmp/deploy/cmake.sh && \
    (echo y; echo n) | sh /tmp/deploy/cmake.sh --prefix=/usr/local && \
    curl -L http://samba.org/ftp/ccache/ccache-3.1.9.tar.bz2 -o /tmp/deploy/ccache.tar.bz2 && \
    cd /tmp/deploy && tar -xjf ccache.tar.bz2 && \
    cd ccache-3.1.9 && ./configure --prefix=/usr/local && make -j && make install && \
    ln -s ccache /usr/local/bin/gcc && \
    ln -s ccache /usr/local/bin/g++ && \
    ln -s ccache /usr/local/bin/cc && \
    ln -s ccache /usr/local/bin/c++ && \
    ln -s ccache /usr/local/bin/x86_64-redhat-linux-c++ && \
    ln -s ccache /usr/local/bin/x86_64-redhat-linux-g++ && \
    ln -s ccache /usr/local/bin/x86_64-redhat-linux-gcc && \
    curl https://storage.googleapis.com/golang/go1.3.3.linux-amd64.tar.gz -o /tmp/deploy/go.tar.gz && \
    cd /usr/local && tar xzf /tmp/deploy/go.tar.gz && \
    cd bin && for file in /usr/local/go/bin/*; do ln -s $file; done && \
    curl https://storage.googleapis.com/git-repo-downloads/repo -o /usr/local/bin/repo && \
    chmod a+x /usr/local/bin/repo && \
    rm -rf /tmp/deploy

# Centos 6 only includes git 1.7.1. Recent versions of repo require
# 1.7.2.  It's like they planned to be evil. EPEL has no newer
# version, and Repoforge didn't seem to work. So, we have to build
# from source. Theoretically there are several build pre-requisites to
# install, but in practice they don't seem necessary other than curl-dev.
RUN mkdir /tmp/deploy && \
    yum install -y curl-devel && \
    curl https://www.kernel.org/pub/software/scm/git/git-1.9.4.tar.gz -o /tmp/deploy/git.tar.gz && \
    cd /tmp/deploy && tar xzf git.tar.gz && \
    cd git-1.9.4 && ./configure && make -j && make install && \
    cd /tmp && rm -rf /tmp/deploy && yum erase -y curl-devel autoconf automake libidn-devel && \
    cd /usr/local/libexec/git-core && \
    find . -samefile git -name 'git-*' -exec ln -sf git {} \; && \
    find . -samefile git-remote-ftp -name 'git-*' -exec ln -sf git-remote-ftp {} \; && \
    (strip * || true)


# Install third-party build dependencies
RUN yum install -y m4 file && yum clean packages

# Install autoconf and friends - necessary for building some third-party deps
# from source, not for Couchbase.
RUN mkdir /tmp/deploy && \
    curl -L http://ftpmirror.gnu.org/autoconf/autoconf-2.69.tar.gz -o /tmp/deploy/autoconf-2.69.tar.gz && \
    cd /tmp/deploy && tar -xzf autoconf-2.69.tar.gz && \
    cd autoconf-2.69 && ./configure --prefix=/usr/local && make -j && make install && \
    curl -L http://ftpmirror.gnu.org/automake/automake-1.11.1.tar.gz -o /tmp/deploy/automake-1.11.1.tar.gz && \
    cd /tmp/deploy && tar -xzf automake-1.11.1.tar.gz && \
    cd automake-1.11.1 && ./configure --prefix=/usr/local && make -j && make install && \
    curl -L http://ftpmirror.gnu.org/libtool/libtool-2.4.2.tar.gz -o /tmp/deploy/libtool-2.4.2.tar.gz && \
    cd /tmp/deploy && tar -xzf libtool-2.4.2.tar.gz && \
    cd libtool-2.4.2 && ./configure --prefix=/usr/local && make -j && make install && \
    cd /tmp && rm -rf /tmp/deploy

# JDK for Jenkins.
RUN yum -y install java-1.7.0-openjdk && yum clean packages

# Configure user "buildbot" for git.
USER buildbot
git config --global user.email "build-team@couchase.com"
git config --global user.name "Couchbase Build Team"
git config --global color.ui false
