Feature: The site answers and its accounts work
  As the owner of the site
  I want the front page, the login page and each default account to work
  So that a build that came out broken is caught before anything else is tested

  # Placed by the workspace's testing setup as a starting point: it is yours to change.
  # The accounts are the default ones (cmd-tools-add-users.sh); a scenario logs in by a handle of
  # the users registry in cucumber.js, so no password is written here.

  # A site with no published page sends a visitor to the login page; once it has a home page, the
  # visitor gets that page and the last step of this scenario is the one to change.
  @critical
  Scenario: The front page is served
    Given I am not logged in
    When I go to the homepage
    Then the response status code should be 200
    And I should not see the toolbar
    And I should see the login form

  @critical
  Scenario: The login page is served with its form
    Given I am on the login page
    Then the response status code should be 200
    And I should see the login form
    And I should not see a login error

  Scenario Outline: Each default account logs in
    Given I am a logged in user with the "<handle>" user
    Then I should be logged in
    And I should not see the login form
    When I go to the homepage
    Then I should see the toolbar

    Examples:
      | handle |
      | admin  |
      | editor |

  Scenario: Each default account has its role
    Given I am a logged in user with the "admin" user
    Then the user "administrator" should be a superuser
    And the user "editor" should be staff
    And the user "editor" should be in the "Editors" group
    But the user "editor" should not be a superuser

  Scenario: An account is refused what its role may not open
    Given I am a logged in user with the "editor" user
    Then the administration should offer "Page contents"
    But the administration should not offer "Users"
    And the administration should not offer "Groups"

  Scenario: An anonymous visitor has no session
    Given I am not logged in
    When I go to the homepage
    Then I should not see the toolbar
    And I should not be logged in
