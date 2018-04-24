#!/bin/bash

function show_help {
    echo "Usage: ./backup-jenkins.sh <options>"
    echo "Options:"
    echo "   -d :  Data directory to backup. Typically it is JENKINS_HOME (Required)"
    echo "   -j :  Jobs directory to backup, if different from JENKINS_HOME/jobs (Optional)"
    echo "   -b :  Full backup directory, if needed. This is for full backup only."
    echo "         Full backups are not ftp-ed to NAS. If this option is not given"
    echo "         full backups are not made. (Optional)"
    echo "   -i :  Instance name (eg, server_jenkins, cv_jenkins, mobile_jenkins) (Required)"
}

bold=$(tput bold)
normal=$(tput sgr0)

while getopts :d:j:b:i:h ARG; do
    case $ARG in
        d) JENKINS_DATA="$OPTARG"
           ;;
        j) JENKINS_JOBS="$OPTARG"
           ;;
        b) FULL_BACKUP_DIR="$OPTARG"
           ;;
        i) INSTANCE_NAME="$OPTARG"
           ;;
        h) show_help
           ;;
        \?) # Unrecognized option; show help
            echo -e \\n"Option -${bold}${OPTARG}${normal} not allowed."
            show_help
    esac
done

if [[ -z "$JENKINS_DATA" ]]; then
    echo "Data directory (-d) is required"
    exit 1
fi

if [[ -z "$INSTANCE_NAME" ]]; then
    echo "Instance name (-i) is required"
    exit 1
fi

if [[ -n "$JENKINS_DATA" && ! -d "$JENKINS_DATA" ]]; then
    echo "Data directory ${JENKINS_DATA} doesn't exist"
    exit 1
fi

if [[ -n "$JENKINS_JOBS" && ! -d "$JENKINS_JOBS" ]]; then
    echo "Jobs directory ${JENKINS_JOBS} doesn't exist"
    exit 1
fi

if [[ -n "$FULL_BACKUP_DIR" && ! -d "$FULL_BACKUP_DIR" ]]; then
    echo "Full backup directory ${FULL_BACKUP_DIR} doesn't exist"
    exit 1
fi

# Remove any old temporary backup tarball dumps
/bin/rm -f jenkins_backup*tar.gz

DAYOFWEEK=$(/bin/date +%a)
DUMP=jenkins_backup.${DAYOFWEEK}.tar.gz

echo "Starting minimal backup at $(/bin/date)"
nice -n 19 tar --exclude-from jenkins_backup_exclusions -zcf ${DUMP} ${JENKINS_DATA} ${JENKINS_JOBS}
echo "Minimal backup finished at $(/bin/date)"

echo "ftp to NAS started at $(/bin/date)"
ftp 172.23.120.24 << END_CMDS
cd Jenkins_backup/${INSTANCE_NAME}
bin
put ${DUMP}
END_CMDS
echo "ftp to NAS ended at $(/bin/date)"

if [[ "$DAYOFWEEK" == "Sun" && -n "$FULL_BACKUP_DIR" ]]; then
   echo "Starting full backup at $(/bin/date)"
   nice -n 19 rsync -au ${JENKINS_DATA} ${JENKINS_JOBS} ${FULL_BACKUP_DIR}
   echo "Full backup finished at $(/bin/date)"
fi
