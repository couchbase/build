# Docker container for Docker 7.6

# See https://github.com/ceejatec/naked-docker/ for details about the
# construction of the base image.

FROM ceejatec/debian-7-couchbase-build:latest
MAINTAINER ceej@couchbase.com

# GCC (from ceejatec/debian-gcc-build)
COPY build/local /usr/local
RUN  (echo "/usr/local/lib64"; cat /etc/ld.so.conf) > /tmp/ld.so.conf && \
     mv /tmp/ld.so.conf /etc && ldconfig && \
     ln -s gcc /usr/local/bin/cc

ENV CPATH=/usr/include/x86_64-linux-gnu LIBRARY_PATH=/usr/lib/x86_64-linux-gnu

