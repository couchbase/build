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

# Install Couchbase Lite Android toolchain requirements
RUN apt-get update && apt-get install -y git-core tar curl unzip gcc-multilib g++-multilib lib32z1 lib32stdc++6 && \
    rm -f /var/cache/apt/archives/*.deb

# Oracle JDK
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections && \
    add-apt-repository ppa:webupd8team/java && \
    apt-get update && \
    apt-get install -y oracle-java8-installer && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /var/cache/oracle-java8-installer

ENV JAVA_HOME /usr/lib/jvm/java-8-oracle

# Expose SSH daemon and run our builder startup script
EXPOSE 22
ADD .ssh /home/couchbase/.ssh
COPY build/couchbuilder_start.sh /usr/sbin/
ENTRYPOINT [ "/usr/sbin/couchbuilder_start.sh" ]
CMD [ "default" ]

# Android SDK/CLANG environment settings
RUN echo 'export ANDROID_NDK_HOME="/home/couchbase/jenkins/tools/android-ndk-r15c"\nexport ANDROID_HOME="/home/couchbase/jenkins/tools/android-sdk"\nexport ANDROID_SDK_HOME="/home/couchbase/jenkins/tools/android-sdk"\nexport PATH="$ANDROID_NDK_HOME:$ANDROID_SDK_HOME:$ANDROID_SDK_HOME/tools:$ANDROID_SDK_HOME/platform-tools:$PATH"' > /etc/profile.d/android.sh

# Android SDK
USER couchbase
RUN mkdir -p /home/couchbase/jenkins/tools && \
    cd /home/couchbase/jenkins/tools && \
    curl -L http://dl.google.com/android/android-sdk_r24.4.1-linux.tgz -o android-sdk.tgz && \
    tar xzf android-sdk.tgz && \
    rm -rf android-sdk.tgz && \
    mv android-sdk-linux android-sdk && \
    chown -R couchbase:couchbase android-sdk && \
    chmod 755 android-sdk

RUN . /etc/profile && \
    echo yes | android update sdk --filter platform-tools,android-26,extra --no-ui --force --all && \
    filter=`android list sdk --all | grep Build-tools | grep 26.0.1 | awk '{ print $1 }' | tr -d -` && \
    echo yes | android update sdk --filter $filter --no-ui --force --all && \
    filter=`android list sdk --all | grep "SDK Platform Android" | grep "API 26" | awk '{ print $1 }' | tr -d -` && \
    echo yes | android update sdk --filter $filter --no-ui --force --all && \
    echo yes | android -s update sdk --no-ui --force --all --filter extra-android-m2repository,extra-android-support,extra-google-google_play_services,extra-google-m2repository && \
    echo yes | android update sdk --filter android-24,sys-img-armeabi-v7a-android-24 --no-ui --force --all && \
    filter=`android list sdk --all | grep "SDK Platform Android" | grep "API 24" | awk '{ print $1 }' | tr -d -` && \
    echo yes | android -s update sdk --no-ui --filter $filter --force --all && \
    # test legacy android-16
    echo yes | android update sdk --filter android-16,sys-img-armeabi-v7a-android-16 --no-ui --force --all && \
    filter=`android list sdk --all | grep "SDK Platform Android" | grep "API 16" | awk '{ print $1 }' | tr -d -` && \
    echo yes | android -s update sdk --no-ui --filter $filter --force --all

# Android SDK License
ENV ANDROID_HOME /home/couchbase/jenkins/tools/android-sdk
RUN mkdir -p "$ANDROID_HOME/licenses" || true && \
    echo -e "\n8933bad161af4178b1185d1a37fbf41ea5269c55" > "$ANDROID_HOME/licenses/android-sdk-license" && \
    echo -e "\n84831b9409646a918e30573bab4c9c91346d8abd" > "$ANDROID_HOME/licenses/android-sdk-preview-license"

# Android NDK
USER couchbase
RUN cd /home/couchbase/jenkins/tools && \
    curl -L https://dl.google.com/android/repository/android-ndk-r15c-linux-x86_64.zip -o android-ndk-r15c.zip && \
    unzip -qq android-ndk-r15c.zip && \
    chown -R couchbase:couchbase android-ndk-r15c && \
    chmod 755 android-ndk-r15c && \
    rm -rf android-ndk-r15c.zip

# Revert so CMD will run as root.
USER root
