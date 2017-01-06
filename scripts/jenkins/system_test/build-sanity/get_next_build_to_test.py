#!/usr/bin/python
import requests
import json
from optparse import OptionParser

btm_manifest_map = {
    'couchbase-server/watson/4.5.1.xml': ('watson-4.5.1', 'watson.xml'),
}

_RESTAPI_BASE_URL="http://172.23.123.43:8282"
def main(ver, ttype):
    url = '{}/builds/totest?ver={}&type={}'.format(_RESTAPI_BASE_URL, ver, ttype)
    res = requests.get(url)
    j = res.json()

    if j['build_nums']:
        to_build = j['build_nums'][0]
        url = '{}/builds/info?ver={}&bnum={}'.format(_RESTAPI_BASE_URL, ver, to_build)
        res = requests.get(url)
        j = res.json()
        with open('env.properties', 'w') as F:
            F.write("VERSION={}\n".format(j['build_info']['version']))
            F.write("BLD_NUM={}\n".format(j['build_info']['build_num']))
            F.write("MANIFEST_SHA={}\n".format(j['build_info']['manifest_sha']))
            mf = j['build_info']['manifest']
            if btm_manifest_map.has_key(mf):
                mf = btm_manifest_map[mf][1]
            F.write("MANIFEST_FILE={}\n".format(mf))
    

if __name__ == '__main__':
    parser = OptionParser()
    parser.add_option("-v", "--version", dest="version", help="eg 5.0.0")
    parser.add_option("-t", "--test-type", dest="ttype", default="sanity", help="sanity or unit")

    (options, args) = parser.parse_args()
    main(options.version, options.ttype)
