import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { spawnSync } from 'child_process';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const FUNCTIONS = path.join(PKG, 'scripts', 'functions', 'fun-django-cms.sh');

// The cucumber.js webship-js scaffolds, as far as the testing hook reads it.
const SCAFFOLD = `module.exports = {
  default: {
    requireModule: ['ts-node/register'],
    require: [
      'node_modules/webship-js/tests/step-definitions/**/*.js',          // Webship-js core step definitions.
      'tests/step-definitions/**/*.js',                                  // Your custom step definitions.
    ],
    paths: ['tests/features/**/*.feature'],
    worldParameters: {
      launchUrl: process.env.LAUNCH_URL || 'http://localhost:8080',
    },
  },
};
`;

/** A project folder with the testing stack scaffolded, and the tooling folder the installer would have filled. */
function project(type: string) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'django-cms-plugin-'));
  const dir = path.join(root, 'dev', 'site1');
  fs.mkdirSync(path.join(dir, '.ddev'), { recursive: true });
  fs.writeFileSync(path.join(dir, '.ddev', 'config.yaml'), `name: site1\ntype: ${type === 'django-cms' ? 'generic' : type}\ndocroot: ""\n`);
  // What the builder leaves: the file a django CMS project is recognised by.
  if (type === 'django-cms') fs.writeFileSync(path.join(dir, '.ddev', 'config.django-cms.yaml'), 'web_extra_daemons: []\n');
  fs.writeFileSync(path.join(dir, 'cucumber.js'), SCAFFOLD);
  fs.writeFileSync(path.join(dir, 'package.json'), JSON.stringify({ name: 'site1', devDependencies: { 'webship-js': '^2.0.6' } }, null, 2));
  const scripts = path.join(root, 'core', 'scripts');
  fs.mkdirSync(path.join(scripts, 'plugins', 'django-cms'), { recursive: true });
  fs.copyFileSync(path.join(PKG, 'testing', 'site.feature'), path.join(scripts, 'plugins', 'django-cms', 'site.feature'));
  fs.copyFileSync(path.join(PKG, 'scripts', 'django-cms-accounts.py'), path.join(scripts, 'plugins', 'django-cms', 'django-cms-accounts.py'));
  return { root, dir, scripts };
}

/** Run bash with the plugin's functions sourced and `ddev` replaced by a recorder (the server answers 200). */
function bash(script: string, env: Record<string, string> = {}) {
  const r = spawnSync('bash', ['-c', `ddev() { echo "ddev $*" >> "\${DDEV_LOG:-/dev/null}" ; case "$*" in *curl*) echo 200 ;; esac ; return 0 ; }\nsleep() { :; }\nsource ${FUNCTIONS}\n${script}`],
    { encoding: 'utf8', env: { ...process.env, ...env } });
  return r;
}

/** What a recorded `ddev exec … DJANGO_CMS_ACCOUNTS=<base64> DJANGO_CMS_ACCOUNTS_VERB=<verb> …python -` handed to the accounts script. */
function payloads(log: string) {
  return fs.readFileSync(log, 'utf8').split('\n')
    .map((l) => /^ddev exec -d \S+ DJANGO_CMS_ACCOUNTS=(\S+) DJANGO_CMS_ACCOUNTS_VERB=(\w+) \S+\/\.venv\/bin\/python -$/.exec(l))
    .filter((m): m is RegExpExecArray => !!m)
    .map((m) => ({ verb: m[2], given: JSON.parse(Buffer.from(m[1], 'base64').toString('utf8')) }));
}

const ACCOUNT = { account_name: 'webmaster', account_mail: 'webmaster@example.com', account_pass: 'a "quoted" $pass \'word' };

test('the default accounts are an administrator and an editor, with example addresses', () => {
  const r = bash('set_django_cms_users ; for u in "${users[@]}" ; do n="user_${u}_name" ; m="user_${u}_mail" ; p="user_${u}_password" ; l="user_${u}_role" ; echo "${!n}|${!m}|${!p}|${!l}" ; done');
  assert.strictEqual(r.status, 0, r.stderr);
  const rows = r.stdout.trim().split('\n').map((l) => l.split('|'));
  assert.deepStrictEqual(rows.map((x) => x[0]), ['administrator', 'editor']);
  assert.deepStrictEqual(rows.map((x) => x[3]), ['superuser', 'editor']);
  for (const [name, mail, password] of rows) {
    assert.strictEqual(mail, `${name}@example.com`);
    assert.ok(password.length >= 8);
  }
});

