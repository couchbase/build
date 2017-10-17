#!/usr/bin/env python3

import re
import sys
import argparse
from argparse import RawTextHelpFormatter
from lxml import etree


def parse_src_input(input):
    # parse locked SHA build input to get lock revisions
    tree = etree.parse(input)

    input_lock_src = {}
    input_src_data = tree.iterfind("//project")

    for input_src in input_src_data:
        input_src_name = input_src.get('name')
        input_src_path = input_src.get('path', input_src_name)
        input_src_revision = input_src.get('revision')

        input_lock_src[input_src_path] = {
            'name': input_src_name,
            'revision': input_src_revision
        }

    print("Found \"%s\" repo(s) with locked SHA from %s" %
          (len(input_lock_src), args.input_lock_src))
    print()
    return input_lock_src


def main(args):

    lock_src_dict = parse_src_input(args.input_lock_src)

    # Loop through input_src file
    # Replace the git SHA from src_lock_input xml
    tree = etree.parse(args.input_src)
    result_dict = tree.iterfind("//project")
    sha_regex = re.compile(r'\b([a-f0-9]{40})\b')

    for result in result_dict:
        result_src_name = result.get('name')
        result_path = result.get('path', result_src_name)
        result_revision = result.get('revision')
        if result_path and not result_revision or not sha_regex.match(result_revision):
            try:
                result.attrib['revision'] = lock_src_dict[result_path]['revision']
            except KeyError as e:
                print("Error: %s repo not found in \"%s\" input file!" % (e, args.input_lock_src))
                print()
                sys.exit(1)

    # write data
    tree.write(args.output, encoding='UTF-8',
               xml_declaration=True, pretty_print=True)
    print("\nOutput locked SHA has been generated here: %s\n" % args.output)
    print


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Lock manifest to SHA\n\n"
                                     "exe1: ./lock-to-sha.py  --input-src spock.xml  --input-lock-src couchbase-server-5.0.0-3519-manifest.xml --output 5.0.0.xml\n"
                                     "exe2: ./lock-to-sha.py --input-src vulcan.xml --input-lock-src couchbase-server-5.1.0-1297-manifest.xml\n\n", formatter_class=RawTextHelpFormatter)
    parser.add_argument('--input-src',
                        help="Input xml to lock to sha. e.g. spock.xml, vulcan.xml\n\n",
                        required=True)
    parser.add_argument('--input-lock-src',
                        help="Input xml that has locked SHA. e.g. couchbase-server-5.0.0-3519-manifest.xml\n\n",
                        required=True)
    parser.add_argument('--output',
                        help="Output result xml file name.  e.g. 5.0.0.xml, 5.0.1.xml\n"
                        "default: out.xml",
                        default='out.xml',
                        required=False)
    args = parser.parse_args()
    main(args)
