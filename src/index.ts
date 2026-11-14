/**
 * django CMS for Webship Workspace: a platform plugin.
 *
 * What the package carries is placed by the installer from the manifest: the builder and the
 * manage.py tool in the sites folders, their functions, argparse and the accounts script under
 * core/scripts/plugins/django-cms/, the agents in the AI Agents folder. The dashboard needs
 * nothing drawn for it: the builder is in the Build list because it is a cmd-*-project.sh, the
 * row menus are the core's, the agents are listed like any other. What register() adds is what
 * the assistant is told.
 *
 * Everything the dashboard is asked for goes through `api`; this package requires nothing from the
 * dashboard's own files, so it can be installed from npm and removed without a trace.
 */

import type { PluginApi } from '@webship.co/workspace-plugin-api';

/** The plugin's name. In a bash function name its hyphen is an underscore (`set_django_cms_users`). */
export const PLATFORM = 'django-cms';

/** The commands the installer places in every sites folder. */
export const COMMANDS = ['cmd-django-cms-project.sh', 'cmd-tools-django-cms-cli.sh'];

/** The agents the installer places in the AI Agents folder. */
export const AGENTS = ['django-cms-site-builder', 'django-cms-tester'];

/** What the assistant is told about django CMS in this workspace. */
export function assistantContext(): string {
  return [
    'django CMS (a plugin, @webship.co/workspace-django-cms): a django CMS site is built with',
    '`bash cmd-django-cms-project.sh <name> --install --add-users` from a sites folder (dev, test, sandboxes, demos),',
    'in a container like every other project, at https://<name>.ddev.site (the admin at /admin/).',
    '`bash cmd-tools-django-cms-cli.sh <name>` says what the site is; `--run "<manage.py command>"` runs manage.py in it,',
    '`--update` updates django CMS within its major line, `--restart` starts the server again,',
    '`--add-users` adds the default accounts (an administrator and an editor).',
    '`bash cmd-tools-testing.sh <name>` sets up webship-js with the django CMS step pack; `--run` runs the suite.',
    `For django CMS work, hand over to the agents ${AGENTS.map((a) => `\`${a}\``).join(' and ')}.`,
    'Never run python, pip, manage.py or psql on the host for a project; the superuser of a site is the workspace account.',
  ].join(' ');
}

export function register(api: PluginApi): void {
  api.addAssistantContext(assistantContext);
}
