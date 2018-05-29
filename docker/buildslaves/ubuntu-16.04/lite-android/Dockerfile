# Docker container for Ubuntu 16.04

# See https://github.com/ceejatec/naked-docker/ for details about the
# construction of the base image.

FROM  ubuntu:16.04
MAINTAINER build-team@couchbase.com

USER root

# Install SSH server
RUN apt-get update && \
    apt-get install -y openssh-server sudo && \
    apt-get clean && \
    mkdir /var/run/sshd

# Create couchbase user with password-less sudo privs, and give
# ownership of /opt/couchbase
RUN useradd couchbase -G sudo -m -s /bin/bash && \
    mkdir -p /opt/couchbase && chown -R couchbase:couchbase /opt/couchbase && \
    echo 'couchbase:couchbase' | chpasswd && \
    sed -ri 's/ALL\) ALL/ALL) NOPASSWD:ALL/' /etc/sudoers

# Install Couchbase Lite Android toolchain requirements
RUN apt-get update && apt-get install -y git-core tar curl unzip gcc-multilib g++-multilib lib32z1 lib32stdc++6 openjdk-8-jdk gnupg2 && \
    apt-get clean

# Update locale
RUN apt-get update && \
    apt-get install -y locales && \
    apt-get clean && \
    locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8

# Expose SSH daemon and run our builder startup script
EXPOSE 22
ADD .ssh /home/couchbase/.ssh
COPY build/couchbuilder_start.sh /usr/sbin/
ENTRYPOINT [ "/usr/sbin/couchbuilder_start.sh" ]
CMD [ "default" ]

# Android SDK
USER couchbase

# Download and untar Android SDK tools
RUN mkdir -p /home/couchbase/jenkins/tools && \
    cd /home/couchbase/jenkins/tools && \
	wget --no-check-certificate https://dl.google.com/android/repository/tools_r25.2.3-linux.zip -O android-sdk.zip && \
	unzip android-sdk.zip -d android-sdk  && \
    rm android-sdk.zip && \
    chown -R couchbase:couchbase android-sdk && \
    chmod 755 android-sdk

# Set environment variable
ENV ANDROID_HOME /home/couchbase/jenkins/tools/android-sdk
ENV PATH ${ANDROID_HOME}/tools:$ANDROID_HOME/platform-tools:$PATH

# Android SDK License
RUN mkdir $ANDROID_HOME/licenses && \
	echo 8933bad161af4178b1185d1a37fbf41ea5269c55 > $ANDROID_HOME/licenses/android-sdk-license  && \
	echo d56f5187479451eabf01fb78af6dfcb131a6481e >> $ANDROID_HOME/licenses/android-sdk-license && \
	echo 84831b9409646a918e30573bab4c9c91346d8abd > $ANDROID_HOME/licenses/android-sdk-preview-license

# Update and install using sdkmanager
ENV SDK_CMD $ANDROID_HOME/tools/bin/sdkmanager
RUN $SDK_CMD "tools" "platform-tools"
RUN $SDK_CMD "build-tools;27.0.3" "build-tools;27.0.0" "build-tools;26.0.2" "build-tools;25.0.3"
RUN $SDK_CMD "platforms;android-27" "platforms;android-26" "platforms;android-25" "platforms;android-24" "platforms;android-16"
RUN $SDK_CMD "system-images;android-16;default;armeabi-v7a"
RUN $SDK_CMD "system-images;android-24;default;armeabi-v7a"
RUN $SDK_CMD "system-images;android-25;google_apis;armeabi-v7a"
RUN $SDK_CMD "extras;android;m2repository" "extras;google;m2repository"
RUN $SDK_CMD --update  # fix the "Your emulator is out of date" message

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

# gpg maven
COPY couchhook.sh /usr/sbin/
