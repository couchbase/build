# Docker container for openSUSE 11.2

# See https://github.com/ceejatec/naked-docker/ for details about the
# construction of the base image.

FROM ceejatec/naked-opensuse:11.2
MAINTAINER ceej@couchbase.com

USER root
RUN zypper install -y openssh sudo && zypper clean

# Set up for SSH daemon
RUN sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config && \
    sed -ri 's/#UsePAM no/UsePAM no/g' /etc/ssh/sshd_config && \
    sed -ri 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config && \
    ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa && \
    ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa

# Create buildbot user with password-less sudo privs, and give
# ownership of /opt/buildbot
RUN groupadd -g1000 buildbot && \
    useradd buildbot -g buildbot -u1000 -G wheel -m -s /bin/bash && \
    mkdir /opt/buildbot && chown -R buildbot:buildbot /opt/buildbot && \
    echo 'buildbot:buildbot' | chpasswd && \
    sed -ri 's/ALL\) ALL/ALL) NOPASSWD:ALL/' /etc/sudoers

ADD .ssh /home/buildbot/.ssh
RUN chown -R buildbot:buildbot /home/buildbot/.ssh && \
    chmod 700 /home/buildbot/.ssh && \
    chmod 600 /home/buildbot/.ssh/*

### Install Couchbase build dependencies ######################################
# * Packages from the base CentOS repository
RUN zypper install -y \
                binutils \
                curl \
                ed \
                make \
                man \
                ncurses-devel \
                libopenssl-devel \
                python-devel \
                lsb-release \
                ruby rubygems rubygem-rake \
                tar \
                unzip && \
                zypper clean

# * golang
RUN mkdir /tmp/deploy && \
    curl https://storage.googleapis.com/golang/go1.4.2.linux-amd64.tar.gz -o /tmp/deploy/go.tar.gz && \
    cd /usr/local && tar xzf /tmp/deploy/go.tar.gz && \
    cd bin && for file in /usr/local/go/bin/*; do ln -s $file; done && \
    rm -fr /tmp/deploy

# * repo
RUN curl https://storage.googleapis.com/git-repo-downloads/repo -o /usr/local/bin/repo && \
    chmod a+x /usr/local/bin/repo && \
    zypper install -y python-xml && zypper clean

# GCC (from ceejatec/opensuse-gcc-build)
COPY build/local /usr/local
RUN  (echo "/usr/local/lib64"; cat /etc/ld.so.conf) > /tmp/ld.so.conf && \
     mv /tmp/ld.so.conf /etc && ldconfig && \
     ln -s gcc /usr/local/bin/cc

# * CMake (from cmake.org)
RUN mkdir /tmp/deploy && cd /tmp/deploy && \
    curl -O http://www.cmake.org/files/v3.1/cmake-3.1.3.tar.gz && \
    tar xzf cmake-3.1.3.tar.gz && \
    cd cmake-3.1.3 && ./configure --prefix=/usr/local --no-system-libs && \
    make -j8 all && make install && \
    cd /tmp && rm -rf /tmp/deploy

# * git
RUN mkdir /tmp/deploy && \
    zypper install -y curl-devel gettext-tools && \
    curl https://www.kernel.org/pub/software/scm/git/git-1.9.4.tar.gz -o /tmp/deploy/git.tar.gz && \
    cd /tmp/deploy && tar xzf git.tar.gz && \
    cd git-1.9.4 && ./configure && make -j8 NO_PERL=YesPlease && make NO_PERL=YesPlease install && \
    cd /tmp && rm -rf /tmp/deploy && \
    zypper remove -y cvs gettext-runtime curl-devel gettext-devel gettext-tools libcurl-devel libgomp44 tcsh && \
    zypper clean && \
    cd /usr/local/libexec/git-core && \
    find . -samefile git -name 'git-*' -exec ln -sf git {} \; && \
    find . -samefile git-remote-ftp -name 'git-*' -exec ln -sf git-remote-ftp {} \; && \
    (strip * || true) && \
    ln -s /usr/local/bin/git /usr/bin/git

# Install autoconf and friends - necessary for building some third-party deps
# from source, not for Couchbase. (The "full" version of perl is also required
# for some third-party builds, so don't remove that after building libtool.)
RUN zypper install -y perl && \
    mkdir /tmp/deploy && \
    curl -L http://ftp.gnu.org/gnu/m4/m4-1.4.17.tar.bz2 -o /tmp/deploy/m4-1.4.17.tar.bz2 && \
    cd /tmp/deploy && tar -xjf m4-1.4.17.tar.bz2 && \
    cd m4-1.4.17 && ./configure --prefix=/usr/local && make -j8 && make install && \
    curl -L http://ftpmirror.gnu.org/autoconf/autoconf-2.69.tar.gz -o /tmp/deploy/autoconf-2.69.tar.gz && \
    cd /tmp/deploy && tar -xzf autoconf-2.69.tar.gz && \
    cd autoconf-2.69 && ./configure --prefix=/usr/local && make -j8 && make install && \
    curl -L http://ftpmirror.gnu.org/automake/automake-1.14.tar.gz -o /tmp/deploy/automake-1.14.tar.gz && \
    cd /tmp/deploy && tar -xzf automake-1.14.tar.gz && \
    cd automake-1.14 && ./configure --prefix=/usr/local && make && make install && \
    curl -L http://ftpmirror.gnu.org/libtool/libtool-2.4.2.tar.gz -o /tmp/deploy/libtool-2.4.2.tar.gz && \
    cd /tmp/deploy && tar -xzf libtool-2.4.2.tar.gz && \
    cd libtool-2.4.2 && ./configure --prefix=/usr/local && make -j8 && make install && \
    cd /tmp && rm -rf /tmp/deploy && zypper clean

# * ccache (from source)
RUN mkdir /tmp/deploy && \
    curl -L https://www.samba.org/ftp/ccache/ccache-3.1.9.tar.bz2 -o /tmp/deploy/ccache.tar.bz2 && \
    cd /tmp/deploy && tar -xjf ccache.tar.bz2 && \
    cd ccache-3.1.9 && ./configure --prefix=/home/buildbot && make -j8 && \
    make install && rm -rf /home/buildbot/share && \
    ln -s ccache /home/buildbot/bin/gcc && \
    ln -s ccache /home/buildbot/bin/g++ && \
    ln -s ccache /home/buildbot/bin/cc && \
    ln -s ccache /home/buildbot/bin/c++ && \
    rm -fr /tmp/deploy

# Install requirements for buildbot and buildbot tasks
RUN zypper install -y python-setuptools python-dateutil perl-libwww-perl perl-XML-Simple && \
    easy_install buildbot_slave && \
    mkdir /home/buildbot/buildbot_slave && \
    buildslave create-slave /home/buildbot/buildbot_slave 10.1.1.210:9999 suse-11-builddocker-01 suse-11-builddocker-01 && \
    echo "Couchbase Build Team <build-team@couchbase.com>" > /home/buildbot/buildbot_slave/info/admin && \
    echo "SUSE 11 x86_64 Couchbase Build Slave running in Docker" > /home/buildbot/buildbot_slave/info/host && \
    chown -R buildbot:buildbot /home/buildbot/buildbot_slave && \
    zypper clean
RUN mkdir /tmp/deploy && \
    curl -L 'http://downloads.sourceforge.net/project/s3tools/s3cmd/1.5.0-rc1/s3cmd-1.5.0-rc1.tar.gz?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fs3tools%2Ffiles%2Fs3cmd%2F1.5.0-rc1%2F&ts=1406252479&use_mirror=superb-dca2' -o /tmp/deploy/s3cmd.tar.gz && \
    cd /tmp/deploy && tar -xvf s3cmd.tar.gz && cd s3cmd-1.5.0-rc1 && \
    python setup.py build && python setup.py install && \
    cd /tmp && rm -rf /tmp/deploy

ADD .s3cfg /home/buildbot/.s3cfg
RUN chown buildbot:buildbot /home/buildbot/.s3cfg

# Expose SSH daemon and run our builder startup script
EXPOSE 22

# Override default command for buildbot purposes
CMD su - buildbot -c "buildslave start /home/buildbot/buildbot_slave"; /usr/sbin/sshd -D

