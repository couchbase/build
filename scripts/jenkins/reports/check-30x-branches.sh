#!/bin/bash -ex

git config --global user.name "Couchbase Build Team"
git config --global user.email "build-team@couchbase.com"
git config --global color.ui false

# Sync the primary repo
if [ ! -d repo ]
then
  mkdir repo
fi
cd repo
# Conveniently this does NOT delete the .repo directory itself
rm -rf * .repo/manifest*
repo init -u https://github.com/couchbase/manifest -g all -m rel-3.0.x.xml
repo sync --jobs=6

repo manifest -r > rel30x.xml

repo init -u https://github.com/ceejatec/manifest -g all -m real-3.0.x.xml
repo sync --jobs=6

repo manifest -r > real30x.xml

repo diffmanifests `pwd`/rel30x.xml `pwd`/real30x.xml > diff-report.txt

size=`wc -c < diff-report.txt`
if [ "0" != "$size" ]
then
  echo "There are 3.0.x changes to investigate"
  exit 2
fi

