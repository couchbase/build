#!/bin/bash -ex

display_usage()
{
  echo "\nUsage: $0 -a <Apple Account PW> -d <Dist Dir> -e <Edition> -p <Product> -v <Version> \n"
  echo "  Dist Dir:  i.e. /opt/couchbase \n"
  echo "  Edition: enterprise|community \n"
  echo "  Product: i.e. couchbase-server \n"
  echo "  Version: i.e. 6.6.2 \n"
} 

while getopts a:d:e:p:v: opt
do
  case "${opt}" in
    a) 
      AC_PASSWORD=${OPTARG}
      ;;
    d) DISTDIR=${OPTARG}
      ;;
    e) EDITION=${OPTARG}
      ;;
    p) PRODUCT=${OPTARG}
      ;;
    v) VERSION=${OPTARG}
      ;;
    :)
      display_usgae
      ;;
    esac
done

if [[ -z "${AC_PASSWORD}" || -z "${DISTDIR}" || -z "${EDITION}" || -z "${PRODUCT}" || -z "${VERSION}" ]]; then
    display_usage
    exit 1;
fi

ZIP_NAME=${PRODUCT}-${EDITION}_${VERSION}-macosx.zip
SCRIPT=`realpath $0`
SCRIPT_DIR=`dirname $SCRIPT`
security unlock-keychain -p `cat ~/.ssh/security-password.txt` ${HOME}/Library/Keychains/login.keychain
sign_flags="--force --timestamp --options=runtime  --verbose --entitlements $SCRIPT_DIR/cb.entitlement --preserve-metadata=identifier,requirements"
cert_name="Developer ID Application: Couchbase, Inc. (N2Q372V7W2)"


pushd $DISTDIR

#protoc-gen-go was generated w/ sdk older than 10.9, it will cause notarization failure.
#it can be removed since it doesn't need to be shipped.
rm -f bin/protoc-gen-go

find . -type f > flist.tmp
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

popd

echo "------- Codesigning the package ${ZIP_NAME} -------"
zip -r -X $ZIP_NAME $DISTDIR
codesign $sign_flags --sign "$cert_name" ${ZIP_NAME}

echo "-------Notarizing for ${ZIP_NAME}-------"
XML_OUTPUT=$(
  xcrun altool --notarize-app -t osx \
  -f ${ZIP_NAME} \
  --primary-bundle-id com.couchbase.couchbase-server \
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
