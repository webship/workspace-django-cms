#!/usr/bin/env bash

# django CMS for the Webship Workspace: build a site, run manage.py on it, add its default
# accounts, and wire its step pack into the testing setup.
#
# Placed by `plugins.sh --install django-cms` in core/scripts/plugins/django-cms/functions/, where
# bootstrap sources it after the core's own functions. Everything runs in the project's container
# (DDEV by default), never on the host: the web image gets Python, the site lives in a virtual
# environment of the project, the web container runs the Django server as a daemon, the router
# serves it at the project's address, and PostgreSQL is the container tool's database.
#
# django CMS is not a PHP platform and DDEV has no project type for it, so a django CMS project is
# recognised by a file (.ddev/config.django-cms.yaml, written by the builder), and four names are
# the ones the core's tools look for. A platform's name becomes part of a bash function name, so
# the hyphen of `django-cms` is an underscore there:
#   set_django_cms_users          the default accounts                (cmd-tools-add-users.sh <project> django_cms)
#   add_django_cms_users          create them in the site's database  (the same tool, and --add-users of the builder)
#   cancel_django_cms_users       delete them                         (cmd-tools-cancel-users.sh <project> django_cms)
#   testing_configure_django_cms  the step pack in the testing stack  (cmd-tools-testing.sh <project>)

# The step pack a django CMS project is tested with, and the release line it is required at.
readonly DJANGO_CMS_STEPS_PACKAGE='@webship-js/django-cms-steps';
readonly DJANGO_CMS_STEPS_VERSION='^2.2.0';

# Where the site lives in the web container: the virtual environment, the Django project that the
# django CMS quickstart command makes, and the port the server listens on.
readonly DJANGO_CMS_ROOT='/var/www/html';
readonly DJANGO_CMS_SITE='djangocmssite';
readonly DJANGO_CMS_PORT='8000';

# The oldest release the builder makes a site of: the quickstart command got --versioning in it.
readonly DJANGO_CMS_MINIMUM='5.1';

# The default accounts, the ones a scenario logs in as: an administrator (a superuser) and an
# editor (staff, in the group Editors, who works on pages and not on accounts). Accounts are
# configuration, created once on the site; a test suite never creates or deletes one. The
# superuser the builder creates is the workspace account and is not in this list.
function set_django_cms_users() {
  users=(administrator editor);
  local user ;
  for user in "${users[@]}" ; do
    printf -v "user_${user}_name" '%s' "${user}" ;
    printf -v "user_${user}_mail" '%s' "${user}@example.com" ;
    printf -v "user_${user}_password" '%s' 'dD.123123ddd' ;
  done
  user_administrator_role='superuser' ;
  user_editor_role='editor' ;
}

# Is this folder a django CMS project? The builder leaves .ddev/config.django-cms.yaml in it.
function django_cms_is_project() {
  local project_path="$1";
  [ -f "${project_path}/.ddev/config.django-cms.yaml" ] ;
}

# Go to the project a tool was asked about, or say why not.
function django_cms_enter_project() {
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}";
  if [ ! -d "${project_path}" ] ; then
    echo "No project ${PROJECT_NAME} in ${WORKSPACE_ROOT}/${doc_name}." ;
    return 1 ;
  fi
  if ! django_cms_is_project "${project_path}" ; then
    echo "${doc_name}/${PROJECT_NAME} is not a django CMS project (it has no .ddev/config.django-cms.yaml)." ;
    return 1 ;
  fi
  cd "${project_path}" || return 1 ;
}

