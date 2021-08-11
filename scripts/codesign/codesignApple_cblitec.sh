#!/bin/bash -ex

#${KEYCHAIN_PASSWORD} and ${AC_PASSWORD} are injected as an env password in jenkins job
#when running it manually from command line, it will need to be set as an env variable first

function usage
    {
    echo "Incorrect parameters..."
    echo -e "\nUsage:  ${0}   product version   builld_num  edition [1 = download package] notarize [ yes or no ] \n\n"
    }

if [[ "$#" < 2 ]] ; then usage ; exit DEAD ; fi

PRODUCT=${1}  # Product Name

PKG_VERSION=${2}  # Product Version

PKG_BUILD_NUM=${3}  # Build Number

EDITION=${4}  # community or enterprise

ARCH=${5}  # x86_64 or arm64

DOWNLOAD_PKG=${6}  # Get new build

NOTARIZE=${7} #yes or no

#PKG_URL=http://latestbuilds.service.couchbase.com/builds/latestbuilds/${PRODUCT}/${PKG_VERSION}/${PKG_BUILD_NUM}
PKG_DIR=${PRODUCT}-${ARCH}-${PKG_VERSION}-${PKG_BUILD_NUM}-${EDITION}
PKG_NAME=${PRODUCT}-${ARCH}-${PKG_VERSION}-${PKG_BUILD_NUM}-${EDITION}_unsigned.zip
PKG_NAME_SIGNED=${PRODUCT}-${ARCH}-${PKG_VERSION}-${PKG_BUILD_NUM}-${EDITION}.zip

if [[ ${DOWNLOAD_PKG} == 1 ]]; then
  curl -O ${PKG_URL}/${PKG_NAME}
fi

if [[ -d ${PKG_DIR} ]] ; then
  rm -rf ${PKG_DIR}
fi
if [[ -e ${PKG_NAME} ]]; then
  mkdir ${PKG_DIR}
  unzip -qq ${PKG_NAME} -d ${PKG_DIR}
  rm -f ${PKG_NAME}
else
  echo ${PKG_NAME} not found!
  exit 1
fi

#unlock keychain
echo "------- Unlocking keychain -----------"
security unlock-keychain -p ${KEYCHAIN_PASSWORD} ${HOME}/Library/Keychains/login.keychain-db

echo "------- Codesigning binaries within the package -------"
sign_flags="--force --timestamp --options=runtime  --verbose --entitlements cblitec.entitlement --preserve-metadata=identifier,requirements"
cert_name="Developer ID Application: Couchbase, Inc. (N2Q372V7W2)"
set +e
find "${PKG_DIR}" -type f > flist.tmp
while IFS= read -r f
do
  if [[ `file --brief "$f"` =~ "Mach-O" ]]; then
    codesign $sign_flags --sign "$cert_name" "$f"
  fi
done < flist.tmp
rm -f flist.tmp
set -e

echo "------- Codesigning the package ${PKG_NAME_SIGNED} -------"
zip -r -X ${PKG_NAME_SIGNED} ${PKG_DIR}/*
codesign $sign_flags --sign "$cert_name" ${PKG_NAME_SIGNED}

if [[ ${NOTARIZE} != "yes" ]]; then
  echo "notarization option is set to ${NOTARIZE}"
  echo "skip notarization..."
  exit
fi


echo "-------Notarizing for ${PKG_NAME_SIGNED}-------"
XML_OUTPUT=$(
  xcrun altool --notarize-app -t osx \
  -f ${PKG_NAME_SIGNED} \
  --primary-bundle-id ${PRODUCT} \
  -u build-team@couchbase.com -p ${AC_PASSWORD} \
  --output-format xml
)
if [ $? != 0 ]; then
  echo "Error running notarize command!"
  exit 1
fi
REQUEST_ID=$(
  echo "${XML_OUTPUT}" | xmllint --xpath '//dict[key/text() = "RequestUUID"]/string/text()' -
)
echo "Notarization request has been uploaded - request ID is ${REQUEST_ID}"

# Sometime, there might be a delay for request ID to propagate to all servers
# sleep for 30 sec.
sleep 30

while true; do
  OUTPUT=$(
    xcrun altool --notarization-info ${REQUEST_ID} \
    -u build-team@couchbase.com -p ${AC_PASSWORD} \
    2>&1
  )
  STATUS=$(
    echo "${OUTPUT}" | grep "Status:"
  )
  if [[ ${STATUS} =~ "success" ]]; then
    echo "Request ${REQUEST_ID} succeeded!"
    exit
  elif [[ ${STATUS} =~ "in progress" ]]; then
    echo "Request ${REQUEST_ID} still in progress..."
  else
    echo @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    echo "Request ${REQUEST_ID} failed notarization!"
    echo "${XML_OUTPUT}"
    echo @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    exit 1
  fi
  echo "Wait for a minute before checking it again..."
  sleep 60
done
