# @webship.co/workspace-django-cms

django CMS for the [Webship Workspace](https://github.com/webship/workspace) dashboard: a builder
that makes a real django CMS site in a container, a manage.py tool for the sites it built, the
default accounts, the [django CMS step pack](https://github.com/webship/django-cms-steps) wired
into the workspace's testing setup, and its AI items — two agents, a skill, a
command and a prompt — each listed in the workspace folder of its kind.

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
bash core/scripts/plugins.sh --install django-cms                             # commands, functions, args, AI items
bash core/scripts/plugins.sh --configure django-cms                           # nothing to configure: it has no settings file
```

The same four steps are buttons on the dashboard's **Settings → Plugins** page. `--install` is
idempotent. `--uninstall` removes what it placed; an AI item you edited stays.

Everything the plugin carries lands in the folder it belongs to, when that folder is an active
workspace folder:

| What | Lands in |
| --- | --- |
| `cmd-django-cms-project.sh`, `cmd-tools-django-cms-cli.sh` | every active sites folder: `dev/`, `test/`, `sandboxes/`, `demos/` |
| The agents `django-cms-site-builder`, `django-cms-tester` | `ai-agents/` |
| The skill `django-cms-scenarios` | `ai-skills/` |
| The command `/django-cms-test` | `ai-commands/` |
| The prompt `django-cms-build-and-test` | `ai-prompts/` |

There they are listed like any other item of the folder, and installed into Claude Code from there.

The agents, the builder's flags in the Build form and the step pack in the testing setup need a
Webship Workspace after 1.0.6.

## What it needs

A workspace starts empty, so the manifest says what else this plugin needs (`needs`):

- one sites folder, for the builder and the tool: `dev`, `test`, `sandboxes`, `demos` (`dev` is the one added when none is there). The folder also carries `cmd-tools-testing.sh` and the Users tools this plugin's hooks answer to.
- `ai-agents`, `ai-skills`, `ai-commands` and `ai-prompts`: the AI folders its agents, its skill, its command and its prompt are placed in.

`--require` says so, `--activate` and `--install` stop until the workspace has them, and `--with-needs` adds what is missing first:

```bash
bash core/scripts/plugins.sh --activate django-cms --with-needs   # dev and the four AI folders are required, activated and installed first
bash core/scripts/plugins.sh --install django-cms
```

Everything the builder runs for a site runs in the site's own container, through the container tool the workspace already needs; the plugin asks for no command of its own on the machine.

A workspace that knows none of this (Webship Workspace 1.0.8 and older) ignores the keys: add a sites folder and the AI folders yourself, then `--install django-cms` again. A kind whose folder is not there is skipped, and the install says so.

## What the package holds

| Path | What it is |
| --- | --- |
| `commands/cmd-django-cms-project.sh` | The builder, in the Build list as **django CMS 5**, installed into every sites folder |
| `commands/cmd-tools-django-cms-cli.sh` | manage.py for one project: what the site is, a command, an update, a restart, the default accounts |
| `scripts/functions/fun-django-cms.sh` | The bash functions behind both, sourced by bootstrap once installed; the names the core's tools look for (`set_django_cms_users`, `add_django_cms_users`, `cancel_django_cms_users`, `testing_configure_django_cms`) |
| `scripts/args/arg-django-cms.sh`, `arg-django-cms-cli.sh` | Their argparse; the Build form draws the builder's flags from the first |
| `scripts/django-cms-accounts.py` | The superuser and the default accounts, run with the site's Python in the project's container |
| `testing/site.feature` | The first feature a django CMS project gets when testing is set up |
| `ai/agents/django-cms-site-builder.md` | The agent that builds and maintains django CMS sites with these commands |
| `ai/agents/django-cms-tester.md` | The agent that writes and runs scenarios with the django CMS step pack |
| `ai/skills/django-cms-scenarios/` | The skill: the step pack's phrases by area, the traps found on a real site, three example features |
| `ai/commands/django-cms-test.md` | The slash command `/django-cms-test <site>`: set up, match every step, run, report |
| `ai/prompts/django-cms-build-and-test.md` | A prompt: the whole launch command for a new session |
| `src/index.ts` | `register(api)`: what the assistant is told about django CMS here |
| `features/django-cms.feature` | Scenarios for the dashboard's own browser suite |
| `docs/plugin-items-pattern.md` | How a plugin carries its own commands and AI items, and how to prove it |

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

## The AI items

`ai/` in the package holds one folder per kind, the manifest's `ai` block names each item, and
`--install` places it in the workspace folder of that kind.

| Kind | Item | Use it to |
| --- | --- | --- |
| Agent | `django-cms-site-builder` | Build, update, restart, maintain or remove a django CMS site with the commands above, in containers only |
| Agent | `django-cms-tester` | Set the testing stack up, look at the site in the Playwright MCP browser first, write scenarios from the pack's steps and run them; it never creates an account in a suite and never writes a platform name into a step phrase |
| Skill | `django-cms-scenarios` | Write a scenario from phrases that exist: the pack's steps by area (sessions and accounts, the administration, the toolbar, the wizard, versions, the page tree, the front end), the handles of the users registry, the traps found on a real site, and three features that pass on a fresh site |
| Command | `/django-cms-test <site> [feature or @tag]` | Run the suite of a site from inside a session: set up when missing, match every step, run, report what failed and why |
| Prompt | `django-cms-build-and-test` | Start a session that builds a site, says what it is, sets the testing stack up and runs the first feature |

After `--install` each is in its folder on the dashboard. **Install** there puts an agent, a skill
or a command into Claude Code (`~/.claude/agents`, `~/.claude/skills`, `~/.claude/commands`), or
from the command line:

```bash
cd ~/workspace/ai-agents   && bash cmd-tools-ai-items.sh django-cms-tester --install
cd ~/workspace/ai-skills   && bash cmd-tools-ai-items.sh django-cms-scenarios --install
cd ~/workspace/ai-commands && bash cmd-tools-ai-items.sh django-cms-test --install
```

A prompt is not installed: it is the whole `claude …` launch command of a new session, and the
dashboard's **New screen** form lists it as a template. By hand, fill the placeholders in and run
the command of the file from the folder it names.

Every step phrase the items show is checked against the definitions of the step pack and of
webship-js (`tests/fixtures/step-definitions.txt`), and every command and flag against the
plugin's own.

## Develop it

```bash
npm install     # builds dist/ (TypeScript)
npm run lint
npm test        # the manifest, the commands, the AI items, the functions against a scaffolded project
```
