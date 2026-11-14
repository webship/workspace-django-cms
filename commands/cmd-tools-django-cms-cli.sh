#!/usr/bin/env bash

# Installed by the django CMS plugin (plugins.sh --install django-cms); __WORKSPACE__ is the workspace it was installed into.
#
# manage.py for one django CMS project of this workspace, in its container: say what the site is,
# run a manage.py command, update django CMS, restart the server, add or remove the default
# accounts. Nothing here runs on the host.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="django_cms";

ARGPARSE_DESCRIPTION="Run manage.py on a django CMS project of __WORKSPACE__: status, a command, an update, a restart, the default accounts"
# The args file comes with the plugin: core/scripts/plugins/django-cms/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/django-cms/args/arg-django-cms-cli.sh || exit 1 ;

shift $#;

django_cms_cli_tool ;
