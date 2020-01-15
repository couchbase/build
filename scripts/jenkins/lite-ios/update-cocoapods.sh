#!/bin/bash

# virtualenv stuff
export LC_ALL=C
export LANG=en_US.UTF-8
pip3 install --user --upgrade virtualenv

# start virtualenv
/home/couchbase/.local/bin/virtualenv COCOAPODS || exit 1
source ./COCOAPODS/bin/activate  || exit 1

# Install required cocoapods
sudo gem uninstall --all cocoapods
sudo gem install cocoapods -v 1.8.4
export GEM_HOME=$HOME/.gem
gem which cocoapods

# Checkout required repo
cd ${WORKSPACE} && git clone git@github.com:couchbaselabs/couchbase-lite-ios-ee.git couchbase-lite-ios-ee

cd ${WORKSPACE}/couchbase-lite-ios-ee/Podspecs
declare -a JSON_FILES=( $(ls) )
for fl in "${JSON_FILES[@]}"; do
	python3 ${WORKSPACE}/build-tools/mobile/lite-ios/cocoapods-publish.py --version ${VERSION} --file $fl || exit 1
done

# deactivate virtualenv
echo "Deactivating virtualenv ..."
deactivate
echo
