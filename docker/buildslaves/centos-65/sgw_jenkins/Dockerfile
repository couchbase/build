# Docker container for Centos 6.5

# See https://github.com/ceejatec/naked-docker/ for details about the
# construction of the base image.

FROM ceejatec/centos-65-couchbase-build
MAINTAINER michael.kwok@couchbase.com

# Needed for sg
ADD .rpmmacros /home/couchbase/

RUN chown couchbase:couchbase /home/couchbase/.rpmmacros
