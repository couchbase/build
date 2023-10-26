#!/bin/bash

# Script to archive given list of core files. For each core file
# specified, will archive the core file, its executable program and
# any dependant libraries to the specified directory and compress the
# result.
# Returns zero if no core files found, non-zero if one of
# more cores were found.

set -e

if [ "$#" -lt 1 ]; then
    echo "Usage: $(basename $0) <archive dir>.tar.bz2 [core file...]"
    exit 1
fi

archive_dir=$1
shift

# Wipe out any previously existing archive directory (so any old
# archive doesn't get detected as an artifact by Jenkins).
chmod -R +w $archive_dir
rm -fr $archive_dir

if [ "$#" -ne 0 ]; then
    cat <<EOF

*******************************************************
***  ERROR: Core file(s) found at the end of the build
*******************************************************
EOF
    echo ""
    abs_archive_dir=$(pwd)/${archive_dir}
    mkdir -p $archive_dir

    for core; do
        cp --archive "$core" $archive_dir/

        if ! (hash gdb 2>/dev/null); then
            echo "Warning: gdb not found in PATH. Unable to determine which executable generated core file."
            continue
        fi

        # Determine the executable the core is from.
        prog_path=$(gdb --batch -ex "info auxv" --core "$core" 2>/dev/null \
            | grep 'AT_EXECFN' \
            | sed -e 's/.*"\([^"]\+\)"/\1/')

        # Determine the current working directory of the core. This is needed
        # as some of the shared libraries may have been loaded using relative paths.
        # We do this by examining the value of the "PWD" environment variable
        # from the core file.

        # Method A - Lookup using the symbol `environ` - this works
        # for older distros, or if the application itself doesn't
        # reference `environ` directly.
        core_pwd=$(gdb --batch -ex "set print array on" \
                       -ex "p/s ((char***)&environ)[0][0]@100" \
                       $prog_path --core "$core" 2>/dev/null \
            | grep '"PWD=' \
            | sed -e 's/.*"PWD=\([^"]\+\)",/\1/')

        if [ "$core_pwd" = "" ]; then
            # Attempt Method B - find the name of the environ symbol
            # used by the program. For older distros this is just
            # `environ`; but for newer (e.g. Ubuntu 16.04) it's a
            # versioned symbol (e.g. environ@GLIBC_2.2.5).
            environ=$(readelf --dyn-syms $prog_path \
                | grep -w environ \
                | awk '{split($0,a," "); print a[8]}' \
                | sed -e 's/@/@@/')

            if [ "$environ" != "" ]; then
                core_pwd=$(gdb --batch -ex "set print array on" \
                               -ex "p/s ((char***)&'${environ}')[0][0]@100" \
                               $prog_path --core "$core" 2>/dev/null \
                    | grep '"PWD=' \
                    | sed -e 's/.*"PWD=\([^"]\+\)",/\1/')
            fi

            if [ "$core_pwd" = "" ]; then
                # Attempt Method C - use strings on the core dump,
                # searching for the PWD=xxx string.  This is slow and
                # somewhat imprecise (possible the binary contains
                # another string in the same form but given we have
                # failed so far...
                core_pwd=$(strings $core \
                    | grep '^PWD=' \
                    | head -n 1 \
                    | cut -d '=' -f 2)

                if [ "$core_pwd" != "" ]; then
                    echo "Notice: Determined working directory '$core_pwd' via brute-force search of core dump. This path may be wrong..."
                fi
            fi
        fi

        if [ "$core_pwd" = "" ]; then
            echo "Warning: Failed to determine working directory from core file $core - skipping."
            continue
        fi

        pushd $core_pwd >/dev/null

        cp --archive --parents $prog_path $abs_archive_dir/

        # Now determine all shared libraries which were loaded, and archive them,
        # along with any seperate debuginfo files.
        for lib in $(gdb --batch -ex "info sharedlibrary" $prog_path --core "$core" 2>/dev/null \
            | grep -A999 'Shared Object Library' \
            | grep -v 'Shared Object Library' \
            | grep -v '(*): Shared library is missing debugging information.' \
            | cut -c 50- ); do

            cp --archive --parents --dereference $lib $abs_archive_dir/

            # Debuginfo files use the real name of the library, not
            # the symlink name.
            real_lib=$(readlink -f $lib)
            if [ -f "/usr/lib/debug/$real_lib" ]; then
                cp --archive --parents /usr/lib/debug/$real_lib $abs_archive_dir
            fi
        done

        echo -e "Core file '$core' - created by $(basename $prog_path)"
        echo -e "GDB command to debug (after extracting archive):"
        echo -e ""
        echo -e "    gdb ${prog_path#/} --core '$(basename "$core")' -ex 'set debug-file-directory usr/lib/debug' -ex 'set sysroot .'"
        echo ""

        # Finally, give people a "sneak peak" of where the crash was
        # by dumping a backtrace.
        echo "Backtrace of crashing thread:"
        gdb --batch -ex "backtrace" $prog_path --core "$core" 2>/dev/null
        echo
        echo
        popd >/dev/null
    done

    # Compress the directory to save space on Jenkins
    tar cjf ${archive_dir}.tar.bz2 ${archive_dir}/

    echo "Archiving complete. Data for post-mortem saved to ${archive_dir}.tar.bz2"

    # Make a command exit with non-zero status, so overall script
    # status is failure (see deferred_error_handler)
    echo
    echo "*** Failing build due to presence of core files ***"
    echo ""
    exit 1
fi
