#!/usr/bin/env python3

"""
Program is used to scan and upload report to sonar server
only repositories under couchbase and couchbaselabs are scanned

Currently, internally hosted sonar server is 
http://cleancode.service.couchbase.com

scan_target can be all, or single project/group from manifest

assume sonar-scanner is on the PATH
"""

from lxml import etree
import subprocess
import os, sys, re
import argparse
import logging
import json

# logging
logger = logging.getLogger()
handler = logging.StreamHandler()
formatter = logging.Formatter('%(levelname)-8s %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel('INFO')

def sonar_properties(project_name):
    project_dir=os.path.abspath(project_name)
    #load custom properties if it exists
    props_file=os.getcwd()+'/build/scripts/jenkins/sonar/'+project_name+'.json'
    if os.path.exists(props_file):
        logger.info('Load properties from '+props_file)
        with open(props_file, 'r') as read_file:
            props=json.load(read_file)
    else:
        logger.info('No custom properties present for '+project_name)
        props={}

    #create a dummy directory to bypass java binary check
    if not os.path.exists(project_dir+'/dummy'):
        os.mkdir(project_dir+'/dummy')
    f = open(project_name+'/sonar-project.properties', 'w')
    f.write('sonar.projectKey='+project_name)
    f.write('\nsonar.nodejs.executable='+args.node_exec)
    f.write('\nsonar.java.binaries='+project_dir+'/dummy')
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

def manifest_checkout():
    cmd='git clone ssh://git@github.com/couchbase/manifest.git'
    subprocess.check_output(cmd, shell=True);

def repo_checkout(project,repo_base,default_rev):
    project_name=project.get('name')
    cmd='git clone '+repo_base+project_name+'.git'
    if not os.path.exists(project_name):
        logger.info('checking out project: %s', project_name)
        subprocess.check_output(cmd, shell=True);
        revision = project.get('revision', default=default_rev)
        #check out specific rev or branch if it is defined
        if revision != 'master':
            logger.info('checkout revision: %s', revision)
            cmd='cd '+project_name+';git checkout '+revision
            subprocess.check_output(cmd, shell=True);
        sonar_properties(project_name)
        sonar_scan(project_name)
    else:
      logger.info('%s exist.  Possibily duplicate project listed in manifest.  Skipping', project_name)

def sonar_scan(project_name):
    project_dir=os.path.abspath(project_name)
    cmd='sonar-scanner -Dsonar.projectBaseDir='+project_dir
    logger.info('%s', cmd)
    subprocess.check_output(cmd, shell=True);

def process_manifest(xml,target):
    tree = etree.parse(xml)
    if target == 'all':
        projects=tree.xpath('//project[not(@name="packaging") and not(@name="build")]')
    else:
        projects=tree.xpath('//project[@name=$p or contains(@groups,$p)]', p=target)
    if not projects:
        sys.exit('TARGET "'+target+'" can NOT be located in the manifest')

    defaults=tree.xpath('//default')
    default_remote = defaults[0].get('remote') if defaults else None
    default_revision = defaults[0].get('revision') if defaults else "master"

    remoteDict=dict()
    for item in tree.xpath('//remote'):
        #add urls containing couchbase & couchbaselabs to dict.
        if re.search('github.com/(couchbase|couchbaselabs)/?$',item.get('fetch')):
            remoteDict[item.get('name')]=item.get('fetch')

    for project in projects:
        remote = project.get('remote', default=default_remote)
        #only scan projects under couchbase and couchbaselabs
        if (remote in remoteDict):
            repo_checkout(project,remoteDict.get(remote), default_revision)
        else:
            logger.info('%s is not a repo under couchbase, couchbase-priv, or couchbaselabs.  skipping...', project.get('name'))

def main(args):

    # Setup connection to QualysGuard API.
    #checkout manifest repo 
    manifest_checkout()
    manifest_file='manifest/couchbase-server/'+args.branch+'.xml'
    if os.path.exists(manifest_file):
        process_manifest(manifest_file, args.scan_target)
    else:
        sys.exit(manifest_file+' does not exist')


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='sonarqube project scan\n\n')
    parser.add_argument('--sonar_host_url', help='sonar host url.  i.e. http://cleancode.service.couchbase.com\n', required=True)
    parser.add_argument('--sonar_api_token', help='https://docs.sonarqube.org/latest/user-guide/user-token/ \n', required=True)
    parser.add_argument('--node_exec', help='PATH to node executable\n', required=True)
    parser.add_argument('--scan_target', help='target project or group or all\n', required=True)
    parser.add_argument('--branch', help='target branch, i.e. cheshire-cat\n', required=True)
    parser.add_argument('--exclusions', help='files to be excluded from analysis', default=None)

    args = parser.parse_args()
    main(args)
