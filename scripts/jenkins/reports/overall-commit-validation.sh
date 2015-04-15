#!/bin/bash

# Overall commit validation script for following projects: couchstore, libmemcached, platform, testrunner, couchdb
#                     
#
#
#
#

echo ==========================
echo script start time
echo =========================

STARTTIME=$(date +%s)

echo ===========================
echo PRODUCT IS COUCHSTORE
echo ===========================

cd ${WORKSPACE}
 
source ~jenkins/.bash_profile
set -e
ulimit -a

cat <<EOF
============================================
===                `date "+%H:%M:%S"`              ===
============================================
EOF

env | grep -iv password | grep -iv passwd | sort

cat <<EOF
============================================
===               clean                  ===
============================================
EOF
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
make clean-xfd-hard

cat <<EOF
============================================
===         update couchstore            ===
============================================
EOF

cd ${WORKSPACE}
if [ -d "couchstore" ]; then
  rm -rf couchstore
fi

git clone https://github.com/couchbase/couchstore.git

cat <<EOF
============================================
===               Build                  ===
============================================
EOF
cd ${WORKSPACE}
make -j4 all || (make -j1 && false)
if [ -d build ]
then
   make install
fi

cat <<EOF
============================================
===          Run unit tests              ===
============================================
EOF
if [ -d build/couchstore ]
then
  pushd build/couchstore 2>&1 > /dev/null
else
  pushd couchstore 2>&1 > /dev/null
fi

make test
cd ${WORKSPACE}

cat <<EOF
============================================
===         Run end to end tests         ===
============================================
EOF

cd testrunner
make simple-test

cat <<EOF
============================================
===                `date "+%H:%M:%S"`              ===
============================================
EOF
sudo killall -9 beam.smp epmd memcached python >/dev/null || true

echo ================================
echo PROJECT IS NS_SERVER
echo ================================


cd ${WORKSPACE}


echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ clean and fetch
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
make clean-xfd-hard


cd ${WORKSPACE}
if [ -d "ns_server" ]; then
  rm -rf ns_server
fi

git clone https://github.com/couchbase/ns_server.git

cd ${WORKSPACE}
echo ============================================ make

make -j4 all install

echo ============================================ make simple
cd testrunner
make simple-test
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
sleep 30
scripts/start_cluster_and_run_tests.sh b/resources/dev-4-nodes.ini conf/py-viewmerge.conf

echo ============================================ `date`


cd ${WORKSPACE}

echo==============
echo  PROJECT is LIBMEMCACHED
echo==============


echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ clean
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
make clean-xfd-hard

echo ============================================ update memcached

cd ${WORKSPACE}
if [ -d "libmemcached" ]; then
  rm -rf libmemcached
fi
git clone https://github.com/couchbase/libmemcached.git


echo ============================================ make
popd 2>&1 > /dev/null
make -j4 all install
echo ============================================ make simple-test

cd ${WORKSPACE}
make simple-test
sudo killall -9 beam.smp epmd memcached python >/dev/null || true

echo ============================================ `date`



echo =================
echo PROJECT is PLATFORM
echo ==============


cd ${WORKSPACE}

echo platform

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ clean
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
make clean-xfd-hard

echo ============================================ update platform

cd ${WORKSPACE}
if [ -d "platform" ]; then
  rm -rf platform
fi
git clone https://github.com/couchbase/platform.git

echo ============================================ make

cd ${WORKSPACE}
make -j4 all install

pushd build/platform 2>&1 > /dev/null
make test
popd 2>&1 > /dev/null

echo ============================================ make simple-test
cd testrunner
make simple-test
sudo killall -9 beam.smp epmd memcached python >/dev/null || true

echo ============================================ `date`

echo ================
echo PROJECT is TESTRUNNER
echo ================



cd ${WORKSPACE}

echo testrunner

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ clean
rm -rf testrunner/cluster_run.log
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
make clean-xfd-hard
repo forall -c "git clean -xfd"

echo ============================================ update testrunner
cd ${WORKSPACE}/testrunner
git reset --hard HEAD

cd ${WORKSPACE}
if [ -d "testrunner" ]; then
  rm -rf testrunner
fi
git clone https://github.com/couchbase/testrunner.git

echo ============================================ make
cd ${WORKSPACE}
make all install
echo ============================================ make simple-test
cd testrunner
make simple-test
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
zip cluster_run_log cluster_run.log
echo ============================================ `date`

cd ${WORKSPACE}


echo================
echo PROJECT is COUCHDB
echo================

cat <<EOF
============================================
=== `date "+%H:%M:%S"` ===
============================================
EOF
env | grep -iv password | grep -iv passwd | sort

cat <<EOF
============================================
=== clean ===
============================================
EOF
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
make clean-xfd-hard

cat <<EOF
============================================
=== update CouchDB ===
============================================
EOF

cd ${WORKSPACE}
if [ -d "couchdb" ]; then
  rm -rf couchdb
fi
git clone https://github.com/couchbase/couchbdb.git


cat <<EOF
============================================
=== Build ===
============================================
EOF

# Copy couchdb.plt from ${WORKSPACE} to ${WORKSPACE}/build/couchdb to gain build time

mkdir -p ${WORKSPACE}/build/couchdb

if [ -f ${WORKSPACE}/couchdb.plt ]
then
cp ${WORKSPACE}/couchdb.plt ${WORKSPACE}/build/couchdb/
fi


cd ${WORKSPACE}
make -j4 all install || (make -j1 && false)

cat <<EOF
============================================
=== Run unit tests ===
============================================
EOF

if [ -d build/couchdb ]
then
pushd build/couchdb 2>&1 > /dev/null
else
pushd couchdb 2>&1 > /dev/null
fi

cpulimit -e 'beam.smp' -l 50 &

CPULIMIT_PID=$!
PATH=$PATH:${WORKSPACE}/couchstore make check

kill $CPULIMIT_PID || true
cd ${WORKSPACE}

cat <<EOF
============================================
=== Run end to end tests ===
============================================
EOF
pushd testrunner 2>&1 > /dev/null
make simple-test
popd 2>&1 > /dev/null


cat <<EOF
============================================
=== `date "+%H:%M:%S"` ===
============================================
EOF
sudo killall -9 beam.smp epmd memcached python >/dev/null || true

===================================================
=== Calculate elapsed time at the end of the script
===================================================

ENDTIME=$(date +%s)

dt=$(($ENDTIME - $STARTTIME))

echo "It takes $(($ENDTIME - $STARTTIME)) seconds to complete this task.../n"

ds=$((dt % 60))
dm=$(((dt / 60) % 60))
dh=$((dt / 3600))
printf '%d:%02d:%02d' $dh $dm $ds



