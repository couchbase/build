# Docker container for Centos 6.4

# See https://github.com/ceejatec/naked-docker/ for details about the
# construction of the base image.

FROM ceejatec/naked-centos:6.4
MAINTAINER ceej@couchbase.com

USER root
RUN yum install -y openssh-server sudo

# Set up for SSH daemon
RUN sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config; \
    sed -ri 's/#UsePAM no/UsePAM no/g' /etc/ssh/sshd_config; \
    /etc/init.d/sshd start

# Create user to login, and give access to /opt/couchbase
RUN useradd jenkins -G wheel; \
    echo 'jenkins:jenkins' | chpasswd; \
    echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers; \
    mkdir -p /home/jenkins/.ssh; chown -R jenkins:jenkins /home/jenkins/.ssh; chmod 700 /home/jenkins/.ssh; \
    mkdir -p /opt/couchbase; chown -R jenkins:jenkins /opt/couchbase

# Expose and start SSH daemon
EXPOSE 22
CMD [ "/usr/sbin/sshd", "-D" ]

# Install Couchbase build dependencies
RUN yum install -y gcc-c++ make git tar openssl-devel ruby rubygems rubygem-rake tar glibc.i686 ncurses-devel ed which man unzip python-devel rpm-build
RUN mkdir /tmp/deploy; \
    curl http://www.cmake.org/files/v2.8/cmake-2.8.12.2-Linux-i386.sh -o /tmp/deploy/cmake.sh; \
    (echo y; echo n) | sh /tmp/deploy/cmake.sh --prefix=/usr/local; \
    rm -rf /tmp/deploy

# Install third-party build dependencies
RUN yum install -y m4 file
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
