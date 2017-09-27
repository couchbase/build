#!/bin/bash

# Setup for aptly
echo "deb http://repo.aptly.info/ squeeze main" | sudo tee --append /etc/apt/sources.list >/dev/null
wget -qO - https://www.aptly.info/pubkey.txt | sudo apt-key add -

sudo apt-get update
sudo apt-get install -y aptly wget s3cmd
cp ~/.ssh/live.s3cfg ~/.s3cfg

gpg --import ~/.ssh/79CF7903.priv.gpg
gpg --import ~/.ssh/CD406E62.priv.gpg
gpg --import ~/.ssh/D9223EDA.priv.gpg
