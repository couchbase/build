#!/bin/bash -ex

# Create dmg package for macOS.
# Expect Server's app package directory present (Directory contain Couchbase\  Server.app along with README.txt)

function usage
    {
    echo "Incorrect parameters..."
    echo -e "\nUsage:  ${0}   version   bld_num   edition    OSX (eg. macos) package_dir \n\n"
    }

if [[ "$#" < 2 ]] ; then usage ; exit DEAD ; fi

# enable nocasematch
shopt -s nocasematch

VERSION=${1}  # Product Version
BLD_NUM=${2}  # Build Number
EDITION=${3} # enterprise vs community
OSX=${4} # macos vs elcapitan
PKG_DIR=${5} # Package directory with Couchbase\  Server.app and README.txt
ARCHITECTURE='x86_64'

if [[ ! -e "${PKG_DIR}/Couchbase\  Server.app" ]] && [[ ! -e ${PKG_DIR}/README.txt ]]; then
    echo "The required ${PKG_DIR}/Couchbase\  Server.app or ${PKG_DIR}/README.txt files not found!"
    exit 1
fi

# Create dmg package
DMG_FILENAME=couchbase-server-${EDITION}_${VERSION}-${BLD_NUM}-${OSX}_${ARCHITECTURE}.dmg
rm -rf ${DMG_FILENAME}
ln -s /Applications ${PKG_DIR}
create-dmg --volname "Couchbase Installer ${VERSION}-${BLD_NUM}-${EDITION}" \
           --background "${PKG_DIR}/Couchbase Server.app/Contents/Resources/InstallerBackground.jpg" \
           --window-size 800 600 \
           --icon "Couchbase Server.app" 150 200 \
           --icon "Applications" 650 200 \
           --icon "README.txt" 400 475 \
           ${DMG_FILENAME} \
           ${PKG_DIR}

# get rid of the symlink to applications
rm ${PKG_DIR}/Applications
