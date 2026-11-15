Feature: The django CMS plugin on the dashboard
  Once the plugin is activated and installed, the sites folders offer the django CMS builder, each
  AI folder lists the items of its kind the plugin ships, and the Plugins page lists the plugin
  with its steps.

  Scenario: The plugin is listed on the Plugins page
    Given I am on "/settings/plugins"
     Then I should see "django CMS"
      And I should see "@webship.co/workspace-django-cms"

  Scenario: A sites folder offers the django CMS builder
    Given I am on "/dev"
     Then "option[value='cmd-django-cms-project.sh']" should be attached

  Scenario: The AI Agents folder lists the agents the plugin ships
    Given I am on "/ai-agents"
     Then I should see "django-cms-site-builder"
      And I should see "django-cms-tester"

  Scenario: The AI Skills folder lists the skill the plugin ships
    Given I am on "/ai-skills"
     Then I should see "django-cms-scenarios"

  Scenario: The AI Commands folder lists the command the plugin ships
    Given I am on "/ai-commands"
     Then I should see "django-cms-test"

  Scenario: The AI Prompts folder lists the prompt the plugin ships
    Given I am on "/ai-prompts"
     Then I should see "django-cms-build-and-test"
