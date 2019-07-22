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

# force sign dmg pkg - only if CB_PRODUCTION_BUILD defined
if [[ ${CB_PRODUCTION_BUILD} == 'true' ]]; then
    sign_flags="--force --timestamp --options=runtime --verbose --preserve-metadata=identifier,entitlements,requirements"
    echo ------- Unlocking keychain -----------
    set +x
    security unlock-keychain -p `cat ~/.ssh/security-password.txt` ${HOME}/Library/Keychains/login.keychain
    set -x
    echo --------- Sign Couchbase app last --------------
    codesign $sign_flags --sign "Developer ID Application: Couchbase, Inc" ${DMG_FILENAME}
    spctl -a -t open --context context:primary-signature -v ${DMG_FILENAME} > tmp_dmg.txt 2>&1
    result=`grep "accepted" tmp_dmg.txt | awk '{ print $2 }'`
    echo ${result}
    if [[ ${result} =~ "accepted" ]]
    then
        # Ensure it's actually signed
        if [[ -z $(grep "no usable signature" tmp_dmg.txt) ]]
        then
            exit 0
        else
            exit 1
        fi
    else
        cat tmp_dmg.txt
        exit 1
    fi
fi
# get rid of the symlink to applications
rm ${PKG_DIR}/Applications
