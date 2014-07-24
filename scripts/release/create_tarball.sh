#!/bin/bash

# THIS SCRIPT IS HOPEFULLY OBSOLETE. It was used in part to create
# a tarball for 2.5.1 but it is not known to be correct. It is being
# committed to git for historical interest only.

# Given a directory created from "repo sync" to a released/x.x.x.xml
# manifest, create a releasable source tarball
repodir=$1
topleveldir=couchbase-server_src

cd $repodir

# Delete all the "override" projects and others that we don't ship
rm -rf couchdbx-app otp gperftools icu4c pysqlite snappy v8 tlm testrunner v8

# Run all the autorun.sh scripts, then delete them and certain artifacts
for config in */config/autorun.sh
do
    echo Running $config ...
    pushd $(dirname $(dirname $config))
    ./config/autorun.sh
    rm -rf autom4te.cache config/autorun.sh config/version.pl
    popd
done

# Run the bootstrap scripts, then delete them and certain artifacts
for bootstrap in */bootstrap
do
    pushd $(dirname $bootstrap)
    ./bootstrap
    rm -rf autom4te.cache bootstrap
    popd
done

# Copy in the manifest
cp .repo/manifest.xml .

# Delete all the git and repo files - must do this AFTER running all the
# autorun.sh steps!
rm -rf **/.git **/.gitmodules .repo


# Create top-level subdir
mkdir ${topleveldir}
mv * ${topleveldir}

# Zip it up!
echo
echo Creating $repodir.tar.gz ...
tar czf $repodir.tar.gz ${topleveldir}
echo
echo 'Done!'
