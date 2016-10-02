#!/bin/bash
sudo apt-get update
sudo apt-get install -y reprepro wget s3cmd
cp ~/.ssh/live.s3cfg ~/.s3cfg

gpg --import ~/.ssh/79CF7903.priv.gpg 
gpg --import ~/.ssh/CD406E62.priv.gpg 
gpg --import ~/.ssh/D9223EDA.priv.gpg
