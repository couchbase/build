#!/bin/bash
#
#          run by jenkins job 'build_tuqtng'
#
#          with no paramters
#
source ~jenkins/.bash_profile
set -e
CBFS_URL=http://cbfs.hq.couchbase.com:8484/tuqtng

GITSPEC=master
VERSION=1.0
REVISION=${VERSION}-${BUILD_NUMBER}

LICENSE=license-ce-2013.txt
PROJECT=github.com/couchbaselabs/tuqtng
export GOPATH=${WORKSPACE}/build_tuqtng

env | grep -iv password | grep -iv passwd | sort -u
echo ==============================================

PROJDIR=src/github.com/couchbaselabs/tuqtng
cd   ${WORKSPACE}
echo ======== sync tuqtng =========================

if [[ ! -d ${PROJDIR} ]] ; then git clone https://github.com/couchbaselabs/tuqtng.git        ${PROJDIR} ; fi
cd         ${PROJDIR}
git  pull  origin  ${GITSPEC}
git  show --stat

PROJDIR=src/github.com/couchbaselabs/dparval
cd   ${WORKSPACE}
echo ======== sync dparval ========================

if [[ ! -d ${PROJDIR} ]] ; then git clone https://github.com/couchbaselabs/dparval.git       ${PROJDIR} ; fi
cd         ${PROJDIR}
git  pull  origin  ${GITSPEC}
git  show --stat

PROJDIR=src/github.com/couchbaselabs/clog
cd   ${WORKSPACE}
echo ======== sync clog ===========================

if [[ ! -d ${PROJDIR} ]] ; then git clone https://github.com/couchbaselabs/clog.git          ${PROJDIR} ; fi
cd         ${PROJDIR}
git  pull  origin  ${GITSPEC}
git  show --stat

PROJDIR=src/github.com/couchbaselabs/go-couchbase
cd   ${WORKSPACE}
echo ======== sync go-couchbase ===================

if [[ ! -d ${PROJDIR} ]] ; then git clone https://github.com/couchbaselabs/go-couchbase.git  ${PROJDIR} ; fi
cd         ${PROJDIR}
git  pull  origin  ${GITSPEC}
git  show --stat

PROJDIR=src/github.com/dustin/go-jsonpointer
cd   ${WORKSPACE}
echo ======== sync dustin/go-jsonpointer ==========

if [[ ! -d ${PROJDIR} ]] ; then git clone https://github.com/dustin/go-jsonpointer.git       ${PROJDIR} ; fi
cd         ${PROJDIR}
git  pull  origin  ${GITSPEC}
git  show --stat

PROJDIR=src/github.com/dustin/gojson
cd   ${WORKSPACE}
echo ======== sync dustin/gojson ==================

if [[ ! -d ${PROJDIR} ]] ; then git clone https://github.com/dustin/gojson.git               ${PROJDIR} ; fi
cd         ${PROJDIR}
git  pull  origin  ${GITSPEC}
git  show --stat

PROJDIR=src/github.com/dustin/gomemcached
cd   ${WORKSPACE}
echo ======== sync dustin/gomemcached =============

if [[ ! -d ${PROJDIR} ]] ; then git clone https://github.com/dustin/gomemcached.git         ${PROJDIR} ; fi
cd         ${PROJDIR}
git  pull  origin  ${GITSPEC}
git  show --stat

PROJDIR=src/github.com/gorilla/mux
cd   ${WORKSPACE}
echo ======== sync gorilla/mux ====================

if [[ ! -d ${PROJDIR} ]] ; then git clone https://github.com/gorilla/mux.git                 ${PROJDIR} ; fi
cd         ${PROJDIR}
git  pull  origin  ${GITSPEC}
git  show --stat

PROJDIR=src/github.com/gorilla/context
cd   ${WORKSPACE}
echo ======== sync gorilla/context ================

if [[ ! -d ${PROJDIR} ]] ; then git clone https://github.com/gorilla/context.git             ${PROJDIR} ; fi
cd         ${PROJDIR}
git  pull  origin  ${GITSPEC}
git  show --stat
echo ==============================================


