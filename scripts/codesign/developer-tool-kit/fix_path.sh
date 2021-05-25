#!/bin/bash -ex


display_usage()
{
  echo "\nUsage: $0 -d <Dist Dir> \n"
  echo "  Dist Dir:  i.e. /opt/couchbase \n"
}

while getopts d: opt
do
  case "${opt}" in
    d) distdir=${OPTARG}
      ;;
    :)
      display_usgae
      ;;
    esac
done

clean_lib() {
  echo "Cleaning $1"
  while read something
  do
    base=${something##*/}
    echo "  Fixing $something -> lib/$base"
    test -f "$distdir/lib/$base" || cp "$something" "$distdir/lib/$base"
    chmod 755 "$distdir/lib/$base"
    install_name_tool -change "$something" "@executable_path/../lib/$base" "$1"
  done
}

if [[ -z "$distdir" ]]; then
  display_usage
  exit 1;
fi

if [[ ! -d $distdir ]]; then
  echo "distdir $distdir does not exist. \n"
  exit 1;
fi

# According to old fix_path.sh in couchdbx, clean_lib needs to 
# run multiple times so it picks up libs that got pulled in.
for i in 1 2 3
do
    for fn in "$distdir/lib/"*.dylib
    do
        chmod +w "$fn"
        otool -L "$fn" | egrep -v "^[/a-z]" | grep -v /usr/lib \
            | sed -e 's/(\(.*\))//g' | clean_lib "$fn"
    done
done

for f in $distdir/bin/couchdb $distdir/bin/couchjs $distdir/lib/erlang/bin/erl
do
    grep -qF 'SCRIPT=`realpath $0`' $f | sed -i '' '2i\
    SCRIPT=`realpath $0`
    ' $f

    grep -qF 'SCRIPT_DIR=`dirname $SCRIPT`' $f | sed -i '' '3i\
    SCRIPT_DIR=`dirname $SCRIPT`
    ' $f

done

# realpath returns different values, when running erl in bin or lib/erlang/bin.
# This leads to different ROOTDIR.  Thus, it is necessary to have a real copy of erl in
# bin rather than a symbolic link.
rm $distdir/bin/erl
cp -p $distdir/lib/erlang/bin/erl $distdir/bin/erl

# Replace "/opt/couchbase" with relative path
for f in $distdir/bin/couchdb $distdir/bin/couchjs $distdir/lib/erlang/bin/erl
do
    sed -i '' 's/\/opt\/couchbase/\$SCRIPT_DIR\/../g' $f
done

sed -i '' 's/ROOTDIR=.*/ROOTDIR=$SCRIPT_DIR\/../' $distdir/lib/erlang/bin/erl
sed -i '' 's/ROOTDIR=.*/ROOTDIR=$SCRIPT_DIR\/..\/lib\/erlang/' $distdir/bin/erl
sed -i '' 's/\/opt\/couchbase/../g' $distdir/etc/couchdb/default.ini
