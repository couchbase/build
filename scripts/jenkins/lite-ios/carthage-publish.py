#!/usr/bin/env python3
''' Script to update Carthage JSON provisioning file for each CBL iOS release
'''

import argparse
import json
import sys
from collections import OrderedDict


def parse_json_file(file):
    '''
    Parse content of input JSON file, return data dictionary
    '''
    try:
        with open(file) as content:
            try:
                data = json.load(content, object_pairs_hook=OrderedDict)
            except json.JSONDecodeError:
                print("Invalid JSON content!")
                sys.exit(1)
    except IOError:
        print("Could not open file: {}".format(file))
        sys.exit(1)
    return data


def update_json_file(args):
    '''
    Update Carthage JSON file with CBL iOS release version on S3
    '''
    CBL_IOS_S3_URL = 'https://packages.couchbase.com/releases/couchbase-lite-ios'
    CARTHAGE_PKG_NAME = 'couchbase-lite-carthage-{}-{}.zip'.format(args.edition, args.version)

    data_dict = parse_json_file(args.file)
    data_dict[args.version] = '{}/{}/{}'.format(CBL_IOS_S3_URL, args.version, CARTHAGE_PKG_NAME)

    try:
        with open(args.file, mode='w') as f:
            try:
                f.write(json.dumps(data_dict, indent=4))
            except json.JSONDecodeError:
                print("Invalid JSON output!")
                sys.exit(1)
    except IOError:
        print("Cannot write to file: {}").format(args.file)
        sys.exit(1)


def parse_args():
    parser = argparse.ArgumentParser(description="Publish Carthage Provision File on S3\n\n")
    parser.add_argument('--version', '-v', help='Carthage Version',
                        required=True)
    parser.add_argument('--file', '-f', help='JSON file', required=True)
    parser.add_argument('--edition', '-e', help='Carthage Package Edition',
                        required=True)
    return parser.parse_args()


def main():
    args = parse_args()
    update_json_file(args)


if __name__ == '__main__':
    main()
