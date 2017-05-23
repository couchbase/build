# Docker container for openSUSE 11.3

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
                libnuma-devel \
                libopenssl-devel \
                python-devel \
                lsb-release \
                ruby rubygems rubygem-rake \
                tar \
                unzip && \
                zypper clean

# GCC (from ceejatec/opensuse-gcc-build)
COPY build/local /usr/local
RUN  (echo "/usr/local/lib64"; cat /etc/ld.so.conf) > /tmp/ld.so.conf && \
     mv /tmp/ld.so.conf /etc && ldconfig && \
     ln -s gcc /usr/local/bin/cc

#paramiko for testrunner
RUN zypper install -y python-paramiko && zypper clean

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

# * ccache (from source)
RUN mkdir /tmp/deploy && \
    curl -L https://www.samba.org/ftp/ccache/ccache-3.1.9.tar.bz2 -o /tmp/deploy/ccache.tar.bz2 && \
    cd /tmp/deploy && tar -xjf ccache.tar.bz2 && \
    cd ccache-3.1.9 && ./configure --prefix=/home/couchbase && make -j8 && \
    make install && rm -rf /home/couchbase/share && \
    ln -s ccache /home/couchbase/bin/gcc && \
    ln -s ccache /home/couchbase/bin/g++ && \
    ln -s ccache /home/couchbase/bin/cc && \
    ln -s ccache /home/couchbase/bin/c++ && \
    rm -fr /tmp/deploy

# * repo
RUN curl https://storage.googleapis.com/git-repo-downloads/repo -o /usr/local/bin/repo && \
    chmod a+x /usr/local/bin/repo && \
    zypper install -y python-xml && zypper clean

# * CMake (from cmake.org)
RUN mkdir /tmp/deploy && cd /tmp/deploy && \
    curl -LO https://www.cmake.org/files/v3.6/cmake-3.6.1.tar.gz && \
    tar xzf cmake-3.6.1.tar.gz && \
    cd cmake-3.6.1 && ./configure --prefix=/usr/local --no-system-libs && \
    make -j8 all && make install && \
    cd /tmp && rm -rf /tmp/deploy

# Oracle JDK (for Jenkins and Analytics).
RUN mkdir /tmp/deploy && \
    cd /tmp/deploy && \
    curl -L --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" \
    http://download.oracle.com/otn-pub/java/jdk/8u121-b13/e9e7ea248e2c4826b92b3f075a80e441/jdk-8u121-linux-x64.tar.gz -o jdk.tgz && \
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



