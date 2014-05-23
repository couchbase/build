#!/bin/bash
#
#          run by jenkins job 'build_tuqtng'
#
#          with no paramters
#
source ~jenkins/.bash_profile
set -e

GITSPEC=master
VERSION=1.0.0
REVISION=${VERSION}-${BUILD_NUMBER}

LICENSE=license-ce.txt
PROJECT=github.com/couchbaselabs/tuqtng
export GOPATH=${WORKSPACE}

env | grep -iv password | grep -iv passwd | sort -u
echo ==============================================

PROJDIR=src/github.com/couchbaselabs/tuqtng
cd   ${WORKSPACE}
echo ======== sync tuqtng =========================

###################################
#Manifest file
###################################

cd ${WORKSPACE}
touch manifest.txt
echo 'temporary manifest file' > ${WORKSPACE}/manifest.txt

go get github.com/couchbaselabs/tuqtng/...
cd ${WORKPSPACE}/build/scripts/jenkins/query/
./go-manifest > current-versions_${REVISION}
./go-set-version current-versions_${REVISION}


TOPD=${WORKSPACE}/src/${PROJECT}
top=${TOPD}
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
    goflags="-v -ldflags '-X main.VERSION ${REVISION}'"

    echo "------- building cbq-engine.lin32 ----------"
    eval GOARCH=386           GOOS=linux   CGO_ENABLED=0 go build -o dist/cbq-engine.lin32     $goflags $pkg
  # echo "------- building cbq-engine.arm ------------"
  # eval GOARCH=arm           GOOS=linux   CGO_ENABLED=0 go build -o dist/cbq-engine.arm       $goflags $pkg
  # echo "------- building cbq-engine.arm5 -----------"
  # eval GOARCH=arm   GOARM=5 GOOS=linux   CGO_ENABLED=0 go build -o dist/cbq-engine.arm5      $goflags $pkg
    echo "------- building cbq-engine.lin64 ----------"
    eval GOARCH=amd64         GOOS=linux   CGO_ENABLED=0 go build -o dist/cbq-engine.lin64     $goflags $pkg
    echo "------- building cbq-engine.fbsd -----------"
    eval GOARCH=amd64         GOOS=freebsd CGO_ENABLED=0 go build -o dist/cbq-engine.fbsd      $goflags $pkg
    echo "------- building cbq-engine.win32.exe ------"
    eval GOARCH=386           GOOS=windows               go build -o dist/cbq-engine.win32.exe $goflags $pkg
    echo "------- building cbq-engine.win64.exe ------"
    eval GOARCH=amd64         GOOS=windows               go build -o dist/cbq-engine.win64.exe $goflags $pkg
    echo "------- building cbq-engine.mac ------------"
    eval GOARCH=amd64         GOOS=darwin                go build -o dist/cbq-engine.mac       $goflags $pkg
    }

function build_client
    {
    echo "------- starting build_client --------------"
    pkg=${PROJECT}/cbq
    goflags="-v -ldflags '-X main.VERSION ${REVISION}'"

    eval GOARCH=386           GOOS=linux   CGO_ENABLED=0 go build -o $DIST/cbq.lin32     $goflags $pkg
  # eval GOARCH=arm           GOOS=linux   CGO_ENABLED=0 go build -o $DIST/cbq.arm       $goflags $pkg
  # eval GOARCH=arm   GOARM=5 GOOS=linux   CGO_ENABLED=0 go build -o $DIST/cbq.arm5      $goflags $pkg
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
    cd $DIST/..
    cd tutorial
    go build
    cd $top
    tutorial/tutorial -src tutorial/content/ -dst $DIST/tutorial_tmp/
    
    build_pkg  cbq-engine.lin32      cbq.lin32      couchbase-query_x86_linux_${REVISION}.tar.gz     tar
    build_pkg  cbq-engine.lin64      cbq.lin64      couchbase-query_x86_64_linux_${REVISION}.tar.gz  tar
    build_pkg  cbq-engine.mac        cbq.mac        couchbase-query_x86_64_mac_${REVISION}.zip       zip
    build_pkg  cbq-engine.win32.exe  cbq.win32.exe  couchbase-query_x86_win_${REVISION}.zip          zip
    build_pkg  cbq-engine.win64.exe  cbq.win64.exe  couchbase-query_x86_64_win_${REVISION}.zip       zip
    }


function compress
    {
    echo "------- starting compress ------------------"
    rm -f $DIST/tuqtng.*.gz $DIST/cbq.*.gz $DIST/tuq_tutorial.*.gz || true

    for i in $DIST/tuqtng.* $DIST/cbq.*
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

function s3_upload
    {
     echo "------- starting upload --------------------"
     echo  ======= upload ==============================
     s3cmd put -v -P  ${REVISION} s3://packages.couchbase.com/builds/query/tuqtng/${VERSION}/
     cd $DIST
     echo ............... uploading packages to s3://packages.couchbase.com/builds/query/tuqtng/${VE
RSION}/${REVISION}/
     s3cmd put -v -P  *.tar.gz    s3://packages.couchbase.com/builds/query/tuqtng/${VERSION}/${REVIS
ION}/
     s3cmd put -v -P  *.zip       s3://packages.couchbase.com/builds/query/tuqtng/${VERSION}/${REVIS
ION}/
     cd ${WORKPSPACE}/build/scripts/jenkins/query/
     s3cmd put -v -P  current-versions_${REVISION}    s3://packages.couchbase.com/builds/query/tuqtng/${VERSION}/${REVIS
ION}/
    }



#testpkg
mkversion
build_engine
build_client
build_dist_packages
s3_upload
#compress
#benchmark
#coverage
