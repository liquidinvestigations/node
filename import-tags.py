#!/usr/bin/env python
"""Script to import tags into hoover.

Receives a csv with tags as stdin. Use it like: tags.csv | -c collection -u username
"""
import subprocess
from argparse import ArgumentParser
import sys

parser = ArgumentParser()
parser.add_argument('-c', '--collection', dest='collection', required=True,
                    help='Collection for which the new tags should be added.')
parser.add_argument('-u', '--user', dest='username', required=True,
                    help='User for which tags should be added.')
parser.add_argument('-p', '--public', dest='public',
                    action='store_true', default=False,
                    help='Flag to set if the new tags should be public.')

args = parser.parse_args()

# check if any data has been received as stdin
if sys.stdin.isatty():
    print('No stdin received. Pass the csv with tags as stdin')
    print('Exiting')
    sys.exit(1)

# use devnull as stdin to prevent consuming the data that has been passed to the script
uuid_output = subprocess.run(['./liquid', 'dockerexec', 'hoover:search', './manage.py',
                              'getuuid', args.username],
                             capture_output=True,
                             stdin=subprocess.DEVNULL)

uuid = uuid_output.stdout.strip().decode('utf-8')

if not uuid:
    print(f'Error: Could not find uuid for user: {args.username}')
    sys.exit(1)

# stdin is passed to this subprocess
import_command = ['./liquid', 'dockerexec', 'hoover:snoop', './manage.py', 'importtags',
                  '-c', args.collection,
                  '--uuid', uuid,
                  '--user', args.username]
if args.public:
    import_command.append('--public')

subprocess.run(import_command)
