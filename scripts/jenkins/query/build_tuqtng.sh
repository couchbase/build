#!/bin/bash
#
#          run by jenkins jobs: 'build_tuqtng_master'
#                               'build_tuqtng_100'
#
#          called with parameters:    branch          release    build_number
#
#          by build_tuqtng_master:    master          0.0.0      nnnn
#
#          by build_tuqtng_100:       release/1.0.0   1.0.0      mmmm

source ~jenkins/.bash_profile
set -e

LICENSE=license-ce.txt
PROJECT=github.com/couchbaselabs/tuqtng
export GOPATH=${WORKSPACE}

PROJDIR=src/github.com/couchbaselabs/tuqtng
cd   ${WORKSPACE}

function usage
	{
	echo -e "\nuse: ${0}  branch_name  release_number  build_number\n\n"
	}
	
if [[ ! ${1} ]] ; then usage ; exit 99 ; fi
GITSPEC=${1}

if [[ ! ${2} ]] ; then usage ; exit 88 ; fi
RELEASE=${2}

if [[ ! ${3} ]] ; then usage ; exit 77 ; fi
BLD_NUM=${3}

REVISION=${RELEASE}-${BLD_NUM}

S3_REPO=s3://packages.couchbase.com/builds/query/tuqtng/${RELEASE}/${REVISION}

UPLOADS="manifest.txt                                      \
         couchbase-query_x86_linux_${REVISION}.tar.gz tar   \
         couchbase-query_x86_64_linux_${REVISION}.tar.gz tar \
         couchbase-query_x86_64_mac_${REVISION}.zip zip       \
         couchbase-query_x86_win_${REVISION}.zip zip           \
         couchbase-query_x86_64_win_${REVISION}.zip             \
         "
BLD_DIR=${WORKSPACE}/build

AUT_DIR=${WORKSPACE}/app-under-test
if [[ -e ${AUT_DIR} ]] ; then rm -rf ${AUT_DIR} ; fi
mkdir -p ${AUT_DIR}


TOPD=${AUT_DIR}/src/${PROJECT}
DIST=${TOPD}/dist


env | grep -iv password | grep -iv passwd | sort -u
echo ==============================================

echo ============================================== sync tuqtng
echo ============================================== to ${GITSPEC}
cd ${AUT_DIR}
if [[ ! -d tuqtng ]] ; then git clone https://github.com/couchbaselabs/tuqtng.git ; fi			
cd         tuqtng
git checkout    ${GITSPEC}
git pull origin ${GITSPEC}
git show --stat

cd ${AUT_DIR}/tuqtng
go get github.com/couchbaselabs/tuqtng/...

echo ============================================== generate manifest.txt
${BLD_DIR}/scripts/jenkins/query/go-manifest       > ${DIST}/manifest.txt

echo ============================================== insert meta-data
echo "{\"version\": \"${REVISION}\"}"              > ${DIST}/version.json




function testpkg
    {
    go test ${PROJECT}/...
    go vet  ${PROJECT}/...
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
    cd ${TOPD}
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
    cd ${TOPD}/test
    gocov test -deps -exclude-goroot > $DIST/integ.json
    cat $DIST/integ.json | jq '{"Packages": [.Packages[] | if .Name > "github.com/couchbaselabs/tuqtng" and .Name < "github.com/couchbaselabs/tuqtnh" then . else empty end]}' > $DIST/integ2.json
    cat $DIST/integ2.json |gocov-html > $DIST/integ-cov.html
    cd ${TOPD}
    }


function s3_upload
    {
    echo "------- starting upload --------------------"
    for ARTIFACT in ${UPLOADS}
      do
        echo  ======= upload ============================== ${S3_REPO}/${ARTIFACT}
        s3cmd put -v -P  ${DIST}/${ARTIFACT}  ${S3_REPO}/${ARTIFACT}
    done
    }



                       #testpkg
#                       mkversion
build_engine
build_client
build_dist_packages
#                       go-manifest
s3_upload
                       #compress
                       #benchmark
                       #coverage
