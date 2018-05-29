#!/bin/bash -e

if [[ ! "$(ls /ssh/private_5E0EE1E4_maven.gpg)" ]] && [[ ! "$(ls /ssh/public_5E0EE1E4_maven.gpg)" ]]; then
    echo "Missing required gpg keys files in /ssh/"
else
    cp -a /ssh/*_maven.gpg /home/couchbase/.ssh
fi

chown -R couchbase:couchbase /home/couchbase/.ssh

# import gpg key
exec su -c "gpg --import /home/couchbase/.ssh/private_5E0EE1E4_maven.gpg" couchbase
exec su -c "gpg --import /home/couchbase/.ssh/public_5E0EE1E4_maven.gpg" couchbase