TOPD=${WORKSPACE}/src/${PROJECT}
DIST=${TOPD}/dist
cd   ${TOPD}


function testpkg
    {
    go test ${PROJECT}/...
    go vet  ${PROJECT}/...
    }

function mkversion
    {
    echo "------- starting mkversion -----------------"
    echo "{\"version\": \"${REVISION}\"}" > $DIST/version.json
    }

function build_engine
    {
    echo "------- starting build_engine --------------"
    pkg=${PROJECT}
    goflags="-v -ldflags '-X \"main.VERSION ${REVISION}\"'"

    echo "------- building cbq-engine.lin32 ----------"
    eval GOARCH=386           GOOS=linux   CGO_ENABLED=0 go build $goflags -o dist/cbq-engine.lin32     $pkg
    echo "------- building cbq-engine.arm ------------"
    eval GOARCH=arm           GOOS=linux   CGO_ENABLED=0 go build $goflags -o dist/cbq-engine.arm       $pkg
    echo "------- building cbq-engine.arm5 -----------"
    eval GOARCH=arm   GOARM=5 GOOS=linux   CGO_ENABLED=0 go build $goflags -o dist/cbq-engine.arm5      $pkg
    echo "------- building cbq-engine.lin64 ----------"
    eval GOARCH=amd64         GOOS=linux   CGO_ENABLED=0 go build $goflags -o dist/cbq-engine.lin64     $pkg
    echo "------- building cbq-engine.fbsd -----------"
    eval GOARCH=amd64         GOOS=freebsd CGO_ENABLED=0 go build $goflags -o dist/cbq-engine.fbsd      $pkg
    echo "------- building cbq-engine.win32.exe ------"
    eval GOARCH=386           GOOS=windows               go build $goflags -o dist/cbq-engine.win32.exe $pkg
    echo "------- building cbq-engine.win64.exe ------"
    eval GOARCH=amd64         GOOS=windows               go build $goflags -o dist/cbq-engine.win64.exe $pkg
    echo "------- building cbq-engine.mac ------------"
    eval GOARCH=amd64         GOOS=darwin                go build $goflags -o dist/cbq-engine.mac       $pkg
    }

function build_client
    {
    echo "------- starting build_client --------------"
    pkg=${PROJECT}/tuq_client
    goflags="-v -ldflags '-X main.VERSION ${REVISION}'"

    eval GOARCH=386           GOOS=linux   CGO_ENABLED=0 go build -o $DIST/cbq.lin32     $goflags $pkg
    eval GOARCH=arm           GOOS=linux   CGO_ENABLED=0 go build -o $DIST/cbq.arm       $goflags $pkg
    eval GOARCH=arm   GOARM=5 GOOS=linux   CGO_ENABLED=0 go build -o $DIST/cbq.arm5      $goflags $pkg
    eval GOARCH=amd64         GOOS=linux   CGO_ENABLED=0 go build -o $DIST/cbq.lin64     $goflags $pkg
    eval GOARCH=amd64         GOOS=freebsd CGO_ENABLED=0 go build -o $DIST/cbq.fbsd      $goflags $pkg
    eval GOARCH=386           GOOS=windows               go build -o $DIST/cbq.win32.exe $goflags $pkg
    eval GOARCH=amd64         GOOS=windows               go build -o $DIST/cbq.win64.exe $goflags $pkg
    eval GOARCH=amd64         GOOS=darwin                go build -o $DIST/cbq.mac       $goflags $pkg
    }

