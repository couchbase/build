import sys
import urllib2
import json
import re

build_number = sys.argv[1]
matrix_url = 'http://server.jenkins.couchbase.com/job/build_sanity_matrix/'
specific_build_url = matrix_url + build_number + '/api/json'
ret = urllib2.urlopen(specific_build_url)
results = json.loads(ret.read())

overall_result = 0
total_runs = 0
for res in results['runs']:
    if res['number'] != int(build_number):
        continue
    total_runs += 1
    url = res['url']
    p = r'.*/DISTRO=([a-z0-9]*),TYPE=([a-z0-9]*).*'
    m = re.findall(p, url)
    if m:
        (dis, typ) = m[0]
        ret = urllib2.urlopen(url + 'api/json/')
        bld_res = json.loads(ret.read())['result']
        if dis == 'centos7' and bld_res in ['FAILURE', 'UNSTABLE']:
            overall_result = 1
        print '%10s / %s - %8s - %s' %(dis, typ, bld_res, url)

if total_runs == 0:
    overall_result = 1

sys.exit(overall_result)
