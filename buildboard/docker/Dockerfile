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

### Install development tools ######################################
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
                ruby rubygems rubygem-rake \
                tar \
                unzip \
                which


RUN yum install -y openssl098e 

# * repo
RUN curl https://storage.googleapis.com/git-repo-downloads/repo -o /usr/local/bin/repo && \
    chmod a+x /usr/local/bin/repo

# Install third-party dependencies
RUN yum install -y --setopt=keepcache=0 m4 file

### Disable Swappiness (part of Couchbase Server installation)  ############################
# Set the value for the running system
#RUN echo '' >> /etc/sysctl.conf
#RUN echo '#Set swappiness to 0 to avoid swapping' >> /etc/sysctl.conf
#RUN echo 'vm.swappiness = 0' >> /etc/sysctl.conf

### 
#
# Include Couchbase Server Dependency 
#
###
RUN yum install -y pkgconfig
RUN yum install -y openssl098e 

RUN rpm -ivh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
RUN yum install -y python-pip
RUN pip install --upgrade pip

###
# Buildboard library helpers
###
RUN yum install --setopt=keepcache=0 -y epel-release.noarch
RUN yum install --setopt=keepcache=0 -y python-pip
RUN pip install --upgrade pip

RUN pip install BeautifulSoup \
    		beautifulsoup4 \
    		distribute \
    		requests \
     		Flask \
     		rests['security'] \
     		virtualenv \
     		HTMLParser \
     		Jinja \
     		pycurl \
     		gitpython \
     		PyGithub
 
VOLUME /opt/couchbase/var
RUN export PATH=$PATH:/opt/couchbase/bin:/opt/couchbase/bin/tools:/opt/couchbase/bin/install
 
### 
#
# Install Couchbase C-SDK
#
###
RUN curl -O http://packages.couchbase.com/releases/couchbase-release/couchbase-release-1.0-2-x86_64.rpm
RUN rpm -iv couchbase-release-1.0-2-x86_64.rpm
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
ADD util/.ssh /home/couchbase/.ssh
COPY util/bb_start.sh /usr/sbin/
ENTRYPOINT [ "/usr/sbin/bb_start.sh" ]
CMD [ "default" ]

# Start the services
#ENTRYPOINT /usr/sbin/httpd -D FOREGROUND 
