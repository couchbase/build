# Docker container for Ubuntu 14.04

# See https://github.com/ceejatec/naked-docker/ for details about the
# construction of the base image.

FROM ceejatec/naked-ubuntu:14.04
MAINTAINER build-team@couchbase.com

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
RUN npm config set registry="http://registry.npmjs.org/"
RUN npm install xmlbuilder
RUN npm install findit
RUN npm install ncp
RUN echo yes | apt-get install zip

# JDK for Jenkins.
# JCE Unlimited Policy is not available by default from oracle-java8-installer
# Software-properties-common is required for add-apt-repository
RUN apt-get update && \
    apt-get install -y maven unzip && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:webupd8team/java -y && \
    apt-get update && \
    echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections && \
    apt-get install oracle-java8-installer -y && \
    apt-get install oracle-java8-set-default && \
    apt-get install oracle-java8-unlimited-jce-policy && \
    rm -f /var/cache/apt/archives/*.deb

# CLANG compiler
RUN apt-get install -y clang-3.6

# Android SDK/CLANG environment settings
RUN echo 'export ANDROID_NDK_HOME="/home/couchbase/jenkins/tools/android-ndk-r12b"\nexport ANDROID_HOME="/home/couchbase/jenkins/tools/android-sdk"\nexport ANDROID_SDK_HOME="/home/couchbase/jenkins/tools/android-sdk"\nexport PATH="/usr/lib/llvm-3.6/bin:$ANDROID_NDK_HOME:$ANDROID_SDK_HOME:$ANDROID_SDK_HOME/tools:$ANDROID_SDK_HOME/platform-tools:$PATH"' > /etc/profile.d/android.sh

# Android SDK
USER couchbase
RUN mkdir -p /home/couchbase/jenkins/tools && \
    cd /home/couchbase/jenkins/tools && \
    curl -L https://dl.google.com/android/repository/tools_r25.2.3-linux.zip -o android-sdk.zip && \
    unzip android-sdk.zip -d android-sdk && \
    chown -R couchbase:couchbase android-sdk && \
    chmod 755 android-sdk

ENV ANDROID_HOME /home/couchbase/jenkins/tools/android-sdk
ENV SDK_CMD $ANDROID_HOME/tools/bin/sdkmanager

# Android SDK License
RUN mkdir $ANDROID_HOME/licenses && \
    echo 8933bad161af4178b1185d1a37fbf41ea5269c55 > $ANDROID_HOME/licenses/android-sdk-license  && \
    echo d56f5187479451eabf01fb78af6dfcb131a6481e >> $ANDROID_HOME/licenses/android-sdk-license && \
    echo 84831b9409646a918e30573bab4c9c91346d8abd > $ANDROID_HOME/licenses/android-sdk-preview-license

RUN . /etc/profile && \
    $SDK_CMD "tools" "platform-tools" && \
    $SDK_CMD "build-tools;27.0.3" "build-tools;27.0.0" "build-tools;26.0.2" "build-tools;24.0.0" "build-tools;25.0.3" "build-tools;22.0.1" "build-tools;23.0.3" "build-tools;19.1.0" && \
    $SDK_CMD "platforms;android-27" "platforms;android-26" "platforms;android-25" "platforms;android-24" "platforms;android-22" "platforms;android-16" && \
    $SDK_CMD "system-images;android-16;default;armeabi-v7a" && \
    $SDK_CMD "system-images;android-19;default;armeabi-v7a" && \
    $SDK_CMD "system-images;android-24;default;armeabi-v7a" && \
    $SDK_CMD "system-images;android-25;google_apis;armeabi-v7a"

# Android NDK
USER couchbase
RUN cd /home/couchbase/jenkins/tools && \
    curl -L https://dl.google.com/android/repository/android-ndk-r12b-linux-x86_64.zip -o android-ndk-r12b.zip && \
    unzip -qq android-ndk-r12b.zip && \
    chown -R couchbase:couchbase android-ndk-r12b && \
    chmod 755 android-ndk-r12b

# Revert so CMD will run as root.
USER root

