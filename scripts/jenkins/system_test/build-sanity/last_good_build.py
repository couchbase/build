import sys
import urllib2
import json
from optparse import OptionParser

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
_GOOD_BUILD_HISTORY_URL='http://factory.couchbase.com/job/sherlock-build/api/json?tree=builds[number]'
_ENV_VARS='http://factory.couchbase.com/job/sherlock-build/{0}/injectedEnvVars/api/json'

_FILES_PREFIX_TO_CHECK = [
        'centos6.x86_64.rpm',
        'centos7.x86_64.rpm',
        'suse11.x86_64.rpm',
        'debian7_amd64.deb',
        'ubuntu12.04_amd64.deb',
        'ubuntu14.04_amd64.deb',
        'macos_x86_64.zip',
        'windows_amd64.exe',
        'windows_x86.exe',
]

_CURRENT_VERSION='4.0.0'

def get_last_good_build_from_jenkins(first, last):
    ret = urllib2.urlopen(_GOOD_BUILD_HISTORY_URL)
    all_builds_json = json.loads(ret.read())
    bnums = [int(x['number']) for x in all_builds_json['builds']]
    bnums.sort(reverse=True)
    good_build = first
    for b in bnums:
        ret = urllib2.urlopen(_ENV_VARS.format(b))
        all_envs = json.loads(ret.read())
        if not all_envs.has_key('envMap'):
            break
        if not all_envs['envMap'].has_key('BLD_NUM'):
            break
        sherlock_build = int(all_envs['envMap']['BLD_NUM'])
        if last > sherlock_build > first:
            good_build = sherlock_build
            break
    return good_build

def check_if_file_exists(url):
    try:
        ret = urllib2.urlopen(url)
        if ret.code == 200:
            return True
    except:
        return False

def check_if_good_build(build_number):
    for artifact in _FILES_PREFIX_TO_CHECK:
        if artifact.startswith('suse') and build_number < 2217:
            artifact = 'opensuse11.3.x86_64.rpm'
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

if __name__ == '__main__':
    parser = OptionParser()
    parser.add_option("-s", "--start", dest="last_success", default=0, type="int",
                      help="last successful build... start searching from this number")
    parser.add_option("-e", "--end", dest="upper_limit", default=100000, type="int",
                      help="upper limit for build numbers (any build above this number is not considered)")
    (options, args) = parser.parse_args()

    start = get_last_good_build_from_jenkins(options.last_success, options.upper_limit)

    for build_number in range(start, start-50, -1):
        ret = check_if_good_build(build_number)
        if ret:
            print build_number
            sys.exit(0)
    print '0'
