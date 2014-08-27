# Docker container for Centos 5.8

# See https://github.com/ceejatec/naked-docker/ for details about the
# construction of the base image.

FROM ceejatec/naked-centos:5.8
MAINTAINER ceej@couchbase.com

USER root
RUN yum install -y openssh-server sudo

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
    echo '%wheel ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    echo 'Defaults:%wheel !requiretty' >> /etc/sudoers
ADD .ssh /home/buildbot/.ssh
RUN chown -R buildbot:buildbot /home/buildbot/.ssh && chmod 700 /home/buildbot/.ssh

# Expose and start SSH daemon
EXPOSE 22
CMD [ "/usr/sbin/sshd", "-D" ]

# Install Couchbase build dependencies. It appears we require gcc 4.4.
# To achieve this, install the gcc44-c++ package (which brings in gcc44),
# then create symlinks in /usr/bin for cc, c++, gcc and g++. This is probably
# "not correct" but I didn't find a better way.
# Note: redhat-lsb currently required for "cbdeps" third-party build
# mechanism, but we hope to remove that requirement as it brings in a
# LOT of unnecessary packages on Centos.
RUN rpm -Uvh http://dl.fedoraproject.org/pub/epel/5/x86_64/epel-release-5-4.noarch.rpm && \
    yum install -y gcc44-c++ make git openssl-devel ruby rubygems rubygem-rake glibc.i686 ncurses-devel ed which man unzip python-devel rpm-build redhat-lsb && \
    ln -s gcc44 /usr/bin/cc && \
    ln -s gcc44 /usr/bin/gcc && \
    ln -s g++44 /usr/bin/c++ && \
    ln -s g++44 /usr/bin/g++ && \
    mkdir /tmp/deploy && \
    curl http://www.cmake.org/files/v2.8/cmake-2.8.12.2-Linux-i386.sh -o /tmp/deploy/cmake.sh && \
    (echo y; echo n) | sh /tmp/deploy/cmake.sh --prefix=/usr/local && \
    curl -L http://samba.org/ftp/ccache/ccache-3.1.9.tar.bz2 -o /tmp/deploy/ccache.tar.bz2 && \
    cd /tmp/deploy && tar -xjf ccache.tar.bz2 && \
    cd ccache-3.1.9 && ./configure --prefix=/usr/local && make -j8 && make install && \
    cd /tmp && rm -rf /tmp/deploy && \
    ln -s ccache /usr/local/bin/cc && \
    ln -s ccache /usr/local/bin/gcc && \
    ln -s ccache /usr/local/bin/c++ && \
    ln -s ccache /usr/local/bin/g++

# Install autoconf and friends - necessary for building some third-party deps
# from source, not for Couchbase. python2.6 in particular is only required
# for gyp, which is part of the v8 build.
RUN yum install -y python26 && \
    mkdir /tmp/deploy && \
    curl -L http://ftpmirror.gnu.org/autoconf/autoconf-2.69.tar.gz -o /tmp/deploy/autoconf-2.69.tar.gz && \
    cd /tmp/deploy && tar -xzf autoconf-2.69.tar.gz && \
    cd autoconf-2.69 && ./configure --prefix=/usr/local && make && make install && \
    curl -L http://ftpmirror.gnu.org/automake/automake-1.11.1.tar.gz -o /tmp/deploy/automake-1.11.1.tar.gz && \
    cd /tmp/deploy && tar -xzf automake-1.11.1.tar.gz && \
    cd automake-1.11.1 && ./configure --prefix=/usr/local && make && make install && \
    curl -L http://ftpmirror.gnu.org/libtool/libtool-2.4.2.tar.gz -o /tmp/deploy/libtool-2.4.2.tar.gz && \
    cd /tmp/deploy && tar -xzf libtool-2.4.2.tar.gz && \
    cd libtool-2.4.2 && ./configure --prefix=/usr/local && make && make install && \
    rm -rf /tmp/deploy

# Install requirements for buildbot and buildbot tasks. Note that some of
# the easy_install steps here output python SyntaxErrors, but that appears to
# be OK.
RUN yum install -y python-setuptools python-dateutil perl-libwww-perl perl-XML-Simple && \
    easy_install zope.interface==3.8.0 && \
    easy_install http://twistedmatrix.com/Releases/Twisted/11.1/Twisted-11.1.0.tar.bz2 && \
    easy_install buildbot_slave && \
    mkdir /home/buildbot/buildbot_slave && \
    buildslave create-slave /home/buildbot/buildbot_slave 10.1.1.210:9999 centos-5-builddocker-01 centos-5-builddocker-01 && \
    echo "Couchbase Build Team <build-team@couchbase.com>" > /home/buildbot/buildbot_slave/info/admin && \
    echo "Centos 5.8 x86_64 Couchbase Build Slave running in Docker" > /home/buildbot/buildbot_slave/info/host && \
    chown -R buildbot:buildbot /home/buildbot/buildbot_slave
RUN mkdir /tmp/deploy && \
    curl -L 'http://downloads.sourceforge.net/project/s3tools/s3cmd/1.5.0-rc1/s3cmd-1.5.0-rc1.tar.gz?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fs3tools%2Ffiles%2Fs3cmd%2F1.5.0-rc1%2F&ts=1406252479&use_mirror=superb-dca2' -o /tmp/deploy/s3cmd.tar.gz && \
    cd /tmp/deploy && tar -xvf s3cmd.tar.gz && cd s3cmd-1.5.0-rc1 && \
    python setup.py build && python setup.py install && \
    cd /tmp && rm -rf /tmp/deploy

ADD .s3cfg /home/buildbot/.s3cfg
RUN chown buildbot:buildbot /home/buildbot/.s3cfg

# Override default command for buildbot purposes
CMD su - buildbot -c "buildslave start /home/buildbot/buildbot_slave"; /usr/sbin/sshd -D

