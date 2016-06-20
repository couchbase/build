# Docker container for Ubuntu 14.04

# See https://github.com/ceejatec/naked-docker/ for details about the
# construction of the base image.

FROM ceejatec/naked-ubuntu:14.04
MAINTAINER michael.kwok@couchbase.com

USER root

# Install SSH server
RUN apt-get update && \
    apt-get install -y openssh-server && \
    rm -f /var/cache/apt/archives/*.deb && \
    mkdir /var/run/sshd # update

# Create couchbase user with password-less sudo privs, and give 
# ownership of /opt/couchbase
RUN useradd couchbase -G sudo -m -s /bin/bash && \
    mkdir -p /opt/couchbase && chown -R couchbase:couchbase /opt/couchbase && \
    echo 'couchbase:couchbase' | chpasswd && \
    sed -ri 's/ALL\) ALL/ALL) NOPASSWD:ALL/' /etc/sudoers

# Expose and start SSH daemon
EXPOSE 22
CMD [ "/usr/sbin/sshd", "-D" ]

# Install Couchbase Mobile build dependencies. We don't need "go" or "repo"
# yet, but we probably will.
RUN apt-get update && \
    apt-get install -y ccache git-core ed man curl ccache gcc-multilib g++-multilib lib32z1 lib32stdc++6 npm bc && \
    rm -f /var/cache/apt/archives/*.deb
RUN ln -s /usr/bin/nodejs /usr/bin/node
RUN ln -s /usr/bin/nodejs /usr/sbin/node
RUN ln -s /usr/bin/nodejs /usr/local/bin/node
RUN echo 'PATH="/usr/lib/ccache:$PATH"' >> /home/couchbase/.profile
RUN mkdir /tmp/deploy && \
    curl https://storage.googleapis.com/golang/go1.4.1.linux-amd64.tar.gz -o /tmp/deploy/go.tar.gz && \
    cd /usr/local && tar xzf /tmp/deploy/go.tar.gz && \
    cd bin && for file in /usr/local/go/bin/*; do ln -s $file; done && \
    curl https://storage.googleapis.com/git-repo-downloads/repo -o /usr/local/bin/repo && \
    chmod a+x /usr/local/bin/repo && \
    cd /tmp && rm -rf /tmp/deploy

# Node.js dependency to build phonegap-plugin
RUN npm install xmlbuilder
RUN npm install findit
RUN npm install ncp
RUN echo yes | apt-get install zip

# JDK for Jenkins.
RUN apt-get update && \
    apt-get install -y openjdk-7-jdk maven unzip && \
    rm -f /var/cache/apt/archives/*.deb

# CLANG compiler
RUN apt-get install -y clang-3.6

# Android SDK/CLANG environment settings
RUN echo 'export ANDROID_NDK_HOME="/home/couchbase/jenkins/tools/android-ndk-r10e"\nexport ANDROID_HOME="/home/couchbase/jenkins/tools/android-sdk"\nexport ANDROID_SDK_HOME="/home/couchbase/jenkins/tools/android-sdk"\nexport PATH="/usr/lib/llvm-3.6/bin:$ANDROID_NDK_HOME:$ANDROID_SDK_HOME:$ANDROID_SDK_HOME/tools:$ANDROID_SDK_HOME/platform-tools:$PATH"' > /etc/profile.d/android.sh

# Android SDK
USER couchbase
RUN mkdir -p /home/couchbase/jenkins/tools && \
    cd /home/couchbase/jenkins/tools && \
    curl -L http://dl.google.com/android/android-sdk_r24.4.1-linux.tgz -o android-sdk.tgz && \
    tar xzf android-sdk.tgz && \
    mv android-sdk-linux android-sdk && \
    chown -R couchbase:couchbase android-sdk && \
    chmod 755 android-sdk

RUN . /etc/profile && \
    echo yes | android update sdk --filter platform-tools,android-19,extra --no-ui --force --all && \
    filter=`android list sdk --all | grep Build-tools | grep 19.1 | awk '{ print $1 }' | tr -d -` && \
    echo yes | android update sdk --filter $filter --no-ui --force --all && \
    echo yes | android update sdk --filter sys-img-armeabi-v7a-android-19 --no-ui --force --all && \
    echo yes | android update sdk --filter platform-tools,android-22,extra --no-ui --force --all && \
    filter=`android list sdk --all | grep Build-tools | grep 22.0.1 | awk '{ print $1 }' | tr -d -` && \
    echo yes | android update sdk --filter $filter --no-ui --force --all && \
    echo yes | android update sdk --filter sys-img-armeabi-v7a-android-22 --no-ui --force --all && \
    filter=`android list sdk --all | grep Build-tools | grep 23.0.3 | awk '{ print $1 }' | tr -d -` && \
    echo yes | android update sdk --filter $filter --no-ui --force --all && \
    echo yes | android update sdk --filter platform-tools,android-23,extra --no-ui --force --all && \
    filter=`android list sdk --all | grep Build-tools | grep "revision 24" | awk '{ print $1 }' | tr -d -` && \
    echo yes | android update sdk --filter $filter --no-ui --force --all && \
    echo yes | android update sdk --filter platform-tools,android-23.1,extra --no-ui --force --all

# Android NDK
USER couchbase
RUN cd /home/couchbase/jenkins/tools && \
    curl -L https://dl.google.com/android/ndk/android-ndk-r10e-linux-x86_64.bin -o android-ndk.bin && \
    chmod a+x android-ndk.bin && \
    ./android-ndk.bin && \
    chown -R couchbase:couchbase android-ndk-r10e && \
    chmod 755 android-ndk-r10e

# Revert so CMD will run as root.
USER root

