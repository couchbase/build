#!/usr/bin/env python3

"""
Program is used to scan and upload report to sonar server
only repositories under couchbase and couchbaselabs are scanned

Currently, internally hosted sonar server is 
http://cleancode.service.couchbase.com

scan_target can be all, or single project/group from manifest

assume sonar-scanner is on the PATH
"""
import pandas
from lxml import etree
import subprocess
import os, sys, re
import argparse
import logging
import json
import requests

# logging
logger = logging.getLogger()
handler = logging.StreamHandler()
formatter = logging.Formatter('%(levelname)-8s %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel('INFO')

def read_product_properties(product_name):
    #load product custom properties if it exists
    props_file=os.path.dirname(os.path.realpath(__file__))+'/'+product_name+'.json'
    if os.path.exists(props_file):
        logger.info('Load properties from '+props_file)
        with open(props_file, 'r') as read_file:
            custom_props=json.load(read_file)
    else:
        logger.info('No custom properties present for %s.', product_name)
        custom_props={}
    return custom_props

def sonar_properties(project_name,version,props):
    project_dir=os.path.abspath(project_name)

    #create a dummy directory to bypass java binary check
    if not os.path.exists(project_dir+'/dummy'):
        os.mkdir(project_dir+'/dummy')
    f = open(project_name+'/sonar-project.properties', 'w')
    f.write('sonar.projectKey='+project_name)
    f.write('\nsonar.projectVersion='+version)
    f.write('\nsonar.nodejs.executable='+args.node_exec)
    f.write('\nsonar.java.binaries='+project_dir+'/dummy')

    ##set default encoding
    ##js files in particular is limited to 100kb when encoding is not detected
    ## https://github.com/SonarSource/sonar-css/issues/251
    f.write('\nsonar.sourceEncoding=UTF-8')
    f.write('\nsonar.host.url='+args.sonar_host_url)
    f.write('\nsonar.login='+args.sonar_api_token)

    if 'sonar.sources' in props:
        f.write('\nsonar.sources='+props.get('sonar.sources'))
        props.pop('sonar.sources')
    else:
        f.write('\nsonar.sources=.')

    if 'sonar.exclusions' in props:
        if args.exclusions is None:
            exclusions=props.get('sonar.exclusions')
        else:
            exclusions=args.exclusions+','+props.get('sonar.exclusions')
        props.pop('sonar.exclusions')
    else:
        exclusions=args.exclusions
    if exclusions is not None:
        f.write('\nsonar.exclusions='+exclusions)
    for prop in props:
        f.write('\n'+prop+'='+props[prop])
    f.close()

def repo_checkout(repository):
    repo_name=repository.get('name')
    repo_url=repository.get('url')
    cmd='git clone '+ repo_url
    logger.info('checking out: %s', repo_name)
    subprocess.check_output(cmd, shell=True);

    #check out specific rev or branch if it is defined
    if 'revision' in repository and repository.get('revision') != 'master':
        revision = repository.get('revision')
        logger.info('checkout revision: %s', revision)
        cmd='cd '+repo_name+';git checkout '+revision
        subprocess.check_output(cmd, shell=True);

def scan_project(project_name):
    project_dir=os.path.abspath(project_name)
    cmd='sonar-scanner -Dsonar.projectBaseDir='+project_dir
    logger.info('%s', cmd)
    subprocess.check_output(cmd, shell=True);

def get_scan_result(projects_list,sonar_host_url):
    measures=['vulnerabilities','code_smells','bugs']
    new_measures=['new_vulnerabilities','new_code_smells','new_bugs']
    f = open('scan-result.csv', 'w')
    f.write('project,'+','.join(measures)+','+','.join(new_measures))
    # measures_api_endpoint
    URL = sonar_host_url+'/api/measures/component'
    for proj in set(projects_list):
        f.write('\n'+'<a href='+sonar_host_url+'/dashboard?id='+proj+'>'+proj+'</a>')

        for measure in measures:
            #project name is actually component in the api request
            PARAMS = {
                'component': proj,
                'metricKeys': measure
            }
            try:
                res = requests.get(url = URL, params = PARAMS)
                project_measures=res.json()
            except requests.exceptions.RequestException as e:
                raise SystemExit(e)

            f.write(','+project_measures['component']['measures'][0]['value'])

        for measure in new_measures:
            #project name is actually component in the api request
            PARAMS = {
                'component': proj,
                'metricKeys': measure
            }
            try:
                res = requests.get(url = URL, params = PARAMS)
                project_measures=res.json()
            except requests.exceptions.RequestException as e:
                raise SystemExit(e)

            if not 'measures' in project_measures['component'] or len(project_measures['component']['measures']) == 0:
                #json returns empty for new measure if it is the initial scan
                #no need to scan other new measures
                break
            else:
                f.write(','+project_measures['component']['measures'][0]['period']['value'])
    f.close()
    df = pandas.read_csv("scan-result.csv")
    df.to_html('scan-result.htm',escape=False)

def process_manifest(xml,target):
    tree = etree.parse(xml)
    if target == 'all':
        projects=tree.xpath('//project[not(@name="packaging") and not(@name="build") and not(@name="product-texts")]')
    else:
        projects=tree.xpath('//project[@name=$p or contains(@groups,$p)]', p=target)
    if not projects:
        sys.exit('TARGET "'+target+'" can NOT be located in the manifest')

    defaults=tree.xpath('//default')
    default_remote = defaults[0].get('remote') if defaults else None
    default_revision = defaults[0].get('revision') if defaults else "master"

    remotes=dict()
    projects_to_scan=list()
    for item in tree.xpath('//remote'):
        #add urls containing couchbase & couchbaselabs to dict.
        if re.search('github.com/(couchbase|couchbaselabs)/?$',item.get('fetch')):
            remotes[item.get('name')]=item.get('fetch')

    for project in projects:
        project_to_scan=dict()
        remote = project.get('remote', default=default_remote)

        #only scan projects under couchbase and couchbaselabs
        if (remote in remotes):
            project_to_scan['name'] = project.get('name')
            project_to_scan['url'] = remotes.get(remote) + project_to_scan['name'] + '.git'
            project_to_scan['revision']=project.get('revision', default=default_revision)

            projects_to_scan.append(project_to_scan)
        else:
            logger.info('%s is not a repo under couchbase, couchbase-priv, or couchbaselabs.  skipping...', project.get('name'))

    #return a list of projects that needs to be scanned by sonar
    return projects_to_scan

def sonar_scan(projects,version,sonar_host_url,custom_props):

    #keep a project list so that we can use it to pull the scan result
    sonar_projects_list=list()

    for project in projects:
        project_name=project.get('name')
        logger.info('getting project: ' + project_name)

        #skip if project is on the ignored list
        #some projects are intentionally ignored to avoid duplicated efforts
        #i.e. couchbase-lite-core*, we don't want to scan these again in other CBL products
        #     couchbase-server reposities, we don't want to scan them again in sync_gateway
        if 'ignored_repositories' in custom_props and project_name in custom_props['ignored_repositories']:
            logger.info('%s is listed as a project that should be ignored.', project_name)
        elif os.path.exists(project_name):
            logger.info('%s exists.  Possibily duplicate project in manifest.  Skipping', project_name)
        else:
            sonar_projects_list.append(project_name)
            repo_checkout(project)
            sonar_custom_props = custom_props['sonar'] if custom_props else {}
            #create sonar.properties before the scan
            sonar_properties(project_name,version,sonar_custom_props)
            scan_project(project_name)

    #get scan results
    get_scan_result(sonar_projects_list,sonar_host_url)

def main(args):

    #load product specific properties from <product>.json
    #it contains extra sonar properties, repositories to ignore, additional repo, etc.
    product_properties=read_product_properties(args.product)

    #checkout manifest repo, except sdk
    if args.product != "couchbase-sdk":
        #sync_gateway has its own manifest
        if args.product == "sync_gateway":
            cmd='git clone ssh://git@github.com/couchbase/'+args.product
            subprocess.check_output(cmd, shell=True);
            manifest_file=args.product+'/manifest/'+args.branch+'.xml'
        else:
            cmd='git clone ssh://git@github.com/couchbase/manifest.git'
            subprocess.check_output(cmd, shell=True);
            manifest_file='manifest/'+args.product+'/'+args.branch+'.xml'

        if os.path.exists(manifest_file):
            couchbase_projects=process_manifest(manifest_file,args.scan_target)
        else:
            sys.exit(manifest_file+' does not exist')
    else:
        couchbase_projects=list()

    if 'additional_repositories' in product_properties:
        for item in product_properties['additional_repositories']:
            repo=dict()
            repo['name'] = item
            repo['url'] = product_properties['additional_repositories'][item]
            couchbase_projects.append(repo)
    sonar_scan(couchbase_projects,args.version,args.sonar_host_url,product_properties)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='sonarqube project scan\n\n')
    parser.add_argument('--sonar_host_url', help='sonar host url.  i.e. http://cleancode.service.couchbase.com\n', required=True)
    parser.add_argument('--sonar_api_token', help='https://docs.sonarqube.org/latest/user-guide/user-token/ \n', required=True)
    parser.add_argument('--node_exec', help='PATH to node executable\n', required=True)
    parser.add_argument('--product', help='product name, i.e. couchbase-server\n', required=True)
    parser.add_argument('--scan_target', help='target project or group or all\n', required=True)
    parser.add_argument('--branch', help='target branch, i.e. cheshire-cat\n', required=True)
    parser.add_argument('--version', help='version, i.e. cheshire-cat is 7.0.0\n', required=True)
    parser.add_argument('--exclusions', help='files to be excluded from analysis', default=None)

    args = parser.parse_args()
    main(args)
