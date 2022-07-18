#!/bin/zsh -e

#${KEYCHAIN_PASSWORD} and ${AC_PASSWORD} are injected as an env password in jenkins job

function usage
{
  echo "\nUsage: $0 -p <Product> -r <Release> -v <Version> -b <Build> -e <Edition> -a <Arch> -n\n"
  echo "  -p Product:  couchbase-server|sync_gateway|couchbase-lite-c \n"
  echo "  -r Release: i.e. elixir, 3.1.0 \n"
  echo "  -v Version: i.e. 7.2.0, 3.1.0 \n"
  echo "  -b Build: i.e. 123 \n"
  echo "  optional: \n"
  echo "  -e Edition: enterprise(default)|community \n"
  echo "  -a Arch: x86_64(default)|arm64 \n"
  echo "  -n: notarize\n"
  echo "  -d: download\n"
}

function unlock_keychain
{
    #unlock keychain
    echo "------- Unlocking keychain -----------"
    security unlock-keychain -p ${KEYCHAIN_PASSWORD} ${HOME}/Library/Keychains/login.keychain-db
}

function codesign_pkg
{
    pkg_dir=$1
    pkg_signed=$2
    echo "pkg_dir $pkg_dir\n"
    echo "pkg_signed $pkg_signed\n"
    echo "------- Codesigning binaries within the package -------"
    find ${pkg_dir} -type f | while IFS= read -r file
    do
        ##binaries in jars have to be signed.
        if [[ "${file}" =~ ".jar" ]]; then
            libs=$(jar -tf "${file}" | grep "META-INF" | grep ".jnilib\|.dylib")
            if [[ ! -z ${libs} ]]; then
                for lib in ${libs}; do
                    jar xf "${file}" "${lib}"
                    codesign ${(z)SIGN_FLAGS} --sign ${CERT_NAME} "${lib}"
                    jar uf "${file}" "${lib}"
                done
                rm -rf META-INF
            fi
        elif [[ `file --brief "${file}"` =~ "Mach-O" ]]; then
            codesign ${(z)SIGN_FLAGS} --sign ${CERT_NAME} "${file}"
        fi
    done

    echo "------- Codesigning the package ${pkg_signed} -------"
    pushd ${pkg_dir}
    zip --symlinks -r -X ../${pkg_signed} *
    popd
    codesign ${(z)SIGN_FLAGS} --sign ${CERT_NAME} ${pkg_signed}
}

function notarize_pkg
{
    pkg_signed=$1
    echo "-------Notarizing for ${pkg_signed}-------"
    xml_output=$(xcrun altool --notarize-app -t osx \
        -f ${pkg_signed} \
        --primary-bundle-id couchbase-sync-gateway \
        -u build-team@couchbase.com -p ${AC_PASSWORD} \
        --output-format xml
    )
    if [ $? != 0 ]; then
        echo "Error running notarize command!"
        exit 1
    fi
    request_id=$(echo "${xml_output}" | xmllint --xpath '//dict[key/text() = "RequestUUID"]/string/text()' -
    )
    echo "Notarization request has been uploaded - request ID is ${request_id}"

    # Sometime, there might be a delay for request ID to propagate to all servers
    sleep 30

    while true; do
        output=$(xcrun altool --notarization-info ${request_id} \
            -u build-team@couchbase.com -p ${AC_PASSWORD} 2>&1
        )
        current_status=$(echo "${output}" | grep "Status:")
        if [[ ${current_status} =~ "success" ]]; then
            echo "Request ${request_id} succeeded!"
            exit
        elif [[ ${current_status} =~ "in progress" ]]; then
            echo "Request ${request_id} still in progress..."
        else
            echo @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
            echo "Request ${request_id} failed notarization!"
            echo "${xml_output}"
            echo @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
            exit 1
        fi
        echo "Wait for a minute before checking it again..."
        sleep 60
    done
    ### https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow
    ### Currently, it is not possible to staple ticket to standalone binaries.  Hence, we skip it for now.
}

##Main

#unlock keychain
unlock_keychain

NOTARIZE=false
ARCH=x86_64
EDITION=enterprise
DOWNLOAD=false

while getopts a:b:e:p:r:v:nd opt
do
  case ${opt} in
    a)
      ARCH=${OPTARG}
      ;;
    b) BUILD_NUM=${OPTARG}
      ;;
    e) EDITION=${OPTARG}
      ;;
    p) PRODUCT=${OPTARG}
      ;;
    r) RELEASE=${OPTARG}
      ;;
    v) VERSION=${OPTARG}
      ;;
    n) NOTARIZE=true
      ;;
    d) DOWNLOAD=true
      ;;
    *)
      usgae
      ;;
    esac
done

if [[ -z ${PRODUCT} || -z ${VERSION} || -z ${RELEASE} || -z ${BUILD_NUM} ]]; then
    usage
    exit 1;
fi

SIGN_FLAGS="--force --timestamp --options=runtime  --verbose --entitlements cb.entitlement --preserve-metadata=identifier,requirements"
CERT_NAME="Developer ID Application: Couchbase, Inc. (N2Q372V7W2)"

PKG_URL=http://latestbuilds.service.couchbase.com/builds/latestbuilds/${PRODUCT}/${RELEASE}/${BUILD_NUM}

declare -A PKGS
declare -A PKGS_SIGNED

case ${PRODUCT} in
sync_gateway)
    PKGS[couchbase-sync-gateway]=couchbase-sync-gateway-${EDITION}_${VERSION}-${BUILD_NUM}_${ARCH}_unsigned.zip
    PKGS_SIGNED[couchbase-sync-gateway]=couchbase-sync-gateway-${EDITION}_${VERSION}-${BUILD_NUM}_${ARCH}.zip
    ;;
couchbase-lite-c)
    PKGS[${PRODUCT}]=${PRODUCT}-${EDITION}-${VERSION}-${BUILD_NUM}-macos_unsigned.zip
    PKGS_SIGNED[${PRODUCT}]=${PRODUCT}-${EDITION}-${VERSION}-${BUILD_NUM}-macos.zip
    PKGS[${PRODUCT}-symbols]=${PRODUCT}-${EDITION}-${VERSION}-${BUILD_NUM}-macos_unsigned.zip
    PKGS_SIGNED[${PRODUCT}-symbols]=${PRODUCT}-${EDITION}-${VERSION}-${BUILD_NUM}-macos.zip
    ;;
couchbase-server)
    PKGS[${PRODUCT}]=${PRODUCT}-tools_${VERSION}-${BUILD_NUM}-macos_${ARCH}_unsigned.zip
    PKGS_SIGNED[${PRODUCT}]=${PRODUCT}-tools_${VERSION}-${BUILD_NUM}-macos_${ARCH}.zip
    ;;
*)
    echo "Unsupported product ${PRODUCT}, exit now..."
    exit 1
    ;;
esac

for pkg pkg_name in ${(@kv)PKGS}; do
    rm -rf ${pkg}
    if [[ ${DOWNLOAD} == "true" ]]; then
        curl -LO ${PKG_URL}/${pkg_name}
    fi

    mkdir ${pkg}
    unzip -qq ${pkg_name} -d ${pkg}
    codesign_pkg ${pkg} ${PKGS_SIGNED[${pkg}]}

    if [[ ${NOTARIZE} != "true" ]]; then
        echo "notarization option is set to ${NOTARIZE}"
        echo "skip notarization..."
        exit
    else
        notarize_pkg ${PKGS_SIGNED[${pkg}]}
    fi
done