function build_pkg
    {
    echo "------- starting build_pkg -----------------"
    ENGINE=$1
    CLIENT=$2
    PKGNAM=$3
    PKGTYP=$4
    
    if [[ ${PKGTYP} == zip ]] ; then CMD='zip -r'   ; fi
    if [[ ${PKGTYP} == tar ]] ; then CMD='tar zcvf' ; fi
    
    mkdir -p                     $DIST/stage
    cp $DIST/README              $DIST/stage
    cp $DIST/${LICENSE}          $DIST/stage/LICENSE.txt
    cp $DIST/start_tutorial.sh   $DIST/stage
    cp $DIST/${ENGINE}           $DIST/stage/cbq-engine
    cp $DIST/${CLIENT}           $DIST/stage/cbq
    
    cp -r static/                                 $DIST/stage/static
    mkdir -p                                      $DIST/stage/static/tutorial
    cp -r    $DIST/tutorial_tmp/tutorial/content/ $DIST/stage/static/tutorial
    
    mkdir -p                            $DIST/stage/data/default/tutorial
    unzip tutorial/data/sampledb.zip -d $DIST/stage/data/default/
    
    pushd   $DIST/stage     > /dev/null
    ${CMD}  $DIST/${PKGNAM} .
    popd                    > /dev/null
    rm -rf  $DIST/stage
    }

function build_dist_packages
    {
    echo "------- starting build_dist_packages -------"
    mkdir -p $DIST/tutorial_tmp
    cd tutorial
    go build
    cd $top
    tutorial/tutorial -src tutorial/content/ -dst $DIST/tutorial_tmp/
    
    build_pkg  cbq-engine.lin32      cbq.lin32      couchbase-query_dev_preview1_x86_linux.tar.gz     tar
    build_pkg  cbq-engine.lin64      cbq.lin64      couchbase-query_dev_preview1_x86_64_linux.tar.gz  tar
    build_pkg  cbq-engine.mac        cbq.mac        couchbase-query_dev_preview1_x86_64_mac.zip       zip
    build_pkg  cbq-engine.win32.exe  cbq.win32.exe  couchbase-query_dev_preview1_x86_win.zip          zip
    build_pkg  cbq-engine.win64.exe  cbq.win64.exe  couchbase-query_dev_preview1_x86_64_win.zip       zip
    }


function compress
    {
    echo "------- starting compress ------------------"
    rm -f $DIST/tuqtng.*.gz $DIST/tuq_client.*.gz $DIST/tuq_tutorial.*.gz || true

    for i in $DIST/tuqtng.* $DIST/tuq_client.*
    do
        gzip -9v $i
    done
    }

function benchmark
    {
    echo "------- starting benchmark -----------------"
    go test -test.bench . > $DIST/benchmark.txt
    }

function coverage
    {
    echo "------- starting coverage ------------------"
    for sub in ast misc plan test xpipeline
    do
        gocov test ${PROJECT}/$sub | gocov-html > $DIST/cov-$sub.html
    done
    cd $top/test
    gocov test -deps -exclude-goroot > $DIST/integ.json
    cat $DIST/integ.json | jq '{"Packages": [.Packages[] | if .Name > "github.com/couchbaselabs/tuqtng" and .Name < "github.com/couchbaselabs/tuqtnh" then . else empty end]}' > $DIST/integ2.json
    cat $DIST/integ2.json |gocov-html > $DIST/integ-cov.html
    cd $top
    }

function upload
    {
    echo "------- starting upload --------------------"
    echo  ======= upload ==============================
    for PKG in couchbase-query_dev_preview1_x86_linux.tar.gz   \
               couchbase-query_dev_preview1_x86_64_linux.tar.gz \
               couchbase-query_dev_preview1_x86_64_mac.zip       \
               couchbase-query_dev_preview1_x86_win.zip           \
               couchbase-query_dev_preview1_x86_64_win.zip
    do
        echo ............... uploading to ${CBFS_URL}/${PKG}
        curl -XPUT --data-binary  @${PKG} ${CBFS_URL}/${PKG}
    done
    HTML=redirect.html
    echo ............... uploading to ${CBFS_URL}/${HTML}
    curl -XPUT --data-binary @${HTML} ${CBFS_URL}/${HTML}
    }

#testpkg
mkversion
build_engine
build_client
build_dist_packages
#compress
#benchmark
#coverage
#upload