test('a version is a major line or one release, from the first release with versioning on', () => {
  const r = bash('django_cms_requirement 5 ; django_cms_requirement 5.1.2 ; django_cms_requirement 6');
  assert.deepStrictEqual(r.stdout.trim().split('\n'), ['django-cms>=5.1,<6', 'django-cms==5.1.2', 'django-cms>=6,<7']);
  const supported = bash('for v in 5 6 5.1 5.1.3 5.10.0 6.0.1 4 5.0.13 4.1.9 ; do django_cms_version_supported $v && echo "$v yes" || echo "$v no" ; done');
  assert.deepStrictEqual(supported.stdout.trim().split('\n'), ['5 yes', '6 yes', '5.1 yes', '5.1.3 yes', '5.10.0 yes', '6.0.1 yes', '4 no', '5.0.13 no', '4.1.9 no']);
});

test('the builder refuses a release older than the first one with versioning, before it deletes anything', () => {
  const p = project('django-cms');
  const log = path.join(p.root, 'ddev.log');
  const r = bash('trim_project_name() { :; } ; drop_database() { echo DROPPED ; } ; PROJECT_NAME=site1 ; VERSION=5.0.13 ; django_cms_build', { WORKSPACE_ROOT: p.root, doc_name: 'dev', DDEV_LOG: log });
  assert.strictEqual(r.status, 1);
  assert.match(r.stdout, /django CMS 5\.0\.13 is older than 5\.1/);
  assert.doesNotMatch(r.stdout, /DROPPED/);
  assert.ok(fs.existsSync(path.join(p.dir, 'cucumber.js')), 'the project that was there is untouched');
  assert.ok(!fs.existsSync(log), 'and the container tool was not called');
});

test('the accounts reach the container as one encoded value: the superuser is the workspace account, nothing is written to a file', () => {
  const p = project('django-cms');
  const log = path.join(p.root, 'ddev.log');
  const env = { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log, ...ACCOUNT };
  const r = bash('set_django_cms_users ; add_django_cms_users', env);
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const [call] = payloads(log);
  assert.strictEqual(call.verb, 'add');
  assert.deepStrictEqual(call.given.owner, { name: 'webmaster', email: 'webmaster@example.com', password: ACCOUNT.account_pass }, 'a password with quotes and a dollar sign arrives whole');
  assert.deepStrictEqual(call.given.accounts.map((x: any) => `${x.name}:${x.email}:${x.role}`), ['administrator:administrator@example.com:superuser', 'editor:editor@example.com:editor']);
  assert.ok(!r.stdout.includes(ACCOUNT.account_pass), 'the password of the workspace account is not printed');
  const left = spawnSync('grep', ['-rl', 'quoted', p.dir], { encoding: 'utf8' });
  assert.strictEqual(left.stdout, '', 'and is in no file of the project');
  // The same door for removing them.
  assert.strictEqual(bash('set_django_cms_users ; cancel_django_cms_users', env).status, 0);
  assert.strictEqual(payloads(log)[1].verb, 'cancel');
});

test('the builder\'s files give the site the container\'s own services and nothing personal', () => {
  const p = project('drupal11');
  fs.mkdirSync(path.join(p.dir, 'djangocmssite', 'djangocmssite'), { recursive: true });
  fs.writeFileSync(path.join(p.dir, 'djangocmssite', 'djangocmssite', 'settings.py'), 'DEBUG = True\n');
  const r = bash(`django_cms_write_ddev_config ${p.dir} && django_cms_write_settings ${p.dir} && django_cms_write_settings ${p.dir}`);
  assert.strictEqual(r.status, 0, r.stderr);
  const settings = fs.readFileSync(path.join(p.dir, 'djangocmssite', 'djangocmssite', 'settings.py'), 'utf8');
  assert.strictEqual(settings.match(/from \.workspace_settings import \*/g)?.length, 1, 'the settings import what the builder adds, once');
  // Loaded the way Django would: the builder's values win over the quickstart's.
  const loaded = spawnSync('python3', ['-c', 'import json, sys; sys.path.insert(0, sys.argv[1]); import djangocmssite.settings as s; print(json.dumps([s.DEBUG, s.DATABASES["default"], s.EMAIL_HOST, s.EMAIL_PORT, s.SECURE_PROXY_SSL_HEADER]))', path.join(p.dir, 'djangocmssite')], { encoding: 'utf8' });
  assert.strictEqual(loaded.status, 0, loaded.stderr);
  const [debug, database, mailHost, mailPort, proxy] = JSON.parse(loaded.stdout);
  assert.strictEqual(debug, false);
  assert.deepStrictEqual(database, { ENGINE: 'django.db.backends.postgresql', NAME: 'db', USER: 'db', PASSWORD: 'db', HOST: 'db', PORT: '5432' });
  assert.deepStrictEqual([mailHost, mailPort], ['127.0.0.1', 1025], 'the mail stays in the container');
  assert.deepStrictEqual(proxy, ['HTTP_X_FORWARDED_PROTO', 'https']);
  const ddev = fs.readFileSync(path.join(p.dir, '.ddev', 'config.django-cms.yaml'), 'utf8');
  assert.match(ddev, /web_extra_exposed_ports:\n  - name: django-cms\n    container_port: 8000\n    http_port: 80\n    https_port: 443/);
  assert.match(ddev, /web_extra_daemons:\n  - name: django-cms\n    command: ".*\/\.venv\/bin\/python manage\.py runserver --insecure 0\.0\.0\.0:8000'"/);
  assert.match(fs.readFileSync(path.join(p.dir, '.ddev', 'web-build', 'Dockerfile.django-cms'), 'utf8'), /apt-get install -y --no-install-recommends python3-venv /, 'Python is in the web image');
});

