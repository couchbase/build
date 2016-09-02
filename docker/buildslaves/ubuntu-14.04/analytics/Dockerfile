# Docker container for Ubuntu 14.04 Couchbase Analytics build

# See https://github.com/ceejatec/naked-docker/ for details about the
# construction of the base image.

FROM ceejatec/naked-ubuntu:14.04
MAINTAINER ceej@couchbase.com

USER root

# Install SSH server (required to serve as Jenkins slave)
RUN apt-get update && \
    apt-get install -y openssh-server curl && \
    rm -f /var/cache/apt/archives/*.deb && \
    mkdir /var/run/sshd # update 2

# Create couchbase user with password-less sudo privs
RUN useradd couchbase -G sudo -m -s /bin/bash && \
    echo 'couchbase:couchbase' | chpasswd && \
    sed -ri 's/ALL\) ALL/ALL) NOPASSWD:ALL/' /etc/sudoers

# Oracle JDK.
RUN mkdir /tmp/deploy && \
    cd /tmp/deploy && \
    curl -L --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" \
    http://download.oracle.com/otn-pub/java/jdk/8u91-b14/jdk-8u91-linux-x64.tar.gz -o jdk.tgz && \
    cd /usr/local && \
    tar xvzf /tmp/deploy/jdk.tgz && \
    ln -s jdk* java && \
    for file in /usr/local/java/bin/*; do ln -s $file /usr/local/bin; done && \
    rm -rf /tmp/deploy
ENV JAVA_HOME=/usr/local/java

# Maven.
RUN mkdir /tmp/deploy && \
    cd /tmp/deploy && \
    curl -L http://mirror.cogentco.com/pub/apache/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz \
       -o maven.tar.gz && \
    cd /usr/local && \
    tar xzf /tmp/deploy/maven.tar.gz && \
    ln -s /usr/local/apache-maven-3.3.9/bin/mvn /usr/local/bin/mvn && \
    rm -rf /tmp/deploy

# Go (for cbq).
RUN mkdir -p /usr/local/go/1.6.3 && cd /usr/local/go/1.6.3 && \
    curl https://storage.googleapis.com/golang/go1.6.3.linux-amd64.tar.gz -o go.tar.gz && \
    tar xzf go.tar.gz && \
    rm go.tar.gz && \
    ln -s /usr/local/go/1.6.3/go/bin/go /usr/local/bin

# Expose SSH daemon and run our builder startup script
EXPOSE 22
RUN mkdir /home/couchbase/.ssh && chown couchbase:couchbase /home/couchbase/.ssh
COPY build/couchbuilder_start.sh /usr/sbin/
ENTRYPOINT [ "/usr/sbin/couchbuilder_start.sh" ]
CMD [ "default" ]

