#!/bin/bash

function show_help {
    echo "Usage: ./backup-jenkins.sh <options>"
    echo "Options:"
    echo "   -d :  Data directory to backup. Typically it is JENKINS_HOME (Required)"
    echo "   -j :  Jobs directory to backup, if different from JENKINS_HOME/jobs (Optional)"
    echo "   -b :  Full backup directory, if needed. This is for full backup only."
    echo "         Full backups are not ftp-ed to NAS. If this option is not given"
    echo "         full backups are not made. (Optional)"
    echo "   -i :  Instance name (eg, factory, cv_jenkins, mobile_jenkins) (Required)"
}

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

        \?) #unrecognized option - show help
            echo -e \\n"Option -${BOLD}$OPTARG${NORM} not allowed."
            show_help
    esac
done

if [ "x$JENKINS_DATA" = "x" ]; then
    echo "Data direcotry (-d) is required"
    exit 1
fi

if [ "x$INSTANCE_NAME" = "x" ]; then
    echo "Instance name (-i) is required"
    exit 1
fi

if [ "x$JENKINS_DATA" != "x" -a ! -d $JENKINS_DATA ]; then
    echo "Data direcotry - $JENKINS_DATA - doesn't exist"
    exit 1
fi

if [ "x$JENKINS_JOBS" != "x" -a ! -d "$JENKINS_JOBS" ]; then
    echo "Jobs direcotry - $JENKINS_JOBS - doesn't exist"
    exit 1
fi

if [ "x$FULL_BACKUP_DIR" != "x" -a ! -d "$FULL_BACKUP_DIR" ]; then
    echo "Full backup directory - $FULL_BACKUP_DIR - doesn't exist"
    exit 1
fi

rm -f jenkins_backup*tar.gz

DAYOFWEEK=`date +%a`
DUMP=jenkins_backup.${DAYOFWEEK}.tar.gz

ADDL_FILES=""
if [ "$INSTANCE_NAME" = "factory" ]; then
    ADDL_FILES="/usr/share/jenkins/jenkins.war"
fi

echo Starting minimal backup at `date`
nice -n 19 tar --exclude-from jenkins_backup_exclusions -zcf $DUMP $JENKINS_DATA $JENKINS_JOBS $ADDL_FILES
echo Minimal backup finished at `date`

echo ftp to nas started at `date`
ftp 172.23.120.24 << END_CMDS
cd Jenkins_backup/$INSTANCE_NAME
bin
put $DUMP
END_CMDS
echo ftp to nas ended at `date`

if [ "$DAYOFWEEK" = "Sun" -a -n "$FULL_BACKUP_DIR" ]; then
   echo Starting full backup at `date`
   nice -n 19 rsync -au $JENKINS_DATA $JENKINS_JOBS $FULL_BACKUP_DIR
   echo Full backup finished at `date`
fi