test('the testing hook adds the step pack, the users registry, the admin language and a first feature to a django CMS project, once', () => {
  const p = project('django-cms');
  const log = path.join(p.root, 'ddev.log');
  const run = () => bash(`cd ${p.dir} && testing_configure_django_cms ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log, ...ACCOUNT });
  const r = run();
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const pkg = JSON.parse(fs.readFileSync(path.join(p.dir, 'package.json'), 'utf8'));
  assert.strictEqual(pkg.devDependencies['@webship-js/django-cms-steps'], '^2.1.0');
  assert.strictEqual(pkg.devDependencies['webship-js'], '^2.0.6', 'what was there stays');
  const cucumber = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
  const lines = cucumber.split('\n');
  const core = lines.findIndex((l) => l.includes('node_modules/webship-js/tests/step-definitions'));
  assert.strictEqual(lines[core + 1], "      'node_modules/@webship-js/django-cms-steps/tests/step-definitions/*.steps.js',", 'the pack is listed right after webship-js');
  assert.match(cucumber, /admin: \{ username: process\.env\.DJANGOCMS_ADMIN_USER \|\| 'administrator', password: process\.env\.DJANGOCMS_ADMIN_PASS \|\| '[^']+' \},/);
  assert.match(cucumber, /editor: \{ username: process\.env\.DJANGOCMS_EDITOR_USER \|\| 'editor'/);
  assert.doesNotMatch(cucumber, /webmaster|quoted/, 'the workspace account is not in the registry');
  // Still a module node can load, with the registry where webship-js reads it.
  const loaded = spawnSync(process.execPath, ['-e', `const c = require(${JSON.stringify(path.join(p.dir, 'cucumber.js'))}).default; console.log(JSON.stringify([c.require, Object.keys(c.worldParameters.users), c.worldParameters.djangoCms.adminLanguage]))`], { encoding: 'utf8' });
  assert.strictEqual(loaded.status, 0, loaded.stderr);
  const [requires, handles, language] = JSON.parse(loaded.stdout);
  assert.strictEqual(requires.length, 3);
  assert.deepStrictEqual(handles, ['admin', 'editor']);
  assert.strictEqual(language, 'en');
  assert.ok(fs.existsSync(path.join(p.dir, 'tests', 'features', 'site.feature')));
  assert.deepStrictEqual(payloads(log).map((c) => c.verb), ['installed', 'add'], 'a site that has its superuser gets the default accounts');
  // Again, after a person changed the feature: nothing is doubled, nothing is reset.
  fs.writeFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'Feature: mine\n');
  assert.strictEqual(run().status, 0);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), cucumber);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'utf8'), 'Feature: mine\n');
});

test('the testing hook leaves a project of another platform alone', () => {
  const p = project('drupal11');
  const r = bash(`cd ${p.dir} && testing_configure_django_cms ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1' });
  assert.strictEqual(r.status, 0);
  assert.strictEqual(r.stdout, '');
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), SCAFFOLD);
  assert.ok(!fs.existsSync(path.join(p.dir, 'tests')));
});

test('the CLI tool refuses a project that is not django CMS', () => {
  const p = project('drupal11');
  const r = bash('PROJECT_NAME=site1 ; RUN="check" ; trim_project_name() { :; } ; django_cms_cli_tool', { WORKSPACE_ROOT: p.root, doc_name: 'dev' });
  assert.strictEqual(r.status, 1);
  assert.match(r.stdout, /is not a django CMS project/);
});

test('the first feature names no platform in a step, and no password', () => {
  const feature = fs.readFileSync(path.join(PKG, 'testing', 'site.feature'), 'utf8');
  const steps = feature.split('\n').filter((l) => /^\s*(Given|When|Then|And|But) /.test(l));
  assert.ok(steps.length >= 10);
  for (const s of steps) assert.doesNotMatch(s, /django|\bCMS\b/i, s);
  assert.doesNotMatch(feature, /password "/);
  assert.doesNotMatch(feature, /createsuperuser|I register|add user/i, 'a suite never creates an account');
  assert.doesNotMatch(feature, /"webmaster"/, 'the superuser is the workspace account: no scenario logs in as it');
});
