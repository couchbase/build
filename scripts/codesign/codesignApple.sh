#!/bin/bash -ex

#
# REMEMBER TO ALWAYS PRESERVE SYMLINKS WHEN ZIP and UNZIP
#
# Verification steps after codesign
# 1. spctl -avvvv pkg_name.app
#    Results "accepted" and Couchbase ID must be present
# 2. codesign -dvvvv pkg_name.app
#    Sealed resource must be version 2
# 3. Best to upload to another website (latestbuilds), download from there and rerun step #1 and #2
#
#

function usage
    {
    echo "Incorrect parameters..."
    echo -e "\nUsage:  ${0}   version   builld_num   edition    OSX (eg. elcaptian) [1 = download package]\n\n"
    }

if [[ "$#" < 2 ]] ; then usage ; exit DEAD ; fi

# enable nocasematch
shopt -s nocasematch

PKG_VERSION=${1}  # Product Version

PKG_BUILD_NUM=${2}  # Build Number

EDITION=${3} # enterprise vs community

OSX=${4} # macos vs elcapitan

DOWNLOAD_NEW_PKG=${5}  # Get new build

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )" #find out absolute path of the script

result="rejected"

PKG_URL=http://latestbuilds.service.couchbase.com/builds/latestbuilds/${PRODUCT}/zz-versions/${PKG_VERSION}/${PKG_BUILD_NUM}
PKG_NAME_US=couchbase-server-${EDITION}_${PKG_VERSION}-${PKG_BUILD_NUM}-${OSX}_x86_64-unsigned.zip
PKG_NAME=couchbase-server-${EDITION}_${PKG_VERSION}-${PKG_BUILD_NUM}-${OSX}_x86_64.zip
PKG_DIR=couchbase-server-${EDITION}_${PKG_VERSION}

if [[ ${DOWNLOAD_NEW_PKG} ]]
then
    curl -O ${PKG_URL}/${PKG_NAME_US}

    if [[ -d ${PKG_DIR} ]] ; then rm -rf ${PKG_DIR} ; fi
    if [[ -e ${PKG_NAME_US} ]]
    then
        unzip -qq ${PKG_NAME_US}
    else
        echo ${PKG_NAME_US} not found!
        exit 1
    fi
fi

if [[ -d ${PKG_DIR} ]]
then
    pushd ${PKG_DIR}
else
    mkdir ${PKG_DIR}
    mv *.app ${PKG_DIR}
    mv README.txt ${PKG_DIR}
    pushd ${PKG_DIR}
fi

echo ------- Unlocking keychain -----------
set +x
security unlock-keychain -p `cat ~/.ssh/security-password.txt` /Users/couchbase/Library/Keychains/login.keychain
set -x

###define codesigning flags and cert id
###use cb.entitlement.  mainly because of packaged adoptopenjdk
###they have to be resigned due to lack of runtime hardening.  missing necessary entitlements when using --preserve-metadata
###cb.entitlement consists of entitlements for basic java apps, which is similar to what is used by adoptopenjdk described in (https://medium.com/adoptopenjdk/bundling-adoptopenjdk-into-a-notarized-macos-application-f4d69404afc)
###In order to have consistent entitlements, it is best to use cb.entitlement for all codesiging.
sign_flags="--force --timestamp --options=runtime  --verbose --entitlements ${SCRIPTPATH}/cb.entitlement --preserve-metadata=identifier,requirements"
cert_name="Developer ID Application: Couchbase, Inc. (N2Q372V7W2)"

echo ------- Codesign options: $sign_flags -----------

echo ------- Sign binary files individually in Resources and Frameworks-------
set +e
find "Couchbase Server.app/Contents/Resources" "Couchbase Server.app/Contents/Frameworks" -type f > flist.tmp
while IFS= read -r f
do
  ##binaries in jars have to be signed.
  ##It seems only jars in  META-INF are impacted so far.
  ##jars with .jnilib in other locations were not rejected
  if [[ "$f" =~ ".jar" ]]; then
    libs=`jar -tf "$f" | grep "META-INF" | grep ".jnilib\|.dylib"`
    if [[ ! -z $libs ]]; then
      for l in ${libs}; do
        jar xf "$f" "$l"
        codesign $sign_flags --sign "$cert_name" "$l"
        jar uf "$f" "$l"
      done
      rm -rf META-INF
    fi
  elif [[ `file --brief "$f"` =~ "Mach-O" ]]; then

    if [[ `echo "$f" |grep -v "crypto.o\|crypto_callback.o\|librocksdb.5.18.3.dylib\|otp_test_engine.o"` != ""  ]]; then
      codesign $sign_flags --sign "$cert_name" "$f"
    fi
  fi
done < flist.tmp
rm -f flist.tmp
set -e

echo -------- Must sign Sparkle framework all versions ----------
sign_flags="--force --verbose --preserve-metadata=identifier,entitlements,requirements"
echo options: $sign_flags -----
codesign $sign_flags --sign "Developer ID Application: Couchbase, Inc" Couchbase\ Server.app/Contents/Frameworks/Sparkle.framework/Versions/A/Sparkle
codesign $sign_flags --sign "Developer ID Application: Couchbase, Inc" Couchbase\ Server.app/Contents/Frameworks/Sparkle.framework/Versions/A

codesign $sign_flags --sign "Developer ID Application: Couchbase, Inc" Couchbase\ Server.app/Contents/Frameworks/Sparkle.framework/Versions/Current/Sparkle
codesign $sign_flags --sign "Developer ID Application: Couchbase, Inc" Couchbase\ Server.app/Contents/Frameworks/Sparkle.framework/Versions/Current

echo --------- Sign Couchbase app last --------------
codesign $sign_flags --sign "Developer ID Application: Couchbase, Inc" Couchbase\ Server.app

popd

rm -f ${PKG_NAME}
zip -qry ${PKG_NAME} ${PKG_DIR}
rm -f ${PKG_NAME_US}

# Verify codesigned successfully
spctl -avvvv ${PKG_DIR}/*.app > tmp.txt 2>&1
result=`grep "accepted" tmp.txt | awk '{ print $3 }'`
echo ${result}
if [[ ${result} =~ "accepted" ]]
then
    # Ensure it's actually signed
    if [[ -z $(grep "no usable signature" tmp.txt) ]]
    then
        exit 0
    else
        exit 1
    fi
else
    exit 1
fi
