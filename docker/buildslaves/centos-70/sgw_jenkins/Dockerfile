# Docker container for Centos 7.0

# See https://github.com/ceejatec/naked-docker/ for details about the
# construction of the base image.

FROM centos:7.0.1406
MAINTAINER build-team@couchbase.com

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

# * Required for sgcollect_info
RUN yum install --setopt=keepcache=0 -y epel-release.noarch
RUN yum install --setopt=keepcache=0 -y python-pip
RUN pip install --upgrade pip \
                -Iv PyInstaller==3.1

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

# * golang
RUN mkdir -p /usr/local/go/1.4.1 && cd /usr/local/go/1.4.1 && \
    curl https://storage.googleapis.com/golang/go1.4.1.linux-amd64.tar.gz -o go.tar.gz && \
    tar xzf go.tar.gz && \
    mkdir /usr/local/go/1.5.2 && cd /usr/local/go/1.5.2 && \
    curl https://storage.googleapis.com/golang/go1.5.2.linux-amd64.tar.gz -o go.tar.gz && \
    tar xzf go.tar.gz && \
    mkdir /usr/local/go/1.5.3 && cd /usr/local/go/1.5.3 && \
    curl https://storage.googleapis.com/golang/go1.5.3.linux-amd64.tar.gz -o go.tar.gz && \
    tar xzf go.tar.gz && \
    mkdir /usr/local/go/1.7.1 && cd /usr/local/go/1.7.1 && \
    curl https://storage.googleapis.com/golang/go1.7.1.linux-amd64.tar.gz -o go.tar.gz && \
    tar xzf go.tar.gz && \
    mkdir /usr/local/go/1.7.4 && cd /usr/local/go/1.7.4 && \
    curl https://storage.googleapis.com/golang/go1.7.4.linux-amd64.tar.gz -o go.tar.gz && \
    tar xzf go.tar.gz && \
    mkdir /usr/local/go/1.8.5 && cd /usr/local/go/1.8.5 && \
    curl https://storage.googleapis.com/golang/go1.8.5.linux-amd64.tar.gz -o go.tar.gz && \
    tar xzf go.tar.gz && \
    mkdir /usr/local/go/1.9 && cd /usr/local/go/1.9 && \
    curl https://storage.googleapis.com/golang/go1.9.linux-amd64.tar.gz -o go.tar.gz && \
    tar xzf go.tar.gz && \
    rm go.tar.gz

# * repo
RUN curl https://storage.googleapis.com/git-repo-downloads/repo -o /usr/local/bin/repo && \
    chmod a+x /usr/local/bin/repo

# Install third-party build dependencies
RUN yum install -y --setopt=keepcache=0 m4 file

# JDK for Jenkins.
RUN yum -y install java-1.7.0-openjdk && yum clean packages

# Expose SSH daemon and run our builder startup script
EXPOSE 22
ADD .ssh /home/couchbase/.ssh
COPY build/couchbuilder_start.sh /usr/sbin/
ENTRYPOINT [ "/usr/sbin/couchbuilder_start.sh" ]
CMD [ "default" ]

# Needed for sg
ADD .rpmmacros /home/couchbase/

RUN chown couchbase:couchbase /home/couchbase/.rpmmacros