# What the container tool is told about the site: the router sends the project's address to the
# Django server's port, and the server runs as a daemon of the web container once the build has
# finished.
function django_cms_write_ddev_config() {
  local project_path="$1";
  mkdir -p "${project_path}/.ddev/web-build" || return 1 ;
  cat > "${project_path}/.ddev/config.django-cms.yaml" <<YAMLEOF
# django CMS in this project. Written by the django CMS builder of the workspace; build again
# rather than editing by hand. The web container serves no files of its own: the router sends
# ports 80 and 443 of the project's address to the Django server, which the web container runs as
# a daemon.
web_extra_exposed_ports:
  - name: django-cms
    container_port: ${DJANGO_CMS_PORT}
    http_port: 80
    https_port: 443
web_extra_daemons:
  - name: django-cms
    command: "bash -c 'while [ ! -f ${DJANGO_CMS_ROOT}/${DJANGO_CMS_SITE}/.ready ]; do sleep 2; done; cd ${DJANGO_CMS_ROOT}/${DJANGO_CMS_SITE} && exec ${DJANGO_CMS_ROOT}/.venv/bin/python manage.py runserver --insecure 0.0.0.0:${DJANGO_CMS_PORT}'"
    directory: ${DJANGO_CMS_ROOT}
YAMLEOF
  cat > "${project_path}/.ddev/web-build/Dockerfile.django-cms" <<'DOCKEREOF'
# Python for the django CMS site, in the web image. Written by the django CMS builder of the
# workspace. A stale third-party repository key in the base image must not stop the build, so the
# index refresh may fail softly.
RUN (apt-get update || true) \
    && apt-get install -y --no-install-recommends python3-venv python3-pip python3-dev build-essential \
    && rm -rf /var/lib/apt/lists/*
DOCKEREOF
}

# What the builder adds to the settings the quickstart command wrote: the hosts and the proxy of
# the container tool, the container's own database (db/db/db), the mailbox of the container.
# Nothing personal is written.
function django_cms_write_settings() {
  local project_path="$1";
  local package="${project_path}/${DJANGO_CMS_SITE}/${DJANGO_CMS_SITE}";
  cat > "${package}/workspace_settings.py" <<'PYEOF'
"""Settings the Webship Workspace builder adds to the quickstart project.

settings.py imports this file last, so what is set here wins. It is yours to change.
"""

# The site is reached through the router of the container tool, over https.
ALLOWED_HOSTS = ["*"]
CSRF_TRUSTED_ORIGINS = ["https://*.ddev.site", "http://*.ddev.site", "http://localhost:8000", "http://127.0.0.1:8000"]
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")

# Off, so the site answers with its real pages (a 404 is a 404 page, not a debug page); the
# server is started with --insecure, which keeps it serving the static files. Set it to True
# while you develop.
DEBUG = False

# The database of the project's container.
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": "db",
        "USER": "db",
        "PASSWORD": "db",
        "HOST": "db",
        "PORT": "5432",
    }
}

# The mailbox of the project's container: no e-mail leaves the machine.
EMAIL_HOST = "127.0.0.1"
EMAIL_PORT = 1025

# One cache for the server and for manage.py, so a command can clear what the server has cached.
CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.filebased.FileBasedCache",
        "LOCATION": "/tmp/django-cms-cache",
    }
}
PYEOF
  if ! grep -q "workspace_settings" "${package}/settings.py" ; then
    printf '\nfrom .workspace_settings import *  # noqa: E402,F401,F403\n' >> "${package}/settings.py" ;
  fi
}

# manage.py in the container, with the Python of the site's virtual environment.
function django_cms_manage() {
  ddev exec -d "${DJANGO_CMS_ROOT}/${DJANGO_CMS_SITE}" "${DJANGO_CMS_ROOT}/.venv/bin/python manage.py $*" ;
}

# The release of django CMS the project runs.
function django_cms_version() {
  ddev exec "${DJANGO_CMS_ROOT}/.venv/bin/python -c 'import cms; print(cms.__version__)'" 2>/dev/null | tr -d '\r' ;
}

# The pip requirement for a --version: a major line ("5": the latest release of it) or one release.
# The quickstart command makes a site with versioning from 5.1 on, so the 5 line starts there.
function django_cms_requirement() {
  local version="$1" ;
  if [[ "${version}" =~ ^[0-9]+$ ]] ; then
    if [ "${version}" == "${DJANGO_CMS_MINIMUM%%.*}" ] ; then
      echo "django-cms>=${DJANGO_CMS_MINIMUM},<$(( version + 1 ))" ;
    else
      echo "django-cms>=${version},<$(( version + 1 ))" ;
    fi
  else
    echo "django-cms==${version}" ;
  fi
}

# Is this --version one the builder can make a site of? A major line from the minimum's on, or a
# release that is not older than the minimum.
function django_cms_version_supported() {
  local version="$1" ;
  if [[ "${version}" =~ ^[0-9]+$ ]] ; then
    [ "${version}" -ge "${DJANGO_CMS_MINIMUM%%.*}" ] ;
  else
    [ "$(printf '%s\n%s\n' "${DJANGO_CMS_MINIMUM}" "${version}" | sort -V | head -n 1)" == "${DJANGO_CMS_MINIMUM}" ] ;
  fi
}

# Wait until the Django server answers on its own port.
function django_cms_wait() {
  local attempt code ;
  for attempt in $(seq 1 60) ; do
    code="$(ddev exec "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:${DJANGO_CMS_PORT}/admin/login/" 2>/dev/null | tr -d '\r')" ;
    case "${code}" in
      200|301|302) return 0 ;;
    esac
    sleep 3 ;
  done
  echo "The Django server did not start; the end of its log:" ;
  ddev exec "supervisorctl tail webextradaemons:django-cms stderr" 2>/dev/null ;
  return 1 ;
}

# Start the Django server again (the daemon of the web container), and wait for it.
function django_cms_restart() {
  ddev exec "supervisorctl restart webextradaemons:django-cms" || return 1 ;
  django_cms_wait ;
}

# Run a verb of django-cms-accounts.py (installed, owner, add, cancel, list) in the container.
# The script is piped to the Python of the site, and what it needs travels as base64 of a JSON
# object, so no password is written into a file of the project and no quoting can break a value.
function django_cms_accounts() {
  local verb="$1" script="${WORKSPACE_SCRIPTS}/plugins/django-cms/django-cms-accounts.py" rows="" user name mail password role payload ;
  if [ ! -f "${script}" ] ; then
    echo "django-cms-accounts.py is not in ${WORKSPACE_SCRIPTS}/plugins/django-cms: install the plugin (plugins.sh --install django-cms)." ;
    return 1 ;
  fi
  for user in "${users[@]}" ; do
    name="user_${user}_name"; mail="user_${user}_mail"; password="user_${user}_password"; role="user_${user}_role";
    rows="${rows}${!name}"$'\x1f'"${!mail}"$'\x1f'"${!password}"$'\x1f'"${!role}"$'\x1e' ;
  done
  payload="$(DJANGO_CMS_OWNER_NAME="${account_name}" DJANGO_CMS_OWNER_MAIL="${account_mail}" DJANGO_CMS_OWNER_PASS="${account_pass}" \
    DJANGO_CMS_ROWS="${rows}" python3 -c '
import base64, json, os
accounts = [dict(zip(("name", "email", "password", "role"), row.split("\x1f"))) for row in os.environ["DJANGO_CMS_ROWS"].split("\x1e") if row]
print(base64.b64encode(json.dumps({
    "owner": {"name": os.environ["DJANGO_CMS_OWNER_NAME"], "email": os.environ["DJANGO_CMS_OWNER_MAIL"], "password": os.environ["DJANGO_CMS_OWNER_PASS"]},
    "accounts": accounts,
}).encode()).decode())')" || return 1 ;
  ddev exec -d "${DJANGO_CMS_ROOT}/${DJANGO_CMS_SITE}" "DJANGO_CMS_ACCOUNTS=${payload} DJANGO_CMS_ACCOUNTS_VERB=${verb} ${DJANGO_CMS_ROOT}/.venv/bin/python -" < "${script}" ;
}

# Build a django CMS site from nothing: the container, the code, the database, and with --install
# its superuser.
function django_cms_build() {
  trim_project_name ;
  local base_url="https://${PROJECT_NAME}.ddev.site" ;
  local version="${VERSION:-${site_version:-5}}" ;
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}" ;
  local requirement ; requirement="$(django_cms_requirement "${version}")" ;

  if ! django_cms_version_supported "${version}" ; then
    echo "django CMS ${version} is older than ${DJANGO_CMS_MINIMUM}, the first release whose quickstart command makes a site with versioning." ;
    echo "Nothing was changed. Build with --version ${DJANGO_CMS_MINIMUM%%.*} (the latest release of that line), or a release from ${DJANGO_CMS_MINIMUM} on." ;
    exit 1 ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name} || exit 1 ;

  drop_database ;
  rm -rf "${PROJECT_NAME}" ;
  mkdir -p "${PROJECT_NAME}" ;
  cd "${project_path}" || exit 1 ;

  # A generic web server: no nginx and no PHP are started. The database is PostgreSQL.
  ddev config --project-type=generic --webserver-type=generic --docroot="" --project-name=${PROJECT_NAME} \
    --database=postgres:16 --nodejs-version=$(ddev_nodejs_version) || exit 1 ;
  django_cms_write_ddev_config "${project_path}" || exit 1 ;
  ddev_up start -y || exit 1 ;

  echo "Installing ${requirement} in a virtual environment. This takes a few minutes." ;
  ddev exec "python3 -m venv .venv && .venv/bin/pip install --quiet --upgrade pip && .venv/bin/pip install --quiet '${requirement}' 'psycopg[binary]'" \
    || { echo "The install of django CMS failed." ; exit 1 ; } ;

  # The django CMS quickstart: django CMS with djangocms-versioning, djangocms-alias,
  # djangocms-text, djangocms-frontend and django-filer. It sets its own first database up; the
  # settings below move the site to the database of the container.
  echo "Creating the project with the django CMS quickstart command (with versioning)." ;
  ddev exec "source .venv/bin/activate && djangocms ${DJANGO_CMS_SITE} --noinput --username quickstart --email quickstart@example.com --versioning --alias" \
    || { echo "The django CMS quickstart command failed." ; exit 1 ; } ;
  rm -f "${project_path}/${DJANGO_CMS_SITE}/db.sqlite3" ;

  django_cms_write_settings "${project_path}" ;
  django_cms_manage migrate --noinput || { echo "manage.py migrate failed." ; exit 1 ; } ;

  touch "${project_path}/${DJANGO_CMS_SITE}/.ready" ;
  echo "Starting the Django server." ;
  django_cms_restart || exit 1 ;

  if [ "${INSTALL}" == 'yes' ] ; then
    users=() ;
    django_cms_accounts owner || { echo "The superuser could not be created." ; exit 1 ; } ;

    if [ "${ADD_USERS}" == 'yes' ] ; then
      set_django_cms_users ;
      add_django_cms_users ;
      cd "${project_path}" || exit 1 ;
    fi

    echo "${doc_name} ${PROJECT_NAME} has been installed: django CMS $(django_cms_version).";
    echo "Go to ${base_url}/admin/ and log in as ${account_name}";
  else
    [ "${ADD_USERS}" == 'yes' ] && echo "--add-users needs --install: the site has no superuser yet." ;
    echo "${doc_name} ${PROJECT_NAME} is ready, without a superuser: django CMS $(django_cms_version).";
    echo "Give it one with: bash cmd-tools-django-cms-cli.sh ${PROJECT_NAME} --run createsuperuser   (or build with --install)";
    echo "Go to ${base_url}";
  fi

  if [ "${LAUNCH}" == 'yes' ] ; then
    ddev launch ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name};
}

# Create the default accounts in the site's database. An account that is already there is left as
# it is. The list is loaded by the caller (set_django_cms_users): the core's add_users, the
# builder, the CLI tool.
function add_django_cms_users() {
  django_cms_enter_project || return 1 ;
  local user user_name user_mail user_password user_role ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    user_password="user_${user}_password"; user_role="user_${user}_role";

    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo "      User mail: ${!user_mail}";
    echo "  User password: ${!user_password}";
    echo "      User role: ${!user_role}";
    echo " ================================================================= ";
  done
  django_cms_accounts add ;
  local status=$? ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${status} ;
}

# Delete the default accounts. One that has written page versions the site keeps is deactivated
# instead.
function cancel_django_cms_users() {
  django_cms_enter_project || return 1 ;
  local user user_name ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name";
    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo " ================================================================= ";
  done
  django_cms_accounts cancel ;
  local status=$? ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${status} ;
}

# What cmd-tools-django-cms-cli.sh does: the first of --run, --update, --restart, --add-users,
# --cancel-users that was asked for; with none of them, what the site is.
function django_cms_cli_tool() {
  trim_project_name ;
  django_cms_enter_project || exit 1 ;

  if ! ddev describe -j 2>/dev/null | grep -q '"status":"running"' ; then
    ddev start -y || exit 1 ;
  fi

  if [ ! "${RUN}" == '_none_' ] ; then
    # Unquoted on purpose: --run "showmigrations cms" is a command and its arguments.
    django_cms_manage ${RUN} ;
    exit $? ;
  fi

  if [ "${UPDATE}" == 'yes' ] ; then
    local installed major ;
    installed="$(django_cms_version)" ; major="${installed%%.*}" ;
    echo "django CMS ${installed} is installed." ;
    ddev exec "${DJANGO_CMS_ROOT}/.venv/bin/pip install --quiet --upgrade '$(django_cms_requirement "${major}")'" || exit 1 ;
    django_cms_manage migrate --noinput || exit 1 ;
    django_cms_restart || exit 1 ;
    echo "django CMS $(django_cms_version) is running." ;
  elif [ "${RESTART}" == 'yes' ] ; then
    django_cms_restart || exit 1 ;
    echo "django CMS $(django_cms_version) is running." ;
  elif [ "${ADD_USERS}" == 'yes' ] ; then
    set_django_cms_users ;
    add_django_cms_users ;
  elif [ "${CANCEL_USERS}" == 'yes' ] ; then
    set_django_cms_users ;
    cancel_django_cms_users ;
  else
    echo "${doc_name}/${PROJECT_NAME}: django CMS $(django_cms_version) at https://${PROJECT_NAME}.ddev.site" ;
    echo "" ; echo "Packages:" ;
    ddev exec "${DJANGO_CMS_ROOT}/.venv/bin/pip list 2>/dev/null | grep -i -E '^(django|djangocms|django-cms|django-filer|psycopg)' | sed 's/^/   /'" ;
    echo "" ; echo "Accounts:" ;
    users=() ;
    django_cms_accounts list ;
  fi
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# The step pack in the testing stack of a django CMS project. The core's testing_configure calls
# this in the project folder once webship-js is scaffolded and before the dependencies are
# installed; for a project that is not django CMS it changes nothing.
#
# It adds the pack to package.json, lists its step definitions in cucumber.js after webship-js's
# own, gives cucumber.js the users registry of the default accounts (a handle a scenario reads,
# mapped to an account; never the workspace account) and the language the admin is opened in, and
# writes a first feature when the project has none of its own. Every part is skipped when it is
# already there, so a second run adds what the first missed and never resets a suite.
function testing_configure_django_cms() {
  local project_path="$1";
  django_cms_is_project "${project_path}" || return 0 ;
  if [ ! -f "${project_path}/cucumber.js" ] || [ ! -f "${project_path}/package.json" ] ; then
    echo "  django CMS: cucumber.js is not here yet — run the testing setup again once webship-js is scaffolded." ;
    return 1 ;
  fi

  echo "Adding the django CMS step pack (${DJANGO_CMS_STEPS_PACKAGE} ${DJANGO_CMS_STEPS_VERSION}).";
  set_django_cms_users ;
  local registry="" user user_name user_password handle ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_password="user_${user}_password";
    # The pack's features call the administrator "admin".
    handle="${user}" ; [ "${user}" == 'administrator' ] && handle="admin" ;
    registry="${registry}${handle}|${!user_name}|${!user_password}"$'\n' ;
  done

  python3 - "${project_path}" "${DJANGO_CMS_STEPS_PACKAGE}" "${DJANGO_CMS_STEPS_VERSION}" 'DJANGOCMS' "${registry}" <<'PYEOF' || return 1
import json, re, sys

project, pack, version, prefix, registry = sys.argv[1:6]

# package.json: the pack as a dev dependency, at the release line this plugin was proven on.
pkg_file = project + '/package.json'
pkg = json.load(open(pkg_file))
if pack not in pkg.get('dependencies', {}) and pack not in pkg.get('devDependencies', {}):
    pkg.setdefault('devDependencies', {})[pack] = version
    open(pkg_file, 'w').write(json.dumps(pkg, indent=2) + '\n')
    print('  package.json: %s %s' % (pack, version))

# cucumber.js: the pack's step definitions after webship-js's own, the users registry, the admin language.
cucumber_file = project + '/cucumber.js'
src = open(cucumber_file).read()
before = src

if ('node_modules/%s/' % pack) not in src:
    line = "'node_modules/%s/tests/step-definitions/*.steps.js'," % pack
    core = re.search(r"^([ \t]*)'node_modules/webship-js/tests/step-definitions/[^']*',.*$", src, re.M)
    opening = re.search(r"^([ \t]*)require:[ \t]*\[[ \t]*$", src, re.M)
    if core:
        src = src[:core.end()] + '\n' + core.group(1) + line + src[core.end():]
    elif opening:
        src = src[:opening.end()] + '\n' + opening.group(1) + '  ' + line + src[opening.end():]
    else:
        sys.exit("  cucumber.js has no require list this can add to. Add this line to it:\n    " + line)
    print('  cucumber.js: the step definitions of %s' % pack)

world = re.search(r"^([ \t]*)worldParameters:[ \t]*\{[ \t]*$", src, re.M)
if not re.search(r"^[ \t]*users:[ \t]*\{", src, re.M):
    if not world:
        sys.exit("  cucumber.js has no worldParameters block to add the users registry to.")
    pad = world.group(1) + '  '
    rows = [r.split('|') for r in registry.splitlines() if r.strip()]
    block = [
        pad + "// The users registry: a handle a scenario reads, mapped to an account of this site (the default",
        pad + "// accounts: cmd-tools-add-users.sh). Override one with %s_<HANDLE>_USER and %s_<HANDLE>_PASS." % (prefix, prefix),
        pad + "users: {",
    ]
    for handle, name, password in rows:
        env = '%s_%s' % (prefix, handle.upper())
        block.append(pad + "  %s: { username: process.env.%s_USER || '%s', password: process.env.%s_PASS || '%s' }," % (handle, env, name, env, password))
    block.append(pad + "},")
    src = src[:world.end()] + '\n' + '\n'.join(block) + src[world.end():]
    print('  cucumber.js: the users registry (%s)' % ', '.join(r[0] for r in rows))

if world and not re.search(r"^[ \t]*djangoCms:", src, re.M):
    world = re.search(r"^([ \t]*)worldParameters:[ \t]*\{[ \t]*$", src, re.M)
    pad = world.group(1) + '  '
    block = [
        pad + "// What the steps need to know about the site. `adminLanguage` opens the admin under that language",
        pad + "// prefix (/en/admin/), so the admin and the page tree answer in the language the features are written in.",
        pad + "djangoCms: { adminLanguage: process.env.%s_ADMIN_LANGUAGE || 'en' }," % prefix,
    ]
    src = src[:world.end()] + '\n' + '\n'.join(block) + src[world.end():]
    print('  cucumber.js: the language of the admin (djangoCms.adminLanguage)')

if src != before:
    open(cucumber_file, 'w').write(src)
PYEOF

  # A first feature, when the project has none for the site yet: the front page, the login page,
  # each default account in its role.
  local feature="${WORKSPACE_SCRIPTS}/plugins/django-cms/site.feature" ;
  if [ -f "${feature}" ] && [ ! -f "${project_path}/tests/features/site.feature" ] ; then
    mkdir -p "${project_path}/tests/features" && cp "${feature}" "${project_path}/tests/features/site.feature" \
      && echo "  tests/features/site.feature: a first feature for the site" ;
  fi

  # The scenarios log in as the default accounts: make sure a site that has its superuser has them.
  if django_cms_wait > /dev/null 2>&1 && ( users=() ; django_cms_accounts installed ) > /dev/null 2>&1 ; then
    ( add_django_cms_users > /dev/null ) && echo "  the default accounts are on the site (${users[*]})" ;
  fi
}
