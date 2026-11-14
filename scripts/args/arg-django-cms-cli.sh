#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The django CMS project in this workspace.')
parser.add_argument('-r', '--run',
                    default="_none_",
                    help='A manage.py command to run in the project, without the leading manage.py. Example: --run "showmigrations cms"')
parser.add_argument('-u', '--update',
                    action='store_true',
                    default=False,
                    help='Update django CMS and its packages within the major line the site is on, migrate the database and start the server again.')
parser.add_argument('-s', '--restart',
                    action='store_true',
                    default=False,
                    help='Start the server again, and wait until it answers.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='Add the default accounts: an administrator and an editor. An account that is already there is left as it is.')
parser.add_argument('-c', '--cancel-users',
                    action='store_true',
                    default=False,
                    help='Delete the default accounts and what belongs to them.')
ARGEOF
