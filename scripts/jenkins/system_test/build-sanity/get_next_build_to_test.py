#!/usr/bin/python

import argparse

import requests

from jenkinsapi import jenkins


btm_manifest_map = {
    'couchbase-server/watson/4.5.1.xml': ('watson-4.5.1', 'watson.xml'),
    'couchbase-server/watson/4.6.3.xml': ('watson-4.6.3', 'watson.xml'),
    'couchbase-server/spock/5.0.0.xml':
        ('spock-5.0.0', 'couchbase-server/spock.xml'),
}
jenkins_only = {
    '4.6.3': {'release': 'watson', 'job': 'watson-build'},
    '5.0.0': {'release': 'spock', 'job': 'couchbase-server-build'},
}
_REST_API_BASE_URL = 'http://172.23.123.43:8282'


def get_next_build_buildboard(version, ttype):
    """"""

    url = '{}/builds/totest?ver={}&type={}'.format(_REST_API_BASE_URL,
                                                   version, ttype)
    res = requests.get(url)
    j = res.json()

    if j['build_nums']:
        to_build = j['build_nums'][0]
        url = '{}/builds/info?ver={}&bnum={}'.format(_REST_API_BASE_URL,
                                                     version, to_build)
        res = requests.get(url)
        j = res.json()

        return j['build_info']


def get_next_build_jenkins(version, _ttype):
    """"""

    jenkins_info = jenkins_only[version]

    server = jenkins.Jenkins('http://server.jenkins.couchbase.com/')
    job = server[jenkins_info['job']]

    for build_id in job.get_build_ids():
        build = job.get_build(build_id)
        build_info = build.name.split()[1]

        release = jenkins_info['release']
        if release == 'spock':
            build_name, _ = build_info.rsplit('-', 1)

            if build_name != 'couchbase-server-{}'.format(release):
                continue

            for param in build.get_actions()['parameters']:
                if param['name'] == 'VERSION' and param['value'] == version:
                    env_vars = build.get_env_vars()

                    return {
                        'build_num': env_vars['BLD_NUM'],
                        'manifest': env_vars['MANIFEST'],
                        'manifest_sha': env_vars.get('MANIFEST_SHA', ''),
                        'version': env_vars['VERSION'],
                    }
        else:  # We have 'watson'
            server_version, build_num, _ = build_info.split('-', 2)

            if server_version == version:
                env_vars = build.get_env_vars()

                return {
                    'build_num': env_vars['BLD_NUM'],
                    'manifest': env_vars['MANIFEST'],
                    'manifest_sha': env_vars.get('MANIFEST_SHA', ''),
                    'version': env_vars['VERSION'],
                }
    else:
        return None


def write_env_properties(build_info):
    """"""

    with open('env.properties', 'w') as fh:
        fh.write('VERSION={}\n'.format(build_info['version']))
        fh.write('BLD_NUM={}\n'.format(build_info['build_num']))
        fh.write('MANIFEST_SHA={}\n'.format(build_info['manifest_sha']))

        mf = build_info['manifest']

        if mf in btm_manifest_map:
            mf = btm_manifest_map[mf][1]

        fh.write('MANIFEST_FILE={}\n'.format(mf))


def get_next_build(args):
    """"""

    if args.version in jenkins_only:
        build_info = get_next_build_jenkins(args.version, args.ttype)
    else:
        build_info = get_next_build_buildboard(args.version, args.ttype)

    if build_info is not None:
        write_env_properties(build_info)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Get next build for sanity/unit testing purposes'
    )
    parser.add_argument('-v', '--version', dest='version',
                        help='Version of server release (e.g. 5.0.0)')
    parser.add_argument('-t', '--test-type', dest='ttype', default='sanity',
                        help='Type of testing: sanity or unit')

    get_next_build(parser.parse_args())
