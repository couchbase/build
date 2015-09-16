import sys
import urllib2
import json
from optparse import OptionParser

#
# The current up to downstream of a build looks like this:
#   <rel>-build --> <rel>-unix-matrix --> <rel>-unix --> distro specific *nix build
#
# The downstream builds are non-blocking. And if one of them fails, the top level job
# doesn't know about it. That is, a green status of the job sherlock-build or
# watson-build doesn't necessarily mean the build was successful. The easiest and
# fairly reliable way to tell this is to check the file server where the builds are
# kept by making sure we have binaries for all the required platforms.
#
# This script first checks the latest successful build of <rel>-build. Then it looks
# for the directory with that build number on the file server to see if all platform
# binaries are there. If not, it checks the previous build, and so on for upto 50
# builds. The first such build number for which we have all platform binaries, is
# the one that is considered the latest good build
#

_FACTORY='http://factory.couchbase.com'
_SERV_JENKINS='http://server.jenkins.couchbase.com'

_PLATFORM_PREFIX = {
    'centos6' : 'centos6.x86_64.rpm',
    'centos7' : 'centos7.x86_64.rpm',
    'suse11'  : 'suse11.x86_64.rpm',  # name was opensuse11.3 until 2217; so we will not support anything less than 2217
    'debian7' : 'debian7_amd64.deb',
    'ubuntu12': 'ubuntu12.04_amd64.deb',
    'ubuntu14': 'ubuntu14.04_amd64.deb',
    'mac'     : 'macos_x86_64.zip',
    'win32'   : 'windows_amd64.exe',
    'win64'   : 'windows_x86.exe',
}

_BUILD_NUMBER_RANGE = {
    '4.0.0' : (4000, 4500),
    '4.1.0' : (4500, 10000),
    '4.5.0' : (0, 10000),
}

def check_if_file_exists(url):
    try:
        ret = urllib2.urlopen(url)
        if ret.code == 200:
            return True
    except:
        return False


class Builds():
    def __init__(self, version):
        code_name = ''
        jenkins_url = ''
        build_job = ''

        self.supported_platforms = _PLATFORM_PREFIX.keys()

        if version.startswith('4.0') or version.startswith('4.1'):
            code_name = 'sherlock'
            jenkins_url = _FACTORY
            build_job = 'sherlock-build'
        elif version.startswith('4.5'):
            code_name = 'watson'
            jenkins_url = _SERV_JENKINS
            build_job = 'watson-build'

        self.file_server = 'http://172.23.120.24/builds/latestbuilds/couchbase-server/' + code_name
        self.build_history_url = jenkins_url + '/job/' + build_job + '/api/json?tree=builds[number]'
        self.env_vars_url = jenkins_url + '/job/' + build_job + '/{0}/injectedEnvVars/api/json'

    def get_last_good_build_from_jenkins(self, first, last):
        ret = urllib2.urlopen(self.build_history_url)
        all_builds_json = json.loads(ret.read())
        bnums = [int(x['number']) for x in all_builds_json['builds']]
        bnums.sort(reverse=True)
        good_build = first
        for b in bnums:
            ret = urllib2.urlopen(self.env_vars_url.format(b))
            all_envs = json.loads(ret.read())
            if not all_envs.has_key('envMap'):
                break
            if all_envs['envMap'].has_key('BLD_NUM'):
                build_num = int(all_envs['envMap']['BLD_NUM'])
            elif all_envs['envMap'].has_key('BUILD_NUMBER'):
                build_num = int(all_envs['envMap']['BUILD_NUMBER'])
            else:
                break
            if last > build_num > first:
                good_build = build_num
                break
        return good_build

    def check_if_good_build(self, build_number, ver):
        for plat in self.supported_platforms:
            artifact_suffix = _PLATFORM_PREFIX[plat]
            special_separator = "-"
            if not artifact_suffix.endswith('.rpm'):
                special_separator = "_"

            artifact_url = '%s/%d/couchbase-server-enterprise%s%s-%d-%s' \
                                %(self.file_server, \
                                  build_number,
                                  special_separator,
                                  ver,
                                  build_number,
                                  artifact_suffix)

            if not check_if_file_exists(artifact_url):
                return False
        return True

    def get_last_good(self, version, from_build, to_build):
        (default_from, default_to) = (0, 10000)
        if _BUILD_NUMBER_RANGE.has_key(version):
            (default_from, default_to) = _BUILD_NUMBER_RANGE[version]
        if not from_build:
            from_build = default_from
        if not to_build:
            to_build = default_to
        start = self.get_last_good_build_from_jenkins(from_build, to_build)
        end = start-50
        for build_number in range(start, start-50, -1):
            if build_number < 0:
                break
            ret = self.check_if_good_build(build_number, version)
            if ret:
                return build_number
        return '0'

if __name__ == '__main__':
    parser = OptionParser()
    parser.add_option("-v", "--version", dest="version", default="4.0.1",
                      help="sherlock version to be used")
    parser.add_option("-s", "--start", dest="last_success", type="int",
                      help="last successful build... start searching from this number")
    parser.add_option("-e", "--end", dest="upper_limit", type="int",
                      help="upper limit for build numbers (any build above this number is not considered)")
    (options, args) = parser.parse_args()

    rel_code_name = ''
    if not options.version[:3] in ['4.0', '4.1', '4.5']:
        print 'Unsupported version %s' %options.version
        sys.exit(1)

    builds = Builds(options.version)
    print builds.get_last_good(options.version, options.last_success, options.upper_limit)
