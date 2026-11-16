---
name: django-cms-scenarios
description: Write and run webship-js scenarios for a django CMS site of the Webship Workspace with the django CMS step pack (`@webship-js/django-cms-steps`) — the phrases of the pack by area (sessions and accounts, the administration, the toolbar and the wizard, plugins and versions, the page tree, the front end), the handles of the users registry, and the workspace command that runs them in the site's container. Use when asked to "write a scenario for this django CMS site", "test the editor account", "which step is there for the page tree", "add a feature for publishing a page", or when a `.feature` file of a django CMS project is being written or fixed.
argument-hint: '<site> [what to cover]'
---

# django-cms-scenarios

Scenarios for a django CMS site of a Webship Workspace (`~/workspace`, container-based, DDEV by
default), written from the steps of
[`@webship-js/django-cms-steps`](https://github.com/webship/django-cms-steps) and of
[webship-js](https://github.com/webship/webship-js) itself, and run in the site's container by the
workspace's own command. It comes with the django CMS plugin (`@webship.co/workspace-django-cms`),
like the builder (`cmd-django-cms-project.sh`), the manage.py tool
(`cmd-tools-django-cms-cli.sh`) and the agents `django-cms-site-builder` and `django-cms-tester`.

## Where everything is

| What | Where |
| --- | --- |
| The site | `~/workspace/<folder>/<site>`, at `https://<site>.ddev.site`, the admin at `/admin/` (`<folder>` is a sites folder: `dev`, `test`, `sandboxes`, `demos`) |
| The suite's configuration | `<site>/cucumber.js`: the step definitions it loads and the users registry (`worldParameters.users`) |
| The features | `<site>/tests/features/*.feature` (`site.feature` is the first one the setup wrote) |
| The pack's steps | `<site>/node_modules/@webship-js/django-cms-steps/tests/step-definitions/*.steps.js` |
| webship-js's steps | `<site>/node_modules/webship-js/tests/step-definitions/*.js` |
| The reports | `<site>/tests/reports/` |

## The order of work

1. **Make sure the testing stack is there.** From the sites folder:
   ```bash
   cd ~/workspace/<folder>
   bash cmd-tools-testing.sh <site>
   ```
   It adds webship-js, the step pack, the users registry and `tests/features/site.feature`, and
   makes sure the default accounts are on the site. It is safe to run again: it adds what is
   missing and keeps what was changed.
2. **Read the installed steps before writing a phrase.** They are the source of truth: the pack
   moves, and a phrase from memory is a guess.
   ```bash
   cd ~/workspace/<folder>/<site>
   grep -hE "^(Given|When|Then)\(" node_modules/@webship-js/django-cms-steps/tests/step-definitions/*.steps.js
   ```
   Every step carries a comment block with five examples above it; open the file when a phrase
   is not obvious.
3. **Look at the page first** (the Playwright MCP browser, a tab of your own) when the scenario
   is about a screen you have not seen: the toolbar, the wizard and the page tree show what the
   account that is logged in may do.
4. **Write the feature** in `<site>/tests/features/`, from phrases that exist (the lists below).
5. **Match every step without a browser**, then run the feature, then the suite:
   ```bash
   cd ~/workspace/<folder>
   bash cmd-tools-testing.sh <site> --dry-run --path tests/features/<name>.feature
   bash cmd-tools-testing.sh <site> --run --path tests/features/<name>.feature
   bash cmd-tools-testing.sh <site> --run --tags "@critical"
   bash cmd-tools-testing.sh <site> --run
   ```
   A dry run says `Undefined` for a phrase no definition matches: fix the phrase, do not write a
   step for it.

## Accounts: a handle, never a password

A scenario logs in by a handle of the users registry. The default accounts are on the site
already (`bash cmd-tools-django-cms-cli.sh <site> --add-users` adds them again if they were
removed):

| Handle | Account | What it is |
| --- | --- | --- |
| `admin` | `administrator` | A superuser |
| `editor` | `editor` | Staff, in the group `Editors`: pages, plugins, versions, aliases and files |

```gherkin
Given I am a logged in user with the "editor" user
Then I should be logged in
```

## The phrases, by area

Each line is a phrase the pack defines, and each one passed on a site built with
`bash cmd-django-cms-project.sh <site> --install --add-users` (a site with no page yet; the titles
in quotes are the ones the scenario itself made). Most `should` steps also take the negative.

### Sessions

```gherkin
Given I am not logged in
Given I am on the login page
Given I am a logged in user with the "editor" user
When I log in as "editor" with the password "not-the-password"
When I log out
Then I should see the login form
Then I should not see a login error
Then I should see a login error
Then I should be logged in
Then I should not be logged in
```

### Accounts and the administration

```gherkin
Then the user "administrator" should be a superuser
Then the user "editor" should be staff
Then the user "editor" should be active
Then the user "editor" should be in the "Editors" group
Then the "Editors" group should have the "Can add page" permission
When I go to the users list
Then I should see "editor" in the admin list
Then the administration should offer "Page contents"
Then the administration should not offer "Users"
Then I should not be allowed to open "/admin/auth/user/"
```

The steps about a user or a group open the administration themselves, so the account that is
logged in must be allowed to see them: `admin`.

### The toolbar and the wizard

```gherkin
Then I should see the welcome screen
Then I should see the toolbar
Then the toolbar should have the "Create" button
Then the toolbar should not have the "Page" menu
Then the "site" toolbar menu should list "Pages"
When I open the create wizard
Then the create wizard should offer "New page"
Then the CMS modal should be open
When I click "Cancel" in the CMS modal
When I create a page titled "A page from the suite" with the text "Written by the suite." with the wizard
```

### Plugins and versions

```gherkin
Then I should be in edit mode
Then the page version should be "Draft"
Then the page should be at version 1
Then the "Page Content" placeholder should have a "Text" plugin
Then the "Page Content" placeholder should have 1 plugin
When I publish the page
Then I should see the CMS message "Version published"
Then the page version should be "Published"
Then the toolbar should have the "New Draft" button
```

### The page tree

```gherkin
Given I am on the page tree
Then I should see the page tree
Then I should see "A page from the suite" in the page tree
Then the page "A page from the suite" should be published in the page tree
Then the page "A page from the suite" should be the home page in the page tree
When I unpublish the page "A page from the suite" in the page tree
Then the page "A page from the suite" should be unpublished in the page tree
When I delete the page "A page from the suite" in the page tree
```

### The front end

```gherkin
When I go to the homepage
Then the navigation menu should list "A page from the suite"
Then I should not see the toolbar
When I go to "/en/this-page-does-not-exist/"
Then I should be on the page not found page
```

`I go to the homepage`, `I go to "<path>"`, `I should see "<text>"` and
`the response status code should be 200` are webship-js's own steps; its status codes, classes,
landmarks and accessibility audits are used as they are and never redefined for this platform.

## Traps found on a real site

- **Log out before you log in as somebody else.** In one scenario, `Given I am a logged in user
  with the "editor" user` after the same step for `admin` failed with `Could not log in as
  "editor"`; with `When I log out` between the two it passed.
- **A site as built has no page.** A visitor who asks for the front page gets the login form, a
  logged in user gets the welcome screen, and the toolbar has `Create` and no `Page` menu. The
  pack's own features (`node_modules/@webship-js/django-cms-steps/tests/features/`) are written
  for the pack's seeded test site (`/en/about/`, `/en/contact/`): copy the shape, replace the
  pages.
- **The first page of a site becomes its home page**, at the front page and not at its own slug:
  read it with `When I go to the homepage`. A scenario that leaves it behind changes what the
  first feature (`site.feature`) sees for a visitor: delete it in the same scenario.
- **The examples unpublish a published page before they delete it** in the page tree. Deleting
  a published page in one step was not tried.
- **A feature that failed half way leaves its page.** Remove it in the page tree before the next
  run, or the wizard makes a second page of the same title.

## Rules

- **No account is created in a suite.** No `createsuperuser` in a hook, no scenario that adds a
  user. A role the registry does not have is asked for, not made.
- **Never the workspace account.** The site's own superuser is not in the registry; `admin` is
  the `administrator` default account.
- **No password in a feature file**, except where a wrong password is the subject.
- **No platform name in a step phrase**: `I am on the page tree`, `I should see the toolbar`,
  `I should see the welcome screen`. The pack takes a longer form with `CMS` in it too
  (`I should see the CMS toolbar`), and the version is a value of its step:
  `the CMS version should start with "<version>"`, for a logged-in staff user on a page of the
  CMS. No phrase names the product, and a custom step does not either.
- **No selector and no address when a step says it**: `the users list`, not the path of the list.
- **What a scenario creates, it removes** in the same scenario, under a title nobody else uses.
- **A custom step is the last resort**: look in the pack and in webship-js first, write it in
  `<site>/tests/step-definitions/` with a comment block and examples, and say it may belong in
  the pack.
- **Everything runs in the container**, through `cmd-tools-testing.sh`. Never `npx cucumber-js`
  or `npx playwright` on the host.
- **A failing scenario is a result.** No `@wip`, no longer timeout, no looser assertion to turn a
  run green: say what the site did.

## Examples that run

`examples/` holds three features that pass on a site built with
`bash cmd-django-cms-project.sh <site> --install --add-users`. Copy one into the suite and run it:

```bash
cp ~/workspace/ai-skills/django-cms-scenarios/examples/page-lifecycle.feature ~/workspace/<folder>/<site>/tests/features/
cd ~/workspace/<folder>
bash cmd-tools-testing.sh <site> --run --path tests/features/page-lifecycle.feature
```

| Feature | What it shows |
| --- | --- |
| `examples/accounts-and-administration.feature` | The roles of the default accounts, the list of users, what the administration offers the editor and refuses it |
| `examples/page-lifecycle.feature` | An editor creating a page with the wizard, publishing it, a visitor reading it, and the editor unpublishing and deleting it |
| `examples/empty-site.feature` | A site before its first page: the welcome screen, the toolbar, the wizard, the page tree, a visitor, an address with no page |

## The book

For any automated functional testing in this work (a Gherkin feature, a step definition, choosing a
step, a test run and its failures), read the book *Automated Functional Testing Recipes* first.

- **Where.** Use the first that exists: `.claude/automated-functional-testing-recipes/` in the project,
  `~/.claude/automated-functional-testing-recipes/` (installed by webship/webship-js-ai-agent,
  webship/webship-js-skills or webship/ai-agents), or
  https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes
- **How.** Its `README.md` first, then the chapter that matches the task (one file per chapter,
  named by its subject), not the single complete file.
- **Which wins.** The installed webship-js package and the step pack are the source of truth for
  step phrasing. When they differ from the book, follow them and say so.
- **For django CMS.** Start with `ch26-testing-cms-applications.md` (content, publishing, media and
  taxonomy), `ch10-authentication-authorization.md` (logins, sessions and access by role),
  `ch33-complete-step-definition-reference.md` (every built-in step) and `ch21-when-tests-go-bad.md`
  (flaky, brittle and slow scenarios).
