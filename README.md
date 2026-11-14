# @webship.co/workspace-django-cms

django CMS for the [Webship Workspace](https://github.com/webship/workspace) dashboard: a builder
that makes a real django CMS site in a container, a manage.py tool for the sites it built, the
default accounts, the [django CMS step pack](https://github.com/webship/django-cms-steps) wired
into the workspace's testing setup, and two AI agents that know all of it.

The workspace is container-based (DDEV by default): a django CMS project is a row like any other,
so the row menus the core draws (start, stop, launch, backup, clone, remove, tests) work on it
unchanged.

The plugin is made from the reference platform plugin,
[`@webship.co/workspace-wordpress`](https://github.com/webship/workspace-wordpress); what differs is
what django CMS needs, see [What is different from a PHP platform](#what-is-different-from-a-php-platform).

## Use it

```bash
cd ~/workspace
bash core/scripts/plugins.sh --require github:webship/workspace-django-cms   # npm install into the dashboard
bash core/scripts/plugins.sh --activate django-cms                            # plugins.django-cms in settings.yml
bash core/scripts/plugins.sh --install django-cms                             # commands, functions, args, agents
bash core/scripts/plugins.sh --configure django-cms                           # nothing to configure: it has no settings file
```

The same four steps are buttons on the dashboard's **Settings → Plugins** page. `--install` is
idempotent. `--uninstall` removes what it placed; an agent you edited stays.

The commands land in the sites folders that are in the workspace (`dev`, `test`, `sandboxes`,
`demos`); the agents land in the AI Agents folder (`ai-agents/`) when the workspace has one, and are
installed into `~/.claude/agents` from there like any other agent.

The agents, the builder's flags in the Build form and the step pack in the testing setup need a
Webship Workspace after 1.0.6.

## What the package holds

| Path | What it is |
| --- | --- |
| `commands/cmd-django-cms-project.sh` | The builder, in the Build list as **django CMS 5**, installed into every sites folder |
| `commands/cmd-tools-django-cms-cli.sh` | manage.py for one project: what the site is, a command, an update, a restart, the default accounts |
| `scripts/functions/fun-django-cms.sh` | The bash functions behind both, sourced by bootstrap once installed; the names the core's tools look for (`set_django_cms_users`, `add_django_cms_users`, `cancel_django_cms_users`, `testing_configure_django_cms`) |
| `scripts/args/arg-django-cms.sh`, `arg-django-cms-cli.sh` | Their argparse; the Build form draws the builder's flags from the first |
| `scripts/django-cms-accounts.py` | The superuser and the default accounts, run with the site's Python in the project's container |
| `testing/site.feature` | The first feature a django CMS project gets when testing is set up |
| `agents/django-cms-site-builder.md` | The agent that builds and maintains django CMS sites with these commands |
| `agents/django-cms-tester.md` | The agent that writes and runs scenarios with the django CMS step pack |
| `src/index.ts` | `register(api)`: what the assistant is told about django CMS here |
| `features/django-cms.feature` | Scenarios for the dashboard's own browser suite |

The `workspacePlugin` block in `package.json` is the manifest the installer reads. The plugin's
name is `django-cms`; in the names of the bash functions, and as the name of the user list, the
hyphen is an underscore (`django_cms`).

## What is different from a PHP platform

django CMS is a Python application and DDEV has no project type for it. The plugin keeps the shape
of the reference and changes only this:

| | WordPress (the reference) | django CMS |
| --- | --- | --- |
| Project | `--project-type=wordpress`, nginx and PHP | `--project-type=generic --webserver-type=generic`: no web server; the router sends the project's address to the Django server's port, and the web container runs the server as a daemon (`.ddev/config.django-cms.yaml`) |
| Recognised by | The DDEV project type | The file `.ddev/config.django-cms.yaml` |
| The language | PHP, in the web image | Python, added to the web image (`.ddev/web-build/Dockerfile.django-cms`); the packages in a virtual environment of the project (`.venv/`) |
| Database | The container tool's default, settings written by the tool | PostgreSQL 16 from the container tool; `workspace_settings.py` carries the container's own `db` / `db` / `db` |
| Getting the code | `wp core download` | `pip install django-cms`, then the django CMS quickstart command (`djangocms <project> --versioning --alias`) |
| Install | `wp core install` | `manage.py migrate`; with `--install` the workspace account is created as the superuser |
| Accounts | WP-CLI | A script run with the site's Python (`scripts/django-cms-accounts.py`) |
| Users menu of the row | Reads the project type | Does not apply (no project type): `cmd-tools-django-cms-cli.sh --add-users`, or `cmd-tools-add-users.sh <name> django_cms` |

## The commands

Run them from a sites folder. `--help` is safe on both.

### Build a site

```bash
cd ~/workspace/dev
bash cmd-django-cms-project.sh mysite --install --add-users
```

| Flag | What it does |
| --- | --- |
| `--version <x>` | The release to install: a major line (`5`, the default: its latest release), or a number from `5.1` on, such as `5.1.2` |
| `--install` | Give the site its superuser: the workspace account |
| `--add-users` | With `--install`: add the default accounts |
| `--launch` | Open the site when it is ready |

The site answers at `https://mysite.ddev.site`, the admin at `/admin/`. It is what the django CMS
quickstart makes, with versioning and aliases: django CMS with djangocms-versioning,
djangocms-alias, djangocms-text, djangocms-frontend and django-filer. The Django project is in the
project's `djangocmssite/` folder; what the builder adds to its settings is in
`djangocmssite/djangocmssite/workspace_settings.py` (the hosts and the proxy, the database, the
mailbox of the container, `DEBUG` off so the site answers with its real pages). A project of the
same name is deleted first.

A new site has no page: a visitor is sent to the login page, and a logged-in user gets the welcome
screen.

### Work on a site

```bash
bash cmd-tools-django-cms-cli.sh mysite                              # versions, address, accounts
bash cmd-tools-django-cms-cli.sh mysite --run "showmigrations cms"   # any manage.py command
bash cmd-tools-django-cms-cli.sh mysite --update                     # the latest release of its major line, migrate, restart
bash cmd-tools-django-cms-cli.sh mysite --restart                    # start the server again and wait for it
bash cmd-tools-django-cms-cli.sh mysite --add-users                  # the default accounts
bash cmd-tools-django-cms-cli.sh mysite --cancel-users               # delete them
```

### The default accounts

| Account | What it is | Handle in the tests |
| --- | --- | --- |
| `administrator` | A superuser | `admin` |
| `editor` | Staff, in the group Editors: pages, plugins, versions, aliases and files; not users, groups or page permissions | `editor` |

Each has the address `<account>@example.com` and the password of the workspace's other default
lists. They are for local sites and for tests; the site's own superuser is the workspace account
and is never written into a test. `bash cmd-tools-add-users.sh mysite django_cms` and
`bash cmd-tools-cancel-users.sh mysite django_cms` add and remove the same list. An account that
wrote page versions the site keeps is deactivated instead of deleted, and comes back with the next
`--add-users`.

### Test a site

```bash
bash cmd-tools-testing.sh mysite                 # webship-js, the step pack, the users registry, a first feature
bash cmd-tools-testing.sh mysite --run           # run the suite in the container
bash cmd-tools-testing.sh mysite --run --path tests/features/site.feature
```

`cmd-tools-testing.sh` is the workspace's own. For a django CMS project it also adds
`@webship-js/django-cms-steps` to `package.json`, lists its step definitions in `cucumber.js` after
webship-js's own, writes the users registry (the handles above, overridable with
`DJANGOCMS_<HANDLE>_USER` and `DJANGOCMS_<HANDLE>_PASS`) and the language the admin is opened in,
places `tests/features/site.feature` when the project has none, and makes sure the default accounts
are on the site. Run it again and it adds what is missing and keeps what you changed.

## The agents

| Agent | Use it to |
| --- | --- |
| `django-cms-site-builder` | Build, update, restart, maintain or remove a django CMS site with the commands above, in containers only |
| `django-cms-tester` | Set the testing stack up, look at the site in the Playwright MCP browser first, write scenarios from the pack's steps and run them; it never creates an account in a suite and never writes a platform name into a step phrase |

After `--install` they are in the AI Agents folder of the dashboard; **Install** there puts one into
`~/.claude/agents`, or from the command line:

```bash
cd ~/workspace/ai-agents
bash cmd-tools-ai-items.sh django-cms-tester --install
```

## Develop it

```bash
npm install     # builds dist/ (TypeScript)
npm run lint
npm test        # the manifest, the commands, the agents, the functions against a scaffolded project
```
