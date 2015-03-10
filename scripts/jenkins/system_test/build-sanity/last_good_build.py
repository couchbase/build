import sys
import urllib2

################################
# NOTE: HARDCODED FOR SHERLOCK #
################################
#
# The current up to downstream of sherlock build looks like this:
#   sherlock-build --> sherlock-unix-matrix --> sherlock-unix --> distro specific *nix build
#
# The downstream builds are non-blocking. And if one of them fails, the top level job
# doesn't know about it. That is, a green status of sherlock-build job doesn't necessarily
# mean the build was successful. The easiest and fairly reliable way to tell this is to
# check the file server were the builds are kept by making sure we have binaries for all
# the required platforms.
#
# This script first checks the latest successful build of sherlock-build. Then it looks
# for the directory with that build number on the file server (latestbuild.hq) to see 
# if all platform binaries are there. If not, it checks the previous build...and so on
# for upto 10 builds
#

_BUILDS_FILE_SERVER='http://latestbuilds.hq.couchbase.com/couchbase-server/sherlock'
_LAST_GOOD_BUILD_JENKINS_URL='http://factory.couchbase.com/job/sherlock-build/lastStableBuild/buildNumber'

_FILES_PREFIX_TO_CHECK = [
        'centos6.x86_64.rpm',
        'centos7.x86_64.rpm',
        'opensuse11.3.x86_64.rpm',
        'debian7_amd64.deb',
        'ubuntu12.04_amd64.deb',
        'ubuntu14.04_amd64.deb',
        'macos_x86_64.zip',
        'windows_amd64.exe',
        'windows_x86.exe',
]

_CURRENT_VERSION='4.0.0'

def get_last_good_build_from_jenkins():
    ret = urllib2.urlopen(_LAST_GOOD_BUILD_JENKINS_URL)
    return ret.read()

def check_if_file_exists(url):
    try:
        ret = urllib2.urlopen(url)
        if ret.code == 200:
            return True
    except:
        return False

def check_if_good_build(build_number):
    for artifact in _FILES_PREFIX_TO_CHECK:
        special_separator = "-"
        if not artifact.endswith('.rpm'):
            special_separator = "_"
            
        artifact_url = '%s/%d/couchbase-server-enterprise%s%s-%d-%s' \
                            %(_BUILDS_FILE_SERVER, \
                              build_number, 
                              special_separator,
                              _CURRENT_VERSION, 
                              build_number, 
                              artifact)

        if not check_if_file_exists(artifact_url):
            return False
    return True

start = int(get_last_good_build_from_jenkins())

for build_number in range(start, start-10, -1):
    ret = check_if_good_build(build_number)
    if ret:
        print build_number
        sys.exit(0)
print '0'
sys.exit(1)
