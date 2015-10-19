# Docker container for Couchbase Server Centos 6.5

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

# * repo
RUN curl https://storage.googleapis.com/git-repo-downloads/repo -o /usr/local/bin/repo && \
    chmod a+x /usr/local/bin/repo

# * git
RUN curl http://people.centos.org/tru/devtools-2/devtools-2.repo > \
         /etc/yum.repos.d/devtools-2.repo
RUN yum install -y --setopt=keepcache=0 devtoolset-2-git && \
    ln -s /opt/rh/devtoolset-2/root/usr/bin/git /usr/bin/git

# Install third-party dependencies
RUN yum install -y --setopt=keepcache=0 m4 file

# JDK for Jenkins.
RUN yum -y install java-1.7.0-openjdk && yum clean packages

### Disable Swappiness (part of Couchbase Server installation)  ############################
# Set the value for the running system
RUN echo '' >> /etc/sysctl.conf
RUN echo '#Set swappiness to 0 to avoid swapping' >> /etc/sysctl.conf
RUN echo 'vm.swappiness = 0' >> /etc/sysctl.conf

### 
#
# Include Couchbase Server Dependency 
#
###
RUN yum install -y perl
RUN yum install -y pkgconfig
#RUN yum install -y openssl098e 

RUN rpm -ivh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
RUN yum install -y python-pip
RUN pip install --upgrade pip

###
#
# Buildboard Dependency
#
###
RUN pip install BeautifulSoup \
    		beautifulsoup4 \
    		distribute \
    		Flask \
    		HTMLParser \
    		Jinja \
    		js.backbone \
    		js.underscore \
    		pycurl \
    		PyGithub

VOLUME /opt/couchbase/var
RUN export PATH=$PATH:/opt/couchbase/bin:/opt/couchbase/bin/tools:/opt/couchbase/bin/install

### 
# Install Couchbase C-SDK
# Note: If licouchbase-devel failed, try libcouchbase-dev.  libcouchbase2-libev and libevent are optional
RUN curl -o /etc/yum.repos.d/couchbase.repo http://packages.couchbase.com/rpm/couchbase-centos62-x86_64.repo
RUN yum install -y \
    libcouchbase2-libevent \
    libcouchbase-devel \
    libcouchbase2-bin
RUN pip install couchbase

### Include Apache HTTP Server ############################
RUN yum install httpd procps-ng -y

# Add configuration file
#ADD action /var/www/cgi-bin/action
#RUN chown root:apache /var/www/cgi-bin/action
#RUN chmod 755 /var/www/cgi-bin/action
COPY util/httpd.conf /etc/httpd/conf/httpd.conf
EXPOSE 8080 8082

# Expose SSH daemon and run our builder startup script
EXPOSE 22
#ADD util/.ssh /home/couchbase/.ssh
#COPY util/couchserver_start.sh /usr/sbin/

# Start the services
#ENTRYPOINT [ "/usr/sbin/couchserver_start.sh" ]
ENTRYPOINT /usr/sbin/httpd -D FOREGROUND 
