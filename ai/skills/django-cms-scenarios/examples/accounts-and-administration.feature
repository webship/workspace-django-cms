Feature: Each account has its role and reaches what it may use
  As the owner of the site
  I want the administrator and the editor to have their roles, and the editor to be kept out of the accounts
  So that a change of permissions is caught by the suite

  # The accounts are the default ones; a scenario logs in by a handle of the users registry.

  Scenario: The administrator sees the accounts with their roles
    Given I am a logged in user with the "admin" user
    Then the user "administrator" should be a superuser
    And the user "editor" should be staff
    And the user "editor" should be active
    And the user "editor" should be in the "Editors" group
    And the "Editors" group should have the "Can add page" permission
    But the user "editor" should not be a superuser

  Scenario: The administrator finds the editor in the list of users
    Given I am a logged in user with the "admin" user
    When I go to the users list
    Then I should see "editor" in the admin list

  Scenario: The editor is offered the pages and is refused the users
    Given I am a logged in user with the "editor" user
    Then the administration should offer "Page contents"
    But the administration should not offer "Users"
    And I should not be allowed to open "/admin/auth/user/"
