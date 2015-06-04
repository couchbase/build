# Docker container for Centos 6.3

# See https://github.com/ceejatec/naked-docker/ for details about the
# construction of the base image.

FROM ceejatec/naked-centos:6.3
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
RUN yum install -y gcc-c++ make git tar openssl-devel ruby rubygems rubygem-rake tar glibc.i686 ncurses-devel ed which man unzip python-devel rpm-build redhat-lsb
RUN mkdir /tmp/deploy && \
    curl http://www.cmake.org/files/v2.8/cmake-2.8.12.2-Linux-i386.sh -o /tmp/deploy/cmake.sh && \
    (echo y; echo n) | sh /tmp/deploy/cmake.sh --prefix=/usr/local && \
    curl -L https://www.samba.org/ftp/ccache/ccache-3.1.9.tar.bz2 -o /tmp/deploy/ccache.tar.bz2 && \
    cd /tmp/deploy && tar -xjf ccache.tar.bz2 && \
    cd ccache-3.1.9 && ./configure --prefix=/usr/local && make -j8 && make install && \
    cd /tmp && rm -rf /tmp/deploy && \
    ln -s ccache /usr/local/bin/gcc && \
    ln -s ccache /usr/local/bin/g++ && \
    ln -s ccache /usr/local/bin/cc && \
    ln -s ccache /usr/local/bin/c++ && \
    ln -s ccache /usr/local/bin/x86_64-redhat-linux-c++ && \
    ln -s ccache /usr/local/bin/x86_64-redhat-linux-g++ && \
    ln -s ccache /usr/local/bin/x86_64-redhat-linux-gcc

# Install third-party build dependencies
RUN yum install -y m4 file

# Install autoconf and friends - necessary for building some third-party deps
# from source, not for Couchbase.
RUN mkdir /tmp/deploy && \
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

# Install requirements for buildbot and buildbot tasks
RUN yum install -y python-setuptools python-dateutil perl-libwww-perl perl-XML-Simple && \
    easy_install buildbot_slave && \
    mkdir /home/buildbot/buildbot_slave && \
    buildslave create-slave /home/buildbot/buildbot_slave 10.1.1.210:9999 centos-6-builddocker-01 centos-6-builddocker-01 && \
    echo "Couchbase Build Team <build-team@couchbase.com>" > /home/buildbot/buildbot_slave/info/admin && \
    echo "Centos 6.3 x86_64 Couchbase Build Slave running in Docker" > /home/buildbot/buildbot_slave/info/host && \
    chown -R buildbot:buildbot /home/buildbot/buildbot_slave
RUN mkdir /tmp/deploy && \
    curl -L 'http://downloads.sourceforge.net/project/s3tools/s3cmd/1.5.0-rc1/s3cmd-1.5.0-rc1.tar.gz?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fs3tools%2Ffiles%2Fs3cmd%2F1.5.0-rc1%2F&ts=1406252479&use_mirror=superb-dca2' -o /tmp/deploy/s3cmd.tar.gz && \
    cd /tmp/deploy && tar -xvf s3cmd.tar.gz && cd s3cmd-1.5.0-rc1 && \
    python setup.py build && python setup.py install && \
    cd /tmp && rm -rf /tmp/deploy

# Install gosu for startup script
RUN gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && curl -o /usr/local/bin/gosu -sSL "https://github.com/tianon/gosu/releases/download/1.4/gosu-amd64" \
    && curl -o /usr/local/bin/gosu.asc -sSL "https://github.com/tianon/gosu/releases/download/1.4/gosu-amd64.asc" \
    && gpg --verify /usr/local/bin/gosu.asc \
    && rm /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu

ADD .s3cfg /home/buildbot/.s3cfg
RUN chown buildbot:buildbot /home/buildbot/.s3cfg

# Override default command for buildbot purposes
COPY centos_start.sh /usr/sbin/
ENTRYPOINT [ "/usr/sbin/centos_start.sh" ]

