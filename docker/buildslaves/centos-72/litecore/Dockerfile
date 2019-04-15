# Docker container for Ubuntu 14.04

# See https://github.com/ceejatec/naked-docker/ for details about the
# construction of the base image.

FROM couchbase/centos-72-jenkins-core:20170613
MAINTAINER build-team@couchbase.com

# FPM packaging tool.  Need this before install clang as it will override c++
RUN yum install -y ruby-devel gcc make rpm-build rubygems && \
    gem install fpm

# Install Clang from Fedora Copr
RUN curl -o /etc/yum.repos.d/alonid.repo \
  https://copr.fedorainfracloud.org/coprs/alonid/llvm-3.9.1/repo/epel-7/alonid-llvm-3.9.1-epel-7.repo && \
  yum install -y --setopt=keepcache=0 clang-3.9.1 llvm-3.9.1-devel

# Make clang-3.9.1 the default, overriding GCC, and fix up CMake stuff
RUN update-alternatives --install /usr/bin/clang++ clang++ /opt/llvm-3.9.1/bin/clang++ 100 && \
    update-alternatives --install /usr/bin/clang clang /opt/llvm-3.9.1/bin/clang 100 && \
    rm /usr/bin/c++ && \
    update-alternatives --install /usr/bin/c++ c++ /opt/llvm-3.9.1/bin/clang++ 100 && \
    update-alternatives --install /usr/bin/cc cc /opt/llvm-3.9.1/bin/clang 100 && \
    ln -s /opt/llvm-3.9.1/bin/llvm-config /usr/bin/llvm-config && \
    mkdir -p /opt/llvm-3.9.1/share/llvm && \
    ln -s /opt/llvm-3.9.1/lib64/cmake/llvm /opt/llvm-3.9.1/share/llvm/cmake

# Install Couchbase Lite Core toolchain requirements
RUN yum install -y --setopt=keepcache=0 tar openssl-devel make redhat-lsb-core wget unzip zip

# * ccache (from source)
RUN mkdir /tmp/deploy && \
    curl -L https://www.samba.org/ftp/ccache/ccache-3.3.4.tar.xz -o /tmp/deploy/ccache.tar.xz && \
    cd /tmp/deploy && tar -xf ccache.tar.xz && \
    cd ccache-3.3.4 && ./configure --prefix=/usr/local && make -j8 && make install && \
    ln -s ccache /usr/local/bin/clang && \
    ln -s ccache /usr/local/bin/clang++ && \
    ln -s ccache /usr/local/bin/cc && \
    ln -s ccache /usr/local/bin/c++ && \
    ln -s ccache /usr/local/bin/gcc && \
    ln -s ccache /usr/local/bin/g++ && \
    rm -fr /tmp/deploy

# * CMake (from cmake.org)
RUN mkdir /tmp/deploy && \
    curl -L https://cmake.org/files/v3.13/cmake-3.13.0-Linux-x86_64.sh -o /tmp/deploy/cmake.sh && \
    (echo y ; echo n) | sh /tmp/deploy/cmake.sh --prefix=/usr/local && \
    rm /usr/local/bin/cmake-gui && \
    rm -rf /tmp/deploy

# Android SDK
RUN mkdir -p /opt && \
    cd /opt && \
    curl -L http://dl.google.com/android/android-sdk_r24.4.1-linux.tgz -o android-sdk.tgz && \
    tar xzf android-sdk.tgz && \
    rm -rf android-sdk.tgz && \
    (echo y | android-sdk-linux/tools/android -s update sdk --no-ui --filter platform-tools,tools -a ) && \
    (echo y | android-sdk-linux/tools/android -s update sdk --no-ui --filter extra-android-m2repository,extra-android-support,extra-google-google_play_services,extra-google-m2repository -a) && \
    (echo y | android-sdk-linux/tools/android -s update sdk --no-ui --filter build-tools-26.0.0,android-26 -a) && \
    chown -R couchbase:couchbase android-sdk-linux && \
    chmod 755 android-sdk-linux

## Android NDK
RUN cd /opt && \
    curl -L https://dl.google.com/android/repository/android-ndk-r15b-linux-x86_64.zip -o android-ndk-r15b.zip && \
    unzip -qq android-ndk-r15b.zip && \
    chown -R couchbase:couchbase android-ndk-r15b && \
    chmod 755 android-ndk-r15b && \
    rm -rf android-ndk-r15b.zip
