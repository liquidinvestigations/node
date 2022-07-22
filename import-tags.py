#!/usr/bin/env python
import subprocess
from argparse import ArgumentParser
import sys

parser = ArgumentParser()
parser.add_argument('-t', '--tags', dest='filename', required=True,
                    help='Path to a csv file that contains the new tags.')
parser.add_argument('-c', '--collection', dest='collection', required=True,
                    help='Collection for which the new tags should be added.')
parser.add_argument('-u', '--user', dest='username', required=True,
                    help='User for which tags should be added.')
parser.add_argument('-p', '--public', dest='public',
                    action='store_true', default=False,
                    help='Flag to set if the new tags should be public.')

args = parser.parse_args()
with open(args.filename) as f:
    csv_str = f.read()

uuid_output = subprocess.run(['./liquid', 'dockerexec', 'hoover:search', './manage.py',
                              'getuuid', args.username],
                             capture_output=True)

uuid = uuid_output.stdout.strip().decode('utf-8')

if not uuid:
    print(f'Error: Could not find uuid for user: {args.username}')
    sys.exit(1)

import_command = ['./liquid', 'dockerexec', 'hoover:snoop', './manage.py', 'importtags',
                  '-c', args.collection,
                  '--tags', csv_str,
                  '--uuid', uuid,
                  '--user', args.username]
if args.public:
    import_command.append('--public')

subprocess.run(import_command)
