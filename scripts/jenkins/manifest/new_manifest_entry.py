#!/usr/bin/env python3

import re
import os
import sys
import json
import argparse
from lxml import etree
import logging

"""
This script is used to add a new entry in product-config.json and update product
version in BRANCH.xml as needed.
For example, mad-hatter is 6.6.x release.  Currently, its mainline build in 
product-config.json is 6.6.1.  We want to start a branch manifest for 6.6.1 and
bump the mainline build to 6.6.2 in product-config.json.  We would do:
1. use lock-to-sha.py to generate 6.6.1.xml
2. run this script to produce product-config.json and mad-hatter.xml:
      * product-config.json has a new entry of "couchbase-server/mad-hatter/6.6.1.ml"
      * mad-hatter.xml's VERSION tag is updated to 6.6.2
3. product-config.json, mad-hatter.xml and 6.6.1.xml need to be checked into manifest repo
"""

# logging
logger = logging.getLogger()
handler = logging.StreamHandler()
formatter = logging.Formatter('%(levelname)-8s %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel('INFO')

def load_json(input_json):
    # load product-config.json
    try:
        with open(input_json, 'r') as f:
            data = json.load(f)
    except KeyError as e:
        sys.exit(f"Unable to load json file {input_json}")

    return data

def update_product_config(json_data,release,release_name,new_manifest_key,release_manifest_key,
    start_build,approval_ticket):

    new_manifest_values={"release": release,
        "release_name": release_name,
        "production": True,
        "interval": 60,
        "keep_git": True}

    #get approval ticket information from the main release entry.
    #this is the ticket for the new entry.
    if json_data['manifests'][release_manifest_key]["approval_ticket"]:
        new_manifest_values["approval_ticket"]=json_data['manifests'][release_manifest_key]["approval_ticket"]
        new_manifest_values["restricted"]=True

    #add new entry into product-config.json
    json_data['manifests'][new_manifest_key]=new_manifest_values


    #update the main release entry.
    #1. if an approval ticket is supplied, add/replace it in the main release entry
    #2. set new starting build number
    if approval_ticket:
        json_data['manifests'][release_manifest_key]["approval_ticket"]=approval_ticket
        json_data['manifests'][release_manifest_key]["restricted"]=True
    else:
        json_data['manifests'][release_manifest_key].pop("approval_ticket", None)
        json_data['manifests'][release_manifest_key].pop("restricted", None)

    json_data['manifests'][release_manifest_key]["start_build"]=start_build

    logger.info('Generating product-config.json...')
    f = open('product-config.json', 'w')
    f.write(json.dumps(json_data, indent=4))

def update_manifest_version(manifest_xml, version):
    #need to update the version information
    tree = etree.parse(manifest_xml)

    tree.find('//annotation[@name="VERSION"]').set('value',version)
    logger.info('Writing '+manifest_xml.split('/')[-1])
    tree.write(manifest_xml.split('/')[-1],encoding='UTF-8',
               xml_declaration=True,pretty_print=True)

def main(args):

    #Parse release names from args.release_xml; i.e.:
    #    args.release_xml could be /opt/manifest/couchbase-server/mad-hatter.xml
    #    args.new_manifest_xml=6.6.1.xml
    #    args.new_release_version=6.6.2
    #    release_xml_name=mad-hatter.xml
    #    release=mad-hatter
    #    release_name="mad-hatter (6.6.1)"
    #    release_manifest_key="couchbase-server/mad-hatter.xml"
    #    new_manifest_key="couchbase-server/mad-hatter/6.6.1.xml"

    release_xml_name=args.release_xml.split('/')[-1]
    release=os.path.splitext(release_xml_name)[0]
    release_manifest_key=args.product+"/"+release_xml_name
    new_manifest_name=os.path.splitext(args.new_manifest_xml)[0]
    release_name=release+" ("+new_manifest_name+")"
    new_manifest_key=args.product+"/"+release+"/"+args.new_manifest_xml

    #load json date from prodduct-config.json
    json_data=load_json(args.prod_config_json)

    #check product-config.json to ensure couchbaser-server/RELEASE.xml exists;
    #otherwise, args.release_xml is incorrect.
    if release_manifest_key not in json_data['manifests']:
        sys.exit(f"{release_manifest_key} does not exist in {args.prod_config_json}!")

    #if desired manifest entry already exist, no need to do it again.
    if new_manifest_key in json_data['manifests']:
        sys.exit(f"Specified new xml, {args.new_manifest_xml}, already exist in {args.prod_config_json}!")

    update_product_config(json_data,release,release_name,new_manifest_key,release_manifest_key,
                          args.start_build,args.approval_ticket)

    update_manifest_version(args.release_xml,args.new_release_version)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Add new manifest entry in product-config.json"
             "and update VERSION in RELEASE.xml\n\n"
             "./new_manifest_entry.py --product couchbase-server"
             "--prod-config-json /opt/manifest/couchbase-server/product-config.json"
             "--new-manifest-xml 6.6.1.xml --release-xml /opt/manifest/couchbase-server/mad-hatter.xml"
             "--new-release-version 6.6.2 --start-build 1234 --approval-ticket MB-1345\n\n")
    parser.add_argument('--product',
                        help="Which product is it for?\n\n",
                        default="couchbase-server",
                        required=True)
    parser.add_argument('--prod-config-json',
                        help="Full path to product-config.json\n\n",
                        required=True)
    parser.add_argument('--release-xml',
                        help="Full path to the release xml.\n\n",
                        required=True)
    parser.add_argument('--new-manifest-xml',
                        help="New manifest xml to be added. i.e. 6.6.0.xml\n\n",
                        required=True)
    parser.add_argument('--new-release-version',
                        help="new release number for release xml.\n\n",
                        required=True)
    parser.add_argument('--approval-ticket',
                        help="Approval ticket to restrict the build for the new manifest.\n\n",
                        required=False)
    parser.add_argument('--start-build', type=int,
                        help="Starting build number for the new release build.\n\n",
                        required=True)

    args = parser.parse_args()
    main(args)
