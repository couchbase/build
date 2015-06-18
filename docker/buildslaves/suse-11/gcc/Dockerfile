# Docker container just to build GCC, because it's slow.

FROM ceejatec/naked-opensuse:11.2
MAINTAINER ceej@couchbase.com

# Install the older gcc so we can bootstrap up to the newer
RUN zypper install -y gcc gcc-c++ libopenssl-devel libcurl-devel \
    libexpat-devel lsb-release ncurses-devel curl make tar

# Clean out /usr/local so we only have our gcc output
RUN rm -rf /usr/local/*

# Download all the sources
RUN mkdir /tmp/deploy && cd /tmp/deploy && \
    curl -O ftp://ftp.fu-berlin.de/unix/languages/gcc/releases/gcc-4.9.1/gcc-4.9.1.tar.bz2 && \
    curl -O https://gmplib.org/download/gmp/gmp-6.0.0a.tar.bz2 && \
    curl -O http://www.mpfr.org/mpfr-current/mpfr-3.1.2.tar.bz2 && \
    curl -O ftp://ftp.gnu.org/gnu/mpc/mpc-1.0.2.tar.gz && \
    curl -O ftp://gcc.gnu.org/pub/gcc/infrastructure/isl-0.12.2.tar.bz2 && \
    curl -O ftp://gcc.gnu.org/pub/gcc/infrastructure/cloog-0.18.1.tar.gz && \
    tar xjf gmp-6.0.0a.tar.bz2 && \
    tar xjf mpfr-3.1.2.tar.bz2 && \
    tar xzf mpc-1.0.2.tar.gz && \
    tar xjf isl-0.12.2.tar.bz2 && \
    tar xzf cloog-0.18.1.tar.gz && \
    tar xjf gcc-4.9.1.tar.bz2 && \
    mv cloog-0.18.1 gcc-4.9.1/cloog && \
    mv gmp-6.0.0 gcc-4.9.1/gmp && \
    mv isl-0.12.2 gcc-4.9.1/isl && \
    mv mpc-1.0.2 gcc-4.9.1/mpc && \
    mv mpfr-3.1.2 gcc-4.9.1/mpfr && \
    cd gcc-4.9.1 && \
    ./configure  --prefix=/usr/local --disable-multiarch --disable-multilib --enable-languages=c,c++ && \
    gmake BOOT_CFLAGS='-O' bootstrap && \
    gmake install && \
    cd /tmp && rm -rf deploy

