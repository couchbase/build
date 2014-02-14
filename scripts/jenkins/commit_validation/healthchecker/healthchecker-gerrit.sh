#!/bin/bash
#          
#          run by jenkins job 'healthchecker-gerrit-master'
#                             healthchecker-gerrit-300
#                             healthchecker-gerrit-250
#          with no paramters
#          
#          triggered on Patchset Creation of repo: healthchecker branch: master

source ~jenkins/.bash_profile
set -e
ulimit -a

echo ============================================ `date`
env | grep -iv password | grep -iv passwd | sort

echo ============================================ clean
sudo killall -9 beam.smp epmd memcached python >/dev/null || true

make clean-xfd-hard

cd cmake/healthchecker
git fetch ssh://review.couchbase.org:29418/healthchecker $GERRIT_REFSPEC && git checkout FETCH_HEAD

echo ============================================ make
cd ../..
make -j4
echo ============================================ make simple-test
cd testrunner
make simple-test

cd ..

Line1="clitest.healthcheckertest.HealthcheckerTests:"
Line2="     healthchecker_test,sasl_buckets=1,doc_ops=update,GROUP=P0"
Line3="     healthchecker_test,standard_buckets=1,doc_ops=delete,GROUP=P0"

cat > ./cbhealthchecker.conf << EOL
${Line1}
${Line2}
${Line3}
EOL

IP=`/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;

echo "IP is  $IP";

iniLine1=“[global]"
iniLine2=“username:root"
iniLine3=password:couchbase"
iniLine4=“port:8091"
iniLine5=“”
iniLine6=“[servers]"
iniLine7=“1:$IP"
iniLine8=“"
iniLine9=“[membase]"
iniLine10=“rest_username:Administrator"
iniLine11=“rest_password:password”

cat > ./ini_file.ini << EOL
${iniLine1}
${iniLine2}
${iniLine3}
${iniLine4}
${iniLine5}
${iniLine6}
${iniLine7}
${iniLine8}
${iniLine9}
${iniLine10}
${iniLine11}
EOL

python ./testrunner -i ini_file.ini -c cbhealthchecker.conf -p get_collectinfo=true

sudo killall -9 beam.smp epmd memcached python  2>&1 > /dev/null || true

echo ============================================ `date`

