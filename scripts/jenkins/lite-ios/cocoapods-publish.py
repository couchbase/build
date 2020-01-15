#!/usr/bin/env python3
''' Script to update cocoapod's podspec files to publish to cocoapods.org
    for CBL iOS release
'''
import argparse
import difflib
import fileinput
import re
import subprocess
import sys


def update_podspec_file(args):
    '''
    Replace 2 items in .podspec files: version and source
    s.version                   = '2.0.0'
    s.source                    = { :http =>
        'https://packages.couchbase.com/releases/couchbase-lite/ios/2.0.0/
        couchbase-lite-swift_community_2.0.0.zip' }
    '''
    package_dict = {'CouchbaseLite-Enterprise.podspec':
                    'couchbase-lite-objc_enterprise',
                    'CouchbaseLite-Swift-Enterprise.podspec':
                    'couchbase-lite-swift_enterprise',
                    'CouchbaseLite-Swift.podspec':
                    'couchbase-lite-swift_community',
                    'CouchbaseLite.podspec': 'couchbase-lite-objc_community'
                    }
    s3_url = 'https://packages.couchbase.com/releases/couchbase-lite-ios'
    if args.file in package_dict:
        package_name = package_dict[args.file]
        pkg_url = '{}/{}/{}_{}.zip'.format(
            s3_url, args.version, package_name, args.version)

        replace_src_key = 's.source                    = '
        string_head = "{ :http => '"
        string_end = "' }"
        replace_src = "{}{}{}{}".format(replace_src_key, string_head,
                                        pkg_url, string_end)

        for line in fileinput.FileInput(args.file, inplace=1, backup='.bak'):
            if "s.version" in line:
                line = re.sub(r'(s\.version.*\=)(.*)', r"\1 " + '\''
                              + args.version + '\'', line.rstrip())
                print(line)
            elif "s.source" in line:
                line = re.sub(r's\.source.*', replace_src, line.rstrip())
                print(line)
            else:
                print(line, end='')
    else:
        print("Could not find matching .podspec: %s" % args.file)
        sys.exit(1)


def diff_file_changes(args):
    '''
    Sanity check diff output
    '''
    try:
        with open(args.file) as file1, open(args.file + '.bak') as file2:
            diff = difflib.unified_diff(file1.readlines(),
                                        file2.readlines(), lineterm='\n')
            for line in diff:
                if '+' in line or '-' in line:
                    print(line)
    except IOError:
        print("Could not open file: {}".format(args.file))
        sys.exit(1)


def pod_spec_lint(args):
    '''
    Run pod lint
    '''
    try:
        subprocess.check_call(['pod', 'spec', 'lint', args.file])
    except subprocess.CalledProcessError as exc:
        print("pod lint failed: {}".format(exc.output))
        sys.exit(1)


def parse_args():
    parser = argparse.ArgumentParser(description="Provision cocoapod \
                                     podspec File\n\n")
    parser.add_argument('--version', '-v', help='CBL iOS Version',
                        required=True)
    parser.add_argument('--file', '-f',
                        help='Cocoapod podspec file', required=True)
    return parser.parse_args()


def main():
    args = parse_args()
    update_podspec_file(args)
    diff_file_changes(args)
    pod_spec_lint(args)


if __name__ == '__main__':
    main()
