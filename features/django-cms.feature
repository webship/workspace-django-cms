Feature: The django CMS plugin on the dashboard
  Once the plugin is activated and installed, the sites folders offer the django CMS builder, each
  AI folder lists the items of its kind the plugin ships, and the Plugins page lists the plugin
  with its steps.

  # The Plugins page names each plugin; the package is on the plugin's own page (the row shows it on hover only).
  Scenario: The plugin is listed on the Plugins page, and its own page names its package
    Given I am on "/settings/plugins"
     Then I should see "django CMS"
     When I go to "/settings/plugin/django-cms"
     Then I should see "@webship.co/workspace-django-cms"

  Scenario: A sites folder offers the django CMS builder
    Given I am on "/dev"
     Then "option[value='cmd-django-cms-project.sh']" should be attached

  # The AI folders are searched by name: with every plugin on, a folder lists more than one page of items.
  Scenario: The AI Agents folder lists the agents the plugin ships
    Given I am on "/ai-agents?q=django-cms-"
     Then I should see "django-cms-site-builder"
      And I should see "django-cms-tester"

  Scenario: The AI Skills folder lists the skill the plugin ships
    Given I am on "/ai-skills?q=django-cms-scenarios"
     Then I should see "django-cms-scenarios"

  Scenario: The AI Commands folder lists the command the plugin ships
    Given I am on "/ai-commands?q=django-cms-test"
     Then I should see "django-cms-test"

  Scenario: The AI Prompts folder lists the prompt the plugin ships
    Given I am on "/ai-prompts?q=django-cms-build-and-test"
     Then I should see "django-cms-build-and-test"
