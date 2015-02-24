# Docker container for openSUSE 11.3

# See https://github.com/ceejatec/naked-docker/ for details about the
# construction of the base image.

FROM ceejatec/naked-opensuse:11.3
MAINTAINER ceej@couchbase.com

USER root
RUN zypper install -y openssh sudo && zypper clean

# Set up for SSH daemon
RUN sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config && \
    sed -ri 's/#UsePAM no/UsePAM no/g' /etc/ssh/sshd_config && \
    sed -ri 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config && \
    ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa && \
    ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa

# Create couchbase user with password-less sudo privs, and give
# ownership of /opt/couchbase
RUN groupadd -g1000 couchbase && \
    useradd couchbase -g couchbase -u1000 -G wheel -m -s /bin/bash && \
    mkdir /opt/couchbase && chown -R couchbase:couchbase /opt/couchbase && \
    echo 'couchbase:couchbase' | chpasswd && \
    sed -ri 's/ALL\) ALL/ALL) NOPASSWD:ALL/' /etc/sudoers

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
    curl https://storage.googleapis.com/golang/go1.3.3.linux-amd64.tar.gz -o /tmp/deploy/go.tar.gz && \
    cd /usr/local && tar xzf /tmp/deploy/go.tar.gz && \
    cd bin && for file in /usr/local/go/bin/*; do ln -s $file; done && \
    rm -fr /tmp/deploy

# * repo
RUN curl https://storage.googleapis.com/git-repo-downloads/repo -o /usr/local/bin/repo && \
    chmod a+x /usr/local/bin/repo

# JDK for Jenkins.
RUN zypper install -y java-1_6_0-openjdk && zypper clean

# GCC (from ceejatec/opensuse-gcc-build)
COPY build/local /usr/local
RUN  (echo "/usr/local/lib64"; cat /etc/ld.so.conf) > /tmp/ld.so.conf && \
     mv /tmp/ld.so.conf /etc && ldconfig

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
    cd /tmp && rm -rf /tmp/deploy && zypper remove -y -u curl-devel gettext-devel && zypper clean && \
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
    cd ccache-3.1.9 && ./configure --prefix=/home/couchbase && make -j8 && \
    make install && rm -rf /home/couchbase/share && \
    ln -s ccache /home/couchbase/bin/gcc && \
    ln -s ccache /home/couchbase/bin/g++ && \
    rm -fr /tmp/deploy

# Expose SSH daemon and run our builder startup script
EXPOSE 22
ADD .ssh /home/couchbase/.ssh
COPY build/couchbuilder_start.sh /usr/sbin/
ENTRYPOINT [ "/usr/sbin/couchbuilder_start.sh" ]


