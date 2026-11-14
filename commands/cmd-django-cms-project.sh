#!/usr/bin/env bash

# workspace-name: django CMS 5

# Installed by the django CMS plugin (plugins.sh --install django-cms); __WORKSPACE__ is the workspace it was installed into.
#
# Build a django CMS site in a container: the latest release of the 5 line with versioning, or the
# one --version names, at https://<name>.ddev.site. With --install the workspace account becomes
# its superuser; with --add-users it also gets the default accounts.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Set site version.
site_version="5";

# Distribution.
distribution_name="django_cms";
distribution_title="django CMS";
distribution_webroot="";

ARGPARSE_DESCRIPTION="Build a ${distribution_title} project in __WORKSPACE__"
# The args file comes with the plugin: core/scripts/plugins/django-cms/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/django-cms/args/arg-django-cms.sh || exit 1 ;

shift $#;

django_cms_build ;
