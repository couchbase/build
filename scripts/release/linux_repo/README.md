# Scripts For Creating and Releasing Couchbase Server

## Debian

| script         |  use:                                        |
|----------------|----------------------------------------------|
| prep_deb.sh    |   1.  prepare repo meta-files                |
| seed_deb.sh    |   2.  seed new repo                          |
| import_deb.sh  |   3.  import packages                        |
| upload_deb.sh  |   4.  upload to shared repository            |
| upload_meta.sh |   5.  upload keys and sources.list files     |

## RPM

| script         |  use:                                        |
|----------------|----------------------------------------------|
| prep_rpm.sh    |   1.  prepare repo meta-files                |
| seed_rpm.sh    |   2.  seed new repo                          |
| import_rpm.sh  |   3.  import and sign packages               |
| sign_rpm.sh    |   4.  sign local repo                        |
| upload_rpm.sh  |   5.  upload local repo to shared repository |
| upload_meta.sh |   6.  upload keys and yum.repos.d            |

## SSL

| script         |  use:                                        |
|----------------|----------------------------------------------|
| prep_ssl.sh   |   1.  prepare local openssl098 repos          |
| seed_ssl.sh   |   2.  seed new repos                          |
| import_ssl.sh |   3.  import packages                         |
| sign_ssl.sh   |   4.  sign RPM packges in local repos         |
| upload_ssl.sh |   5.  upload local repos to shared repository |

