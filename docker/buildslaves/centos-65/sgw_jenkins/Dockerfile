# Docker container for Centos 6.5

# See https://github.com/ceejatec/naked-docker/ for details about the
# construction of the base image.

FROM ceejatec/naked-centos:6.5
MAINTAINER michael.kwok@couchbase.com

USER root
RUN yum install -y openssh-server sudo && yum clean packages

# Set up for SSH daemon
RUN sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config && \
    sed -ri 's/#UsePAM no/UsePAM no/g' /etc/ssh/sshd_config && \
    /etc/init.d/sshd start

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
                glibc.i686 \
                make \
                man \
                ncurses-devel \
                openssh-clients openssl-devel \
                python-devel \
                redhat-lsb-core \
                rpm-build \
                ruby rubygems rubygem-rake \
                tar \
                unzip \
                which

# * Required for sgcollect_info
RUN yum install --setopt=keepcache=0 -y epel-release.noarch
RUN yum install --setopt=keepcache=0 -y python-pip
RUN pip install --upgrade pip \
                -Iv PyInstaller==3.1

# * C++11 compliant compiler and related tools from CentOS's port of RHEL's
#    devtools (http://people.centos.org/tru/devtools-2/)
RUN curl http://people.centos.org/tru/devtools-2/devtools-2.repo > \
         /etc/yum.repos.d/devtools-2.repo && \
    yum install --setopt=keepcache=0 -y \
                devtoolset-2-gcc-c++ \
                devtoolset-2-binutils && \
    ln -s /opt/rh/devtoolset-2/root/usr/bin/as /usr/local/bin/as && \
    ln -s /opt/rh/devtoolset-2/root/usr/bin/gcc /usr/bin/gcc && \
    ln -s /opt/rh/devtoolset-2/root/usr/bin/cc /usr/bin/cc && \
    ln -s /opt/rh/devtoolset-2/root/usr/bin/g++ /usr/bin/g++ && \
    ln -s /opt/rh/devtoolset-2/root/usr/bin/c++ /usr/bin/c++

# * CMake (from cmake.org)
RUN mkdir /tmp/deploy && \
    curl http://www.cmake.org/files/v2.8/cmake-2.8.12.2-Linux-i386.sh -o /tmp/deploy/cmake.sh && \
    (echo y; echo n) | sh /tmp/deploy/cmake.sh --prefix=/usr/local && \
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

# * golang
RUN mkdir -p /usr/local/go/1.4.1 && cd /usr/local/go/1.4.1 && \
    curl https://storage.googleapis.com/golang/go1.4.1.linux-amd64.tar.gz -o go.tar.gz && \
    tar xzf go.tar.gz && \
    mkdir /usr/local/go/1.5.2 && cd /usr/local/go/1.5.2 && \
    curl https://storage.googleapis.com/golang/go1.5.2.linux-amd64.tar.gz -o go.tar.gz && \
    tar xzf go.tar.gz && \
    mkdir /usr/local/go/1.5.3 && cd /usr/local/go/1.5.3 && \
    curl https://storage.googleapis.com/golang/go1.5.3.linux-amd64.tar.gz -o go.tar.gz && \
    tar xzf go.tar.gz

# * golang
#RUN mkdir /tmp/deploy && \
#    curl https://storage.googleapis.com/golang/go1.4.1.linux-amd64.tar.gz -o /tmp/deploy/go.tar.gz && \
#    cd /usr/local && tar xzf /tmp/deploy/go.tar.gz && \
#    cd bin && for file in /usr/local/go/bin/*; do ln -s $file; done && \
#    rm -fr /tmp/deploy

# * repo
RUN curl https://storage.googleapis.com/git-repo-downloads/repo -o /usr/local/bin/repo && \
    chmod a+x /usr/local/bin/repo

# * git
RUN yum install -y --setopt=keepcache=0 devtoolset-2-git && \
    ln -s /opt/rh/devtoolset-2/root/usr/bin/git /usr/local/bin/git

# Install third-party build dependencies
RUN yum install -y --setopt=keepcache=0 m4 file

# Install autoconf and friends - necessary for building some third-party deps
# from source, not for Couchbase.
RUN mkdir /tmp/deploy && \
    curl -L http://ftpmirror.gnu.org/autoconf/autoconf-2.69.tar.gz -o /tmp/deploy/autoconf-2.69.tar.gz && \
    cd /tmp/deploy && tar -xzf autoconf-2.69.tar.gz && \
    cd autoconf-2.69 && ./configure --prefix=/usr/local && make -j8 && make install && \
    yum install -y --setopt=keepcache=0 automake-1.11.1 && \
    curl -L http://ftpmirror.gnu.org/libtool/libtool-2.4.2.tar.gz -o /tmp/deploy/libtool-2.4.2.tar.gz && \
    cd /tmp/deploy && tar -xzf libtool-2.4.2.tar.gz && \
    cd libtool-2.4.2 && ./configure --prefix=/usr/local && make -j8 && make install && \
    cd /tmp && rm -rf /tmp/deploy && ccache --clear

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

