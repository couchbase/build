#!/bin/bash -xe

CB_DSN=${CB_DSN:-127.0.0.1}
CB_BUCKET=${CB_BUCKET:-default}
CB_ADMIN_USER=${CB_ADMIN_USER:-Administrator}
CB_ADMIN_PASSWORD=${CB_ADMIN_USER:-password}
CB_USER=${CB_USER:-default}
CB_PASSWORD=${CB_PASSWORD}

export CB_DSN CB_BUCKET CB_ADMIN_USER CB_ADMIN_PASSWORD CB_USER CB_PASSWORD

# phpunit needs 5.6 always
PHP_DIR="${BBSDK}/php-files/build/${phpver}-${phpts}-${arch}"

LCB_PATH="${BBSDK}/lcb-files/dist/${LCBVER}-${arch}/lib"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$LCB_PATH

rm -rf core*
# allow to generate coredumps
ulimit -c unlimited
# display coredump pattern
/sbin/sysctl kernel.core_pattern || /usr/sbin/sysctl kernel.core_pattern || sysctl kernel.core_pattern || true

# Test
PHP_CMD="${PHP_DIR}/bin/php -d extension=phar.so -d extension=igbinary.so -d extension=$(pwd)/modules/couchbase.so -d couchbase.log_level=TRACE"
${PHP_CMD} -m
${PHP_CMD} ${PHP_DIR}/phpunit.phar --verbose tests/ || \
if [ -x /usr/bin/gdb ]; then
  shopt -s nullglob
  for c in core* /tmp/core* /var/crash/*; do
    ls -l $c
    file $c
    gdb --batch --quiet -ex "thread apply all bt full" -ex "quit" ${PHP_DIR}/bin/php $c
  done
  exit 1
fi
