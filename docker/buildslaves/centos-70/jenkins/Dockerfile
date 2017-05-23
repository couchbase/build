# Docker container for Centos 6.5

FROM centos:7.0.1406
MAINTAINER ceej@couchbase.com

USER root
RUN yum clean all && yum swap -y fakesystemd systemd

RUN yum install --setopt=keepcache=0 -y openssh-server sudo deltarpm

# Set up for SSH daemon
RUN sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config && \
    sed -ri 's/#UsePAM no/UsePAM no/g' /etc/ssh/sshd_config && \
    ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa && \
    ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa

# Create couchbase user with password-less sudo privs, and give
# ownership of /opt/couchbase
RUN groupadd -g1000 couchbase && \
    useradd couchbase -g couchbase -u1000 -G wheel -m -s /bin/bash && \
    mkdir /opt/couchbase && chown -R couchbase:couchbase /opt/couchbase && \
    echo 'couchbase:couchbase' | chpasswd && \
    echo '%wheel ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/wheel_group && \
    echo 'Defaults:%wheel !requiretty' >> /etc/sudoers.d/wheel_group && \
    chmod 440 /etc/sudoers.d/wheel_group

### Install Couchbase build dependencies ######################################
# * Packages from the base CentOS repository
RUN yum install --setopt=keepcache=0 -y \
                ed \
                gcc \
                gcc-c++ \
                git \
                glibc.i686 \
                make \
                man \
                ncurses-devel \
                numactl-devel \
                openssh-clients openssl-devel \
                python-devel \
                redhat-lsb-core \
                rpm-build \
                ruby rubygems rubygem-rake \
                tar \
                unzip \
                which && \
    ln -s /usr/bin/python2.7 /usr/bin/python2.6

# Install third-party build dependencies
RUN yum install -y --setopt=keepcache=0 perl-Data-Dumper

# Install autoconf and friends - necessary for building some third-party deps
# from source, not for Couchbase.
RUN mkdir /tmp/deploy && \
    curl -L http://ftpmirror.gnu.org/autoconf/autoconf-2.69.tar.gz -o /tmp/deploy/autoconf-2.69.tar.gz && \
    cd /tmp/deploy && tar -xzf autoconf-2.69.tar.gz && \
    cd autoconf-2.69 && ./configure --prefix=/usr/local && make -j8 && make install && \
    curl -L http://ftpmirror.gnu.org/automake/automake-1.14.tar.gz -o /tmp/deploy/automake-1.14.tar.gz && \
    cd /tmp/deploy && tar -xzf automake-1.14.tar.gz && \
    cd automake-1.14 && ./configure --prefix=/usr/local && make && make install && \
    curl -L http://ftpmirror.gnu.org/libtool/libtool-2.4.2.tar.gz -o /tmp/deploy/libtool-2.4.2.tar.gz && \
    cd /tmp/deploy && tar -xzf libtool-2.4.2.tar.gz && \
    cd libtool-2.4.2 && ./configure --prefix=/usr/local && make -j8 && make install && \
    cd /tmp && rm -rf /tmp/deploy

# paramiko for testrunner
RUN rpm -iUvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    yum install -y python-pip && \
    pip install paramiko

# * CMake (from cmake.org)
RUN mkdir /tmp/deploy && \
    curl https://cmake.org/files/v3.6/cmake-3.6.1-Linux-x86_64.sh -o /tmp/deploy/cmake.sh && \
    (echo y ; echo n) | sh /tmp/deploy/cmake.sh --prefix=/usr/local && \
    rm -fr /tmp/deploy

# * ccache (from source)
RUN mkdir /tmp/deploy && \
    curl -L https://www.samba.org/ftp/ccache/ccache-3.1.9.tar.bz2 -o /tmp/deploy/ccache.tar.bz2 && \
    cd /tmp/deploy && tar -xjf ccache.tar.bz2 && \
    cd ccache-3.1.9 && ./configure --prefix=/usr/local && make -j8 && make install && \
    ln -s ccache /usr/local/bin/gcc && \
    ln -s ccache /usr/local/bin/g++ && \
    ln -s ccache /usr/local/bin/cc && \
    ln -s ccache /usr/local/bin/c++ && \
    rm -fr /tmp/deploy

# * repo
RUN curl https://storage.googleapis.com/git-repo-downloads/repo -o /usr/local/bin/repo && \
    chmod a+x /usr/local/bin/repo

# Oracle JDK (for Jenkins and Analytics).
RUN mkdir /tmp/deploy && \
    cd /tmp/deploy && \
    curl -L --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" \
    http://download.oracle.com/otn-pub/java/jdk/8u131-b11/d54c1d3a095b4ff2b6607d096fa80163/jdk-8u131-linux-x64.tar.gz -o jdk.tgz && \
    cd /usr/local && \
    tar xvzf /tmp/deploy/jdk.tgz && \
    ln -s jdk* java && \
    for file in /usr/local/java/bin/*; do ln -s $file /usr/local/bin; done && \
    rm -rf /tmp/deploy
ENV JAVA_HOME=/usr/local/java

# Maven (for Analytics).
RUN mkdir /tmp/deploy && \
    cd /tmp/deploy && \
    curl -L http://mirror.cogentco.com/pub/apache/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz \
       -o maven.tar.gz && \
    cd /usr/local && \
    tar xzf /tmp/deploy/maven.tar.gz && \
    ln -s /usr/local/apache-maven-3.3.9/bin/mvn /usr/local/bin/mvn && \
    rm -rf /tmp/deploy

# Expose SSH daemon and run our builder startup script
EXPOSE 22
ADD .ssh /home/couchbase/.ssh
COPY build/couchbuilder_start.sh /usr/sbin/
ENTRYPOINT [ "/usr/sbin/couchbuilder_start.sh" ]
CMD [ "default" ]

