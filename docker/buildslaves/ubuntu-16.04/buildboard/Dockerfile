# Docker container for Hari's temporary buildboard

FROM ceejatec/ubuntu-1604-couchbase-build:20170220
MAINTAINER ceej@couchbase.com

USER root

RUN mkdir /tmp/deploy && \
    cd /tmp/deploy && \
    curl -O http://packages.couchbase.com/releases/couchbase-release/couchbase-release-1.0-2-amd64.deb && \
    dpkg -i couchbase-release-1.0-2-amd64.deb && \
    apt-get update && \
    apt-get install -y libcouchbase-dev libcouchbase2-bin build-essential python-dev python-pip && \
    cd /tmp && \
    rm -rf deploy && \
    rm -f /var/cache/apt/archives/*.deb

RUN pip install gitpython couchbase requests jira flask

ENTRYPOINT [ "/bin/bash", "-c" ]
CMD [ "/home/couchbase/bbdb/start_script.sh" ]

