# Docker container just to build GCC, because it's slow.

FROM ceejatec/naked-debian:7.6
MAINTAINER ceej@couchbase.com

# Install the older gcc so we can bootstrap up to the newer
RUN apt-get update && apt-get install -y g++ libmpc-dev make file curl bzip2 && \
    rm -f /var/cache/apt/archives/*.deb

# Clean out /usr/local so we only have our gcc output
RUN rm -rf /usr/local/*

# Download all the sources and build
# Explanations for env vars in build command:
#  http://stackoverflow.com/questions/12591629/gcc-cannot-find-bits-predefs-h-on-i686
#  https://bugs.launchpad.net/ubuntu/+source/binutils/+bug/738098
RUN mkdir /tmp/deploy && cd /tmp/deploy && \
    curl -O ftp://ftp.fu-berlin.de/unix/languages/gcc/releases/gcc-4.9.1/gcc-4.9.1.tar.bz2 && \
    cd /tmp/deploy &&  tar xjf gcc-4.9.1.tar.bz2 && \
    cd gcc-4.9.1 && \
    ./configure --prefix=/usr/local --with-slibdir=/lib/x86_64-linux-gnu \
        --disable-multilib --enable-languages=c,c++ && \
    make -j8 BOOT_CFLAGS='-O' bootstrap && \
    make install && \
    cd /tmp && rm -rf deploy

# Create a "dummy" package that consumers can install so Debian doesn't
# try to install the old GCC packages
COPY gcc g++ /tmp/
RUN apt-get install -y equivs
RUN cd /tmp && equivs-build gcc && equivs-build g++ && \
    mkdir /usr/local/debs && cp *.deb /usr/local/debs && rm g*

